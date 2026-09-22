import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/router.dart';
import 'package:hue_quito/providers/settings_provider.dart';

void main() {
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

