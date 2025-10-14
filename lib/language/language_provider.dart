import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Language Provider for managing app localization
class LanguageProvider extends ChangeNotifier {
  // Default language is English
  Locale _currentLocale = const Locale('en', 'US');

  static const String _prefsLanguageCodeKey = 'app_language_code';
  static const String _prefsCountryCodeKey = 'app_country_code';

  LanguageProvider() {
    _loadSavedLocale();
  }

  // Getter for current locale
  Locale get currentLocale => _currentLocale;

  // Method to change the language
  void setLocale(Locale locale) {
    if (!supportedLocales.contains(locale)) return;

    _currentLocale = locale;
    notifyListeners();
    _persistLocale(locale);
  }

  // Method to change language by language code
  void changeLanguage(String languageCode, String countryCode) {
    _currentLocale = Locale(languageCode, countryCode);
    notifyListeners();
    _persistLocale(_currentLocale);
  }

  // List of supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('hi', 'IN'), // Hindi
    Locale('ta', 'IN'), // Tamil
    Locale('bn', 'IN'), // Bengali
    Locale('te', 'IN'), // Telugu
    Locale('mr', 'IN'), // Marathi
    Locale('gu', 'IN'), // Gujarati
    Locale('kn', 'IN'), // Kannada
    Locale('ml', 'IN'), // Malayalam
    Locale('or', 'IN'), // Odia
    Locale('pa', 'IN'), // Punjabi
    Locale('ko', 'KR'), // Korean
    Locale('zh', 'CN'), // Chinese
    Locale('ja', 'JP'), // Japanese
    Locale('es', 'ES'), // Spanish
    Locale('fr', 'FR'), // French
    Locale('de', 'DE'), // German
    Locale('ar', 'SA'), // Arabic
  ];

  // Get language name from locale
  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      case 'ta':
        return 'தமிழ்';
      case 'bn':
        return 'বাংলা';
      case 'te':
        return 'తెలుగు';
      case 'mr':
        return 'मराठी';
      case 'gu':
        return 'ગુજરાતી';
      case 'kn':
        return 'ಕನ್ನಡ';
      case 'ml':
        return 'മലയാളം';
      case 'or':
        return 'ଓଡ଼ିଆ';
      case 'pa':
        return 'ਪੰਜਾਬੀ';
      case 'ko':
        return '한국어';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'ar':
        return 'العربية';
      default:
        return 'Unknown';
    }
  }

  // Get country code from language code
  String getCountryCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'US';
      case 'hi':
        return 'IN';
      case 'ta':
        return 'IN';
      case 'bn':
        return 'IN';
      case 'te':
        return 'IN';
      case 'mr':
        return 'IN';
      case 'gu':
        return 'IN';
      case 'kn':
        return 'IN';
      case 'ml':
        return 'IN';
      case 'or':
        return 'IN';
      case 'pa':
        return 'IN';
      case 'ko':
        return 'KR';
      case 'zh':
        return 'CN';
      case 'ja':
        return 'JP';
      case 'es':
        return 'ES';
      case 'fr':
        return 'FR';
      case 'de':
        return 'DE';
      case 'ar':
        return 'SA';
      default:
        return 'US';
    }
  }

  // Get flag emoji from language code
  String getFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'hi':
        return '🇮🇳';
      case 'ta':
        return '🇮🇳';
      case 'bn':
        return '🇧🇩';
      case 'te':
        return '🇮🇳';
      case 'mr':
        return '🇮🇳';
      case 'gu':
        return '🇮🇳';
      case 'kn':
        return '🇮🇳';
      case 'ml':
        return '🇮🇳';
      case 'or':
        return '🇮🇳';
      case 'pa':
        return '🇮🇳';
      case 'ko':
        return '🇰🇷';
      case 'zh':
        return '🇨🇳';
      case 'ja':
        return '🇯🇵';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'ar':
        return '🇸🇦';
      default:
        return '🇺🇸';
    }
  }

  Future<void> _loadSavedLocale() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedLanguageCode = prefs.getString(_prefsLanguageCodeKey);
      final String? savedCountryCode = prefs.getString(_prefsCountryCodeKey);
      if (savedLanguageCode != null && savedCountryCode != null) {
        final Locale savedLocale = Locale(savedLanguageCode, savedCountryCode);
        if (supportedLocales.contains(savedLocale)) {
          _currentLocale = savedLocale;
          notifyListeners();
        }
      }
    } catch (_) {
      // Ignore persistence errors; keep default locale
    }
  }

  Future<void> _persistLocale(Locale locale) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLanguageCodeKey, locale.languageCode);
      await prefs.setString(_prefsCountryCodeKey, locale.countryCode ?? '');
    } catch (_) {
      // Ignore persistence errors
    }
  }
}
