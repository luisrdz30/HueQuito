import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/router.dart';
import 'package:hue_quito/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Habilitar caché local (Offline Persistence) para no descargar todo de la nube siempre
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

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

    double textScaleFactor = 1.0;
    if (settings.textSize == 'A-') textScaleFactor = 0.85;
    if (settings.textSize == 'A+') textScaleFactor = 1.15;

    ThemeData activeTheme = settings.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

    return MaterialApp.router(
      title: 'Hue-Quito',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
            highContrast: settings.isHighContrast,
          ),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}

