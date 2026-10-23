import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/router.dart';
import 'package:flutter/services.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/services/notification_service.dart';
import 'package:hue_quito/models/notification_model.dart';
import 'package:hue_quito/repositories/user_repository.dart';

import 'package:hue_quito/utils/image_picker_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fijar orientación estrictamente en vertical (portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Configurar por defecto selector para permitir Galería nativa del dispositivo
  ImagePickerHelper.configureAndroidPicker(usePhotoPicker: false);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configurar idioma español para correos y plantillas de Firebase Auth
  await FirebaseAuth.instance.setLanguageCode('es');
  
  // Habilitar caché local (Offline Persistence) para no descargar todo de la nube siempre
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Inicializar servicio de notificaciones locales de Android
  await NotificationService().initialize();

  runApp(
    const ProviderScope(
      child: HueQuitoApp(),
    ),
  );
}

class HueQuitoApp extends ConsumerWidget {
  const HueQuitoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    // Configurar acción al tocar la notificación nativa en Android
    NotificationService().onNotificationTapped = (huecaId) {
      router.push('/hueca_detail', extra: huecaId);
    };

    double textScaleFactor = 1.0;
    if (settings.textSize == 'A-') textScaleFactor = 0.85;
    if (settings.textSize == 'A+') textScaleFactor = 1.15;

    ThemeData activeTheme;
    if (settings.isHighContrast) {
      activeTheme = settings.isDarkMode
          ? AppTheme.highContrastDarkTheme
          : AppTheme.highContrastLightTheme;
    } else {
      activeTheme = settings.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
    }

    return MaterialApp.router(
      title: 'Hue-Quito',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      highContrastTheme: AppTheme.highContrastLightTheme,
      highContrastDarkTheme: AppTheme.highContrastDarkTheme,
      builder: (context, child) {
        return NotificationWatcher(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScaleFactor),
              highContrast: settings.isHighContrast,
            ),
            child: child!,
          ),
        );
      },
      routerConfig: router,
    );
  }
}

class NotificationWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationWatcher({super.key, required this.child});

  @override
  ConsumerState<NotificationWatcher> createState() => _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    // Verificación periódica cada 30 segundos para emitir notificaciones programadas
    // en el instante exacto en que llega su hora
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final approvedList = ref.read(approvedNotificationsProvider).value ?? [];
      if (approvedList.isNotEmpty) {
        _processNotifications(approvedList);
      }
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  void _processNotifications(List<NotificationModel> notifications) {
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.subscribedHuecas.isEmpty) return;

    final now = DateTime.now();

    for (final n in notifications) {
      // 1. El usuario debe estar suscrito a la hueca correspondiente
      if (!user.subscribedHuecas.contains(n.huecaId)) continue;

      // 2. Si ya fue mostrada en este dispositivo, no repetir
      if (NotificationService().hasBeenShown(n.id)) continue;

      // 3. Momento de publicación efectivo:
      // Si fue programada: scheduledFor
      // Si fue inmediata: approvedAt o createdAt
      final publishedAt = n.scheduledFor ?? n.approvedAt ?? n.createdAt;

      // 4. Si la fecha programada es aún en el futuro, no emitir todavía
      if (publishedAt.isAfter(now)) {
        continue;
      }

      // 5. Ventana de frescura de publicación:
      // Solo emitir si se publicó en este momento o hace menos de 45 minutos.
      // Si tiene más de 45 minutos (ej. publicada ayer o hace días), es una
      // notificación histórica y se marca como procesada silenciosamente para
      // que no suene ni interrumpa al usuario "a cada rato" al abrir la app.
      final ageInMinutes = now.difference(publishedAt).inMinutes;
      if (ageInMinutes <= 45) {
        NotificationService().showPromotionNotification(notification: n);
      } else {
        NotificationService().markAsSilentlyProcessed(n.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el flujo de notificaciones aprobadas:
    // ref.listen SOLO se activa cuando los datos de Firestore cambian en tiempo real,
    // garantizando que las notificaciones salgan en el momento que se publican y
    // NUNCA en rebuilds visuales de la interfaz
    ref.listen<AsyncValue<List<NotificationModel>>>(
      approvedNotificationsProvider,
      (previous, next) {
        next.whenData((notifications) {
          _processNotifications(notifications);
        });
      },
    );

    // Escuchar cambios de suscripción del usuario
    ref.listen<AsyncValue<UserModel?>>(
      currentUserProvider,
      (previous, next) {
        next.whenData((user) {
          final approvedList = ref.read(approvedNotificationsProvider).value ?? [];
          if (approvedList.isNotEmpty) {
            _processNotifications(approvedList);
          }
        });
      },
    );

    return widget.child;
  }
}

