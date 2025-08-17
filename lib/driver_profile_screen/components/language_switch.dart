// Language Switch Screen
import 'package:flutter/material.dart';
import 'package:okdriver/language/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';

class LanguageSwitchScreen extends StatefulWidget {
  const LanguageSwitchScreen({super.key});

  @override
  State<LanguageSwitchScreen> createState() => _LanguageSwitchScreenState();
}

class _LanguageSwitchScreenState extends State<LanguageSwitchScreen> {
  late String _selectedLanguage;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    // Initialize _isDarkMode from ThemeProvider and _selectedLanguage from LanguageProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
        _selectedLanguage =
            languageProvider.getLanguageName(languageProvider.currentLocale);
      });
    });
  }

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
    {'name': 'हिंदी', 'code': 'hi', 'flag': '🇮🇳'},
    {'name': 'தமிழ்', 'code': 'ta', 'flag': '🇮🇳'},
    {'name': 'বাংলা', 'code': 'bn', 'flag': '🇧🇩'},
    {'name': 'తెలుగు', 'code': 'te', 'flag': '🇮🇳'},
    {'name': 'मराठी', 'code': 'mr', 'flag': '🇮🇳'},
    {'name': 'ગુજરાતી', 'code': 'gu', 'flag': '🇮🇳'},
    {'name': 'ಕನ್ನಡ', 'code': 'kn', 'flag': '🇮🇳'},
    {'name': 'മലയാളം', 'code': 'ml', 'flag': '🇮🇳'},
    {'name': 'ଓଡ଼ିଆ', 'code': 'or', 'flag': '🇮🇳'},
    {'name': 'ਪੰਜਾਬੀ', 'code': 'pa', 'flag': '🇮🇳'},
    {'name': '한국어', 'code': 'ko', 'flag': '🇰🇷'},
    {'name': '中文', 'code': 'zh', 'flag': '🇨🇳'},
    {'name': '日本語', 'code': 'ja', 'flag': '🇯🇵'},
    {'name': 'Español', 'code': 'es', 'flag': '🇪🇸'},
    {'name': 'Français', 'code': 'fr', 'flag': '🇫🇷'},
    {'name': 'Deutsch', 'code': 'de', 'flag': '🇩🇪'},
    {'name': 'العربية', 'code': 'ar', 'flag': '🇸🇦'},
  ];

  void _selectLanguage(String language) {
    // Get the language code from the language name
    String languageCode = '';
    String countryCode = '';

    for (var lang in _languages) {
      if (lang['name'] == language) {
        languageCode = lang['code']!;
        break;
      }
    }

    if (languageCode.isEmpty) return;

    // Get the country code for the language code
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    countryCode = languageProvider.getCountryCode(languageCode);

    // Update the language in the provider
    languageProvider.changeLanguage(languageCode, countryCode);

    setState(() {
      _selectedLanguage = language;
    });

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Language Changed',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Language has been changed to $language. App will restart to apply changes.',
          style: TextStyle(
            color: _isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : const Color(0xFF2196F3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    // Listen to language changes
    final languageProvider = Provider.of<LanguageProvider>(context);
    _selectedLanguage =
        languageProvider.getLanguageName(languageProvider.currentLocale);

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Language',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? Colors.white : Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search languages...',
                      hintStyle: TextStyle(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black54,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Current Language
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current: $_selectedLanguage',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Languages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final language = _languages[index];
                final isSelected = language['name'] == _selectedLanguage;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectLanguage(language['name']!),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : (_isDarkMode
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF4CAF50))
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: _isDarkMode
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              language['flag']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    language['name']!,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF4CAF50)
                                          : (_isDarkMode
                                              ? Colors.white
                                              : Colors.black87),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    language['code']!.toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF4CAF50)
                                              .withOpacity(0.7)
                                          : (_isDarkMode
                                              ? Colors.white.withOpacity(0.6)
                                              : Colors.black54),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50),
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
