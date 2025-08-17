import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserSessionService {
  static const String _baseUrl = 'http://13.60.91.147:5000';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _tokenKey = 'auth_token';

  static UserSessionService? _instance;
  static UserSessionService get instance =>
      _instance ??= UserSessionService._();

  UserSessionService._();

  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;
  String? _authToken;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get authToken => _authToken;

  // Initialize session from stored data
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    _authToken = prefs.getString(_tokenKey);

    if (_isLoggedIn && _authToken != null) {
      final userDataString = prefs.getString(_userDataKey);
      if (userDataString != null) {
        try {
          _currentUser = json.decode(userDataString);
        } catch (e) {
          print('Error parsing stored user data: $e');
          await logout();
        }
      }
    }
  }

  // Login user and store session data
  Future<bool> login(String phoneNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/driver/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phoneNumber,
          'code': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          _currentUser = data['user'] ?? {};
          _authToken = data['token'];
          _isLoggedIn = true;

          // Store session data
          await _saveSessionData();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Fetch current user data from API
  Future<Map<String, dynamic>?> fetchCurrentUserData() async {
    if (!_isLoggedIn || _authToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/driver/data/current'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['driver'] != null) {
          _currentUser = data['driver'];
          await _saveSessionData();
          return _currentUser;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  // Logout user and clear session data
  Future<void> logout() async {
    if (_authToken != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/driver/logout'),
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Content-Type': 'application/json',
          },
        );
      } catch (e) {
        print('Logout API error: $e');
      }
    }

    // Clear session data
    _currentUser = null;
    _authToken = null;
    _isLoggedIn = false;

    await _clearSessionData();
  }

  // Save session data to SharedPreferences
  Future<void> _saveSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, _isLoggedIn);
    await prefs.setString(_tokenKey, _authToken ?? '');

    if (_currentUser != null) {
      await prefs.setString(_userDataKey, json.encode(_currentUser));
    }
  }

  // Clear session data from SharedPreferences
  Future<void> _clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userDataKey);
  }

  // Get user display name
  String getUserDisplayName() {
    if (_currentUser == null) return 'Driver';

    final firstName = _currentUser!['firstName']?.toString() ?? '';
    final lastName = _currentUser!['lastName']?.toString() ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    } else {
      return 'Driver';
    }
  }

  // Get user email
  String getUserEmail() {
    return _currentUser?['email']?.toString() ?? 'No email';
  }

  // Get user phone
  String getUserPhone() {
    return _currentUser?['phone']?.toString() ?? 'No phone';
  }

  // Check if user has premium plan
  bool hasPremiumPlan() {
    return _currentUser?['plan']?.toString().toLowerCase() == 'premium';
  }
}
