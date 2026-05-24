import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();

  static final AppSettingsStore instance = AppSettingsStore._();

  Locale _locale = const Locale('en');
  bool _isDarkMode = false;
  double _textScale = 1.0;
  bool _accessibilityVoice = true;

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isDarkMode => _isDarkMode;
  double get textScale => _textScale;
  bool get accessibilityVoice => _accessibilityVoice;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage =
        prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';

    final savedDarkMode =
        prefs.getBool('darkMode') ?? prefs.getBool('dark_mode') ?? false;

    final savedTextScale =
        prefs.getDouble('textScale') ?? prefs.getDouble('text_scale') ?? 1.0;

    final savedAccessibilityVoice = prefs.getBool('accessibilityVoice') ?? true;

    _locale = Locale(savedLanguage);
    _isDarkMode = savedDarkMode;
    _textScale = savedTextScale;
    _accessibilityVoice = savedAccessibilityVoice;

    await prefs.setString('language', savedLanguage);
    await prefs.setBool('darkMode', savedDarkMode);
    await prefs.setDouble('textScale', savedTextScale);
    await prefs.setBool('accessibilityVoice', savedAccessibilityVoice);

    notifyListeners();
  }

  Future<void> loadSavedSettings() async {
    await loadSettings();
  }

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage =
        prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';

    _locale = Locale(savedLanguage);

    await prefs.setString('language', savedLanguage);

    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    _locale = Locale(languageCode);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('language', languageCode);
    await prefs.setString('app_language', languageCode);

    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    if (isArabic) {
      await changeLanguage('en');
    } else {
      await changeLanguage('ar');
    }
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', value);
    await prefs.setBool('dark_mode', value);

    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('textScale', value);
    await prefs.setDouble('text_scale', value);

    notifyListeners();
  }

  Future<void> setAccessibilityVoice(bool value) async {
    _accessibilityVoice = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('accessibilityVoice', value);

    notifyListeners();
  }

  Future<void> toggleAccessibilityVoice() async {
    await setAccessibilityVoice(!_accessibilityVoice);
  }
}
