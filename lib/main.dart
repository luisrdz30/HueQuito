import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';

import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/router.dart';
import 'package:flutter/services.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/services/notification_service.dart';
import 'package:hue_quito/services/push_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  
  // Pruebas locales: con --dart-define=USE_EMULATORS=true todo va a los emuladores de Firebase
  const useEmulators = bool.fromEnvironment('USE_EMULATORS');
  if (useEmulators) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }

  // Configurar idioma español para correos y plantillas de Firebase Auth
  await FirebaseAuth.instance.setLanguageCode('es');
  
  // Habilitar caché local (Offline Persistence) para no descargar todo de la nube siempre
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !useEmulators,
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

/// Permite mostrar avisos en pantalla (web) desde fuera de un Scaffold
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
      scaffoldMessengerKey: appMessengerKey,
      // Calendarios, relojes y textos del sistema en el idioma elegido por el usuario
      locale: Locale(settings.language == 'en' ? 'en' : 'es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  final Set<String> _welcomesShown = {};

  @override
  void initState() {
    super.initState();
    PushService.instance.listenOpenedNotifications(_onPushOpened);
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
      // Con la app en segundo plano el aviso lo muestra el push (FCM), no se repite aquí
      final inForeground = kIsWeb ||
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (ageInMinutes <= 45 && inForeground) {
        if (kIsWeb) {
          _showInAppNotice(n);
        } else {
          NotificationService().showPromotionNotification(notification: n);
        }
      } else {
        NotificationService().markAsSilentlyProcessed(n.id);
      }
    }
  }

  /// En web, con la página abierta, el aviso se muestra dentro de la app
  void _showInAppNotice(NotificationModel n) {
    NotificationService().markAsSilentlyProcessed(n.id);
    appMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('🔔 ${n.title}\n${n.message}', maxLines: 4, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => NotificationService().onNotificationTapped?.call(n.huecaId),
        ),
      ),
    );
  }

  /// Tocó una notificación push: lo lleva a su panel (hueca aprobada) o a la ficha de la hueca
  Future<void> _onPushOpened(Map<String, dynamic> data) async {
    final huecaId = data['huecaId']?.toString() ?? '';
    if (data['type'] == 'hueca_aprobada') {
      // Ya va directo al panel: no hace falta además el diálogo de bienvenida
      if (huecaId.isNotEmpty) _welcomesShown.add(huecaId);
      ref.invalidate(currentUserProvider);
      ref.invalidate(myHuecaProvider);
      try {
        await ref.read(currentUserProvider.future);
      } catch (_) {}
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await ref.read(userRepositoryProvider).clearBusinessWelcome(uid);
        } catch (_) {}
      }
      if (mounted) ref.read(routerProvider).go('/business/dashboard');
    } else if (huecaId.isNotEmpty) {
      NotificationService().onNotificationTapped?.call(huecaId);
    }
  }

  /// El admin aprobó la hueca de este usuario: se le avisa y pasa a su panel sin cerrar sesión
  Future<void> _showBusinessWelcome(String uid, Map welcome) async {
    final huecaId = welcome['huecaId']?.toString() ?? '';
    if (huecaId.isEmpty || !_welcomesShown.add(huecaId)) return;
    final huecaName = welcome['huecaName']?.toString() ?? '';

    // Recarga el perfil (ahora con rol de negocio) y los datos de su hueca
    ref.invalidate(currentUserProvider);
    ref.invalidate(myHuecaProvider);
    try {
      await ref.read(currentUserProvider.future);
    } catch (_) {}

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final isEn = ref.read(settingsProvider).language == 'en';
    final goToPanel = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEn ? 'Your hueca was approved! 🎉' : '¡Tu hueca fue aprobada! 🎉'),
        content: Text(isEn
            ? '${huecaName.isNotEmpty ? '"$huecaName"' : 'Your hueca'} is now on HueQuito. Go in and set it up: menu, notices and stamps.'
            : '${huecaName.isNotEmpty ? '"$huecaName"' : 'Tu hueca'} ya está en HueQuito. Entra y configúrala: su menú, sus avisos y sus sellos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(isEn ? 'Not now' : 'Ahora no')),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text(isEn ? 'Set up my hueca' : 'Configurar mi hueca'),
          ),
        ],
      ),
    );

    try {
      await ref.read(userRepositoryProvider).clearBusinessWelcome(uid);
    } catch (_) {}
    if (goToPanel == true) ref.read(routerProvider).go('/business/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    // Aviso de hueca aprobada (llega en vivo por el documento del usuario)
    ref.listen<AsyncValue<Map<String, dynamic>?>>(myUserDocProvider, (previous, next) {
      final data = next.value;
      final welcome = data?['businessWelcome'];
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (welcome is Map && uid != null) _showBusinessWelcome(uid, welcome);
    });

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
          // Mantiene registrado este dispositivo para el push si ya dio permiso
          if (user != null && user.uid != previous?.value?.uid) {
            PushService.instance.register(user.uid);
          }
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

