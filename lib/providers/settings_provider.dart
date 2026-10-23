import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String language;
  final String textSize;
  final bool isDarkMode;
  final bool isHighContrast;

  SettingsState({
    this.language = 'es',
    this.textSize = 'Normal',
    this.isDarkMode = false,
    this.isHighContrast = false,
  });

  SettingsState copyWith({
    String? language,
    String? textSize,
    bool? isDarkMode,
    bool? isHighContrast,
  }) {
    return SettingsState(
      language: language ?? this.language,
      textSize: textSize ?? this.textSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isHighContrast: isHighContrast ?? this.isHighContrast,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadFromPrefs();
    return SettingsState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('pref_language') ?? 'es';
      final size = prefs.getString('pref_textSize') ?? 'Normal';
      final dark = prefs.getBool('pref_isDarkMode') ?? false;
      final contrast = prefs.getBool('pref_isHighContrast') ?? false;
      state = SettingsState(
        language: lang,
        textSize: size,
        isDarkMode: dark,
        isHighContrast: contrast,
      );
    } catch (_) {}
  }

  void setLanguage(String lang) {
    state = state.copyWith(language: lang);
    _savePrefString('pref_language', lang);
  }

  void setTextSize(String size) {
    state = state.copyWith(textSize: size);
    _savePrefString('pref_textSize', size);
  }

  void toggleDarkMode(bool isDark) {
    state = state.copyWith(isDarkMode: isDark);
    _savePrefBool('pref_isDarkMode', isDark);
  }

  void toggleHighContrast(bool isHigh) {
    state = state.copyWith(isHighContrast: isHigh);
    _savePrefBool('pref_isHighContrast', isHigh);
  }

  Future<void> _savePrefString(String key, String val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, val);
    } catch (_) {}
  }

  Future<void> _savePrefBool(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
