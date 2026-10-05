import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return SettingsState();
  }

  void setLanguage(String lang) {
    state = state.copyWith(language: lang);
  }

  void setTextSize(String size) {
    state = state.copyWith(textSize: size);
  }

  void toggleDarkMode(bool isDark) {
    state = state.copyWith(isDarkMode: isDark);
  }

  void toggleHighContrast(bool isHigh) {
    state = state.copyWith(isHighContrast: isHigh);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});