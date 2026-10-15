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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación estrictamente en vertical (Portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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

    ThemeData activeTheme = settings.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

    return MaterialApp.router(
      title: 'Hue-Quito',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
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

class NotificationWatcher extends ConsumerWidget {
  final Widget child;
  const NotificationWatcher({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final approvedAsync = ref.watch(approvedNotificationsProvider);

    userAsync.whenData((user) {
      if (user != null && user.subscribedHuecas.isNotEmpty) {
        approvedAsync.whenData((notifications) {
          for (final n in notifications) {
            if (user.subscribedHuecas.contains(n.huecaId)) {
              if (n.scheduledFor == null || n.scheduledFor!.isBefore(DateTime.now())) {
                NotificationService().showPromotionNotification(notification: n);
              }
            }
          }
        });
      }
    });

    return child;
  }
}

