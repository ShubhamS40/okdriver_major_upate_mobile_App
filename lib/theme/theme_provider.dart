import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme Provider for managing light/dark themes with SharedPreferences
class ThemeProvider extends ChangeNotifier {
  bool _isDarkTheme = false;
  static const String THEME_KEY = 'is_dark_theme';

  // Constructor - loads saved theme preference
  ThemeProvider() {
    _loadThemePreference();
  }

  // Getter for current theme state
  bool get isDarkTheme => _isDarkTheme;

  // Toggle theme and save preference
  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    _saveThemePreference();
    notifyListeners();
  }

  // Set specific theme
  void setDarkTheme(bool isDark) {
    _isDarkTheme = isDark;
    _saveThemePreference();
    notifyListeners();
  }

  // Get current ThemeData
  ThemeData get currentTheme => _isDarkTheme ? _darkTheme : _lightTheme;

  // Load saved theme preference
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkTheme = prefs.getBool(THEME_KEY) ?? false; // Default to light theme
    notifyListeners();
  }

  // Save theme preference
  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(THEME_KEY, _isDarkTheme);
  }

  // Light theme definition
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
          color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    textTheme: const TextTheme(
      titleLarge:
          TextStyle(color: Color(0xFF212121), fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFF424242)),
      bodyMedium: TextStyle(color: Color(0xFF757575)),
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    buttonTheme: const ButtonThemeData(buttonColor: Color(0xFF2196F3)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
    ),
  );

  // Dark theme definition
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF2A2A2A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
      bodyMedium: TextStyle(color: Color(0xFFBDBDBD)),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    buttonTheme: const ButtonThemeData(buttonColor: Color(0xFF2196F3)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
    ),
  );
}
