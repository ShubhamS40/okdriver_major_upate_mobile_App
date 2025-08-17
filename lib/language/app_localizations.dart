import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Map of localized strings
  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'OkDriver',
      'select_language': 'Select Language',
      'current': 'Current',
      'language_changed': 'Language Changed',
      'language_change_message':
          'Language has been changed to %s. App will restart to apply changes.',
      'ok': 'OK',
      'search_languages': 'Search languages...',
      'home': 'Home',
      'profile': 'Profile',
      'settings': 'Settings',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'theme': 'Theme',
      'language': 'Language',
      'about': 'About',
      'help': 'Help',
      'logout': 'Logout',
    },
    'hi': {
      'app_name': 'ओके ड्राइवर',
      'select_language': 'भाषा चुनें',
      'current': 'वर्तमान',
      'language_changed': 'भाषा बदल गई है',
      'language_change_message':
          'भाषा %s में बदल दी गई है। परिवर्तन लागू करने के लिए ऐप पुनरारंभ होगा।',
      'ok': 'ठीक है',
      'search_languages': 'भाषाएँ खोजें...',
      'home': 'होम',
      'profile': 'प्रोफाइल',
      'settings': 'सेटिंग्स',
      'dark_mode': 'डार्क मोड',
      'light_mode': 'लाइट मोड',
      'theme': 'थीम',
      'language': 'भाषा',
      'about': 'के बारे में',
      'help': 'सहायता',
      'logout': 'लॉग आउट',
    },
    'ta': {
      'app_name': 'ஓகே டிரைவர்',
      'select_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'current': 'தற்போதைய',
      'language_changed': 'மொழி மாற்றப்பட்டது',
      'language_change_message':
          'மொழி %s க்கு மாற்றப்பட்டுள்ளது. மாற்றங்களைப் பயன்படுத்த ஆப் மறுதொடக்கம் செய்யப்படும்.',
      'ok': 'சரி',
      'search_languages': 'மொழிகளைத் தேடுங்கள்...',
      'home': 'முகப்பு',
      'profile': 'சுயவிவரம்',
      'settings': 'அமைப்புகள்',
      'dark_mode': 'இருள் பயன்முறை',
      'light_mode': 'ஒளி பயன்முறை',
      'theme': 'தீம்',
      'language': 'மொழி',
      'about': 'பற்றி',
      'help': 'உதவி',
      'logout': 'வெளியேறு',
    },
    // Add more languages as needed
  };

  String translate(String key, [List<String>? args]) {
    // Check if the language is supported
    if (!_localizedValues.containsKey(locale.languageCode)) {
      return _localizedValues['en']![key] ?? key;
    }

    // Get the translated value for the key
    String? value = _localizedValues[locale.languageCode]![key];

    // If the key is not found, return the key itself
    if (value == null) {
      return _localizedValues['en']![key] ?? key;
    }

    // If arguments are provided, replace placeholders with arguments
    if (args != null && args.isNotEmpty) {
      for (int i = 0; i < args.length; i++) {
        value = value!.replaceAll('%${i + 1}\$s', args[i]);
        value = value.replaceAll('%s', args[i]); // For simple placeholder
      }
    }

    return value!;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return [
      'en',
      'hi',
      'ta',
      'bn',
      'te',
      'mr',
      'gu',
      'kn',
      'ml',
      'or',
      'pa',
      'ko',
      'zh',
      'ja',
      'es',
      'fr',
      'de',
      'ar'
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Extension method for easy access to translations
extension TranslateX on String {
  String tr(BuildContext context, [List<String>? args]) {
    return AppLocalizations.of(context).translate(this, args);
  }
}
