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
      'dashcam': 'Dashcam',
      'location': 'Location',
      'chat': 'Chat',
      'tracking': 'Tracking',
      'settings': 'Settings',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'theme': 'Theme',
      'language': 'Language',
      'account': 'Account',
      'app_settings': 'App Settings',
      'support_info': 'Support & Info',
      'edit_profile': 'Edit Profile',
      'update_personal_information': 'Update your personal information',
      'notifications': 'Notifications',
      'manage_app_notifications': 'Manage app notifications',
      'dark_theme_enabled': 'Dark theme enabled',
      'light_theme_enabled': 'Light theme enabled',
      'premium': 'Premium',
      'buy_premium_plan': 'Buy Premium Plan',
      'unlock_premium_features': 'Unlock all premium features',
      'about_okdriver': 'About OkDriver',
      'learn_more_about_app': 'Learn more about our app',
      'help_support': 'Help & Support',
      'get_help_support': 'Get help and contact support',
      'privacy_policy': 'Privacy Policy',
      'read_privacy_policy': 'Read our privacy policy',
      'are_you_sure_logout': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'about': 'About',
      'help': 'Help',
      'logout': 'Logout',
      // Home
      'hello': 'Hello!',
      'drive_safe_today': 'Drive Safe Today',
      'good_morning': 'Good Morning',
      'good_afternoon': 'Good Afternoon',
      'good_evening': 'Good Evening',
      'safety_features': 'Safety Features',
      'feature_coming_soon_title': '%s',
      'feature_coming_soon_message':
          "This feature is coming soon! We're working hard to bring you the best %s experience.",
      'emergency_sos': 'Emergency SOS',
      'emergency_sos_desc': 'Quick help in critical situations',
      'dashcam_title': 'DashCam',
      'dashcam_desc': 'Record your journey for safety',
      'drowsiness_monitoring': 'Drowsiness Monitoring',
      'drowsiness_monitoring_desc': 'AI-powered drowsiness detection',
      'assistant_title': 'OkDriver Assistant',
      'assistant_desc': 'Can talk to you and assist you',
      // About
      'about_okdriver_title': 'About OkDriver',
      'about_our_app': 'About Our App',
      'about_our_app_desc':
          'OkDriver is a comprehensive driver safety application designed to enhance road safety through advanced AI technology and real-time monitoring. Our mission is to reduce accidents and save lives by providing intelligent driving assistance.',
      'company_information': 'Company Information',
      'company_information_desc':
          'Developed by okDriver Smart Dashcams Private Limited.\nFounded in 2025 with a vision to make roads safer for everyone through innovative technology solutions.',
      'key_features': 'Key Features',
      'contact_us': 'Contact Us',
      'contact_email_label': 'Email:',
      'contact_phone_label': 'Phone:',
      'contact_website_label': 'Website:',
      'contact_address_label': 'Address:',
      'version': 'Version %s',
      'privacy_policy': 'Privacy Policy',
      'open_privacy_policy': 'Open Privacy Policy',
      // Help & Support
      'help_support': 'Help & Support',
      'help_support_blurb':
          'Create a support ticket for any issue related to your account, vehicles, billing, or product usage.',
      'subject': 'Subject',
      'subject_placeholder': 'Brief summary of the issue',
      'priority': 'Priority',
      'priority_low': 'Low',
      'priority_medium': 'Medium',
      'priority_high': 'High',
      'description': 'Description',
      'description_placeholder':
          'Explain the issue in detail. Include steps, screenshots/IDs if relevant.',
      'create_ticket': 'Create Ticket',
      'ticket_created':
          'Ticket created! We will respond via email within 24 hours.',
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
      'dashcam': 'डैशकैम',
      'location': 'लोकेशन',
      'chat': 'चैट',
      'tracking': 'ट्रैकिंग',
      'settings': 'सेटिंग्स',
      'dark_mode': 'डार्क मोड',
      'light_mode': 'लाइट मोड',
      'theme': 'थीम',
      'language': 'भाषा',
      'account': 'खाता',
      'app_settings': 'ऐप सेटिंग्स',
      'support_info': 'सहायता और जानकारी',
      'edit_profile': 'प्रोफाइल संपादित करें',
      'update_personal_information': 'अपनी व्यक्तिगत जानकारी अपडेट करें',
      'notifications': 'सूचनाएँ',
      'manage_app_notifications': 'ऐप सूचनाएँ प्रबंधित करें',
      'dark_theme_enabled': 'डार्क थीम सक्षम',
      'light_theme_enabled': 'लाइट थीम सक्षम',
      'premium': 'प्रीमियम',
      'buy_premium_plan': 'प्रीमियम प्लान खरीदें',
      'unlock_premium_features': 'सभी प्रीमियम सुविधाएँ अनलॉक करें',
      'about_okdriver': 'ओके ड्राइवर के बारे में',
      'learn_more_about_app': 'हमारे ऐप के बारे में जानें',
      'help_support': 'सहायता और समर्थन',
      'get_help_support': 'मदद प्राप्त करें और समर्थन से संपर्क करें',
      'privacy_policy': 'गोपनीयता नीति',
      'read_privacy_policy': 'हमारी गोपनीयता नीति पढ़ें',
      'are_you_sure_logout': 'क्या आप वाकई लॉग आउट करना चाहते हैं?',
      'cancel': 'रद्द करें',
      'about': 'के बारे में',
      'help': 'सहायता',
      'logout': 'लॉग आउट',
      // Home
      'hello': 'नमस्ते!',
      'drive_safe_today': 'आज सुरक्षित ड्राइव करें',
      'good_morning': 'सुप्रभात',
      'good_afternoon': 'शुभ दोपहर',
      'good_evening': 'शुभ संध्या',
      'safety_features': 'सुरक्षा सुविधाएँ',
      'feature_coming_soon_title': '%s',
      'feature_coming_soon_message':
          'यह सुविधा जल्द ही आ रही है! हम आपको सर्वोत्तम %s अनुभव देने पर काम कर रहे हैं।',
      'emergency_sos': 'आपातकालीन SOS',
      'emergency_sos_desc': 'गंभीर स्थितियों में त्वरित सहायता',
      'dashcam_title': 'डैशकैम',
      'dashcam_desc': 'सुरक्षा के लिए अपनी यात्रा रिकॉर्ड करें',
      'drowsiness_monitoring': 'नींद-झपकी निगरानी',
      'drowsiness_monitoring_desc': 'एआई-संचालित सतर्कता पहचान',
      'assistant_title': 'ओकेड्राइवर सहायक',
      'assistant_desc': 'आपसे बात कर सकता है और सहायता कर सकता है',
      // About
      'about_okdriver_title': 'ओकेड्राइवर के बारे में',
      'about_our_app': 'हमारे ऐप के बारे में',
      'about_our_app_desc':
          'ओकेड्राइवर एक व्यापक ड्राइवर सुरक्षा एप्लिकेशन है जिसे उन्नत एआई तकनीक और रीयल-टाइम मॉनिटरिंग के माध्यम से सड़क सुरक्षा बढ़ाने के लिए डिज़ाइन किया गया है। हमारा मिशन दुर्घटनाओं को कम करना और बुद्धिमान ड्राइविंग सहायता प्रदान करके जीवन बचाना है।',
      'company_information': 'कंपनी की जानकारी',
      'company_information_desc':
          'सेफड्राइव टेक्नोलॉजीज प्राइवेट लिमिटेड द्वारा विकसित।\n2025 में स्थापित, नवीन प्रौद्योगिकी समाधानों के माध्यम से सड़कें सभी के लिए सुरक्षित बनाने की दृष्टि के साथ।',
      'key_features': 'प्रमुख विशेषताएँ',
      'contact_us': 'संपर्क करें',
      'contact_email_label': 'ईमेल:',
      'contact_phone_label': 'फोन:',
      'contact_website_label': 'वेबसाइट:',
      'contact_address_label': 'पता:',
      'version': 'संस्करण %s',
      'privacy_policy': 'गोपनीयता नीति',
      'open_privacy_policy': 'गोपनीयता नीति खोलें',
      // Help & Support
      'help_support': 'सहायता और समर्थन',
      'help_support_blurb':
          'अपने खाते, वाहनों, बिलिंग, या उत्पाद उपयोग से संबंधित किसी भी समस्या के लिए एक सपोर्ट टिकट बनाएं।',
      'subject': 'विषय',
      'subject_placeholder': 'समस्या का संक्षिप्त सारांश',
      'priority': 'प्राथमिकता',
      'priority_low': 'कम',
      'priority_medium': 'मध्यम',
      'priority_high': 'उच्च',
      'description': 'विवरण',
      'description_placeholder':
          'समस्या को विस्तार से समझाएँ। यदि प्रासंगिक हो तो चरण, स्क्रीनशॉट/आईडी शामिल करें।',
      'create_ticket': 'टिकट बनाएँ',
      'ticket_created':
          'टिकट बना दिया गया! हम 24 घंटे के भीतर ईमेल के माध्यम से जवाब देंगे।',
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
