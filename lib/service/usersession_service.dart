import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okdriver/service/api_config.dart';
import 'dart:io';

class UserSessionService {
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _tokenKey = 'auth_token';
  static const String _sessionIdKey = 'session_id';

  static UserSessionService? _instance;
  static UserSessionService get instance =>
      _instance ??= UserSessionService._();

  UserSessionService._();

  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;
  String? _authToken;
  String? _sessionId;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get authToken => _authToken;
  String? get sessionId => _sessionId;

  // Initialize session from stored data
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    _authToken = prefs.getString(_tokenKey);
    _sessionId = prefs.getString(_sessionIdKey);

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
  Future<bool> login(
      Map<String, dynamic> userData, String token, String sessionId) async {
    try {
      print(
          'Storing login data for user: ${userData['firstName'] ?? 'Unknown'}');

      // Store user data and token from response
      _currentUser = userData;
      _authToken = token;
      _sessionId = sessionId;
      _isLoggedIn = true;

      print('Login successful, user data: $_currentUser');
      print('Token: $_authToken');
      print('Session ID: $_sessionId');

      // Store session data
      await _saveSessionData();
      return true;
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
        Uri.parse(ApiConfig.currentDriverUrl),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['driver'] != null) {
          _currentUser = data['driver'];
          await _saveSessionData();
          return _currentUser;
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        print('Token expired or invalid, logging out');
        await logout();
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
          Uri.parse(ApiConfig.driverLogoutUrl),
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Logout API error: $e');
        // Continue with local logout even if API call fails
      }
    }

    // Clear session data
    _currentUser = null;
    _authToken = null;
    _sessionId = null;
    _isLoggedIn = false;

    await _clearSessionData();
    print('User logged out successfully');
  }

  // Delete account via API and clear session locally
  Future<bool> deleteAccount() async {
    if (_authToken == null) return false;
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.driverDeleteUrl),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        await logout();
        return true;
      }
      return false;
    } catch (e) {
      print('Delete account error: $e');
      return false;
    }
  }

  // Save session data to SharedPreferences
  Future<void> _saveSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, _isLoggedIn);
      await prefs.setString(_tokenKey, _authToken ?? '');
      await prefs.setString(_sessionIdKey, _sessionId ?? '');

      if (_currentUser != null) {
        await prefs.setString(_userDataKey, json.encode(_currentUser));
      }
      print('Session data saved successfully');
    } catch (e) {
      print('Error saving session data: $e');
    }
  }

  // Clear session data from SharedPreferences
  Future<void> _clearSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_sessionIdKey);
      await prefs.remove(_userDataKey);
      print('Session data cleared successfully');
    } catch (e) {
      print('Error clearing session data: $e');
    }
  }

  // Test backend connection
  Future<bool> testBackendConnection() async {
    try {
      print('Testing backend connection to: ${ApiConfig.baseUrl}');

      final response = await http.get(
        Uri.parse(ApiConfig.healthCheckUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('Backend connection test response: ${response.statusCode}');
      print('Backend connection test body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Backend connection test failed: $e');
      return false;
    }
  }

  // Get backend URL for debugging
  String get backendUrl => ApiConfig.baseUrl;

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
    final sub = _currentUser?['activeSubscription'];
    if (_isSubscriptionActive(sub)) {
      return true;
    }
    return false;
  }

  // Fetch active subscription and merge into currentUser cache
  Future<Map<String, dynamic>?> fetchActiveSubscription() async {
    if (!_isLoggedIn) return null;
    final driverId = _currentUser?['id']?.toString();
    if (driverId == null || driverId.isEmpty) return null;
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/driver/subscription/active?driverId=$driverId');
      final r = await http.get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        if (data['success'] == true) {
          _currentUser = _currentUser ?? {};
          if (data['active'] == true && data['subscription'] != null) {
            _currentUser!['activeSubscription'] = data['subscription'];
            await _saveSessionData();
            return data['subscription'];
          } else {
            _currentUser!.remove('activeSubscription');
            await _saveSessionData();
            return null;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isSubscriptionActive(dynamic subscription) {
    if (subscription is! Map) return false;
    final status =
        subscription['status']?.toString().toUpperCase() ?? 'INACTIVE';
    final endAtRaw = subscription['endAt']?.toString();
    if (status != 'ACTIVE') return false;
    if (endAtRaw == null) return false;
    final endAt = DateTime.tryParse(endAtRaw);
    if (endAt == null) return false;
    return !endAt.isBefore(DateTime.now());
  }
}
