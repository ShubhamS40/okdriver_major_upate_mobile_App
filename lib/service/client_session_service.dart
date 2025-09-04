import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okdriver/service/api_config.dart';

class ClientSessionService {
  static const String _userDataKey = 'client_user_data';
  static const String _isLoggedInKey = 'client_is_logged_in';
  static const String _tokenKey = 'client_auth_token';
  static const String _sessionIdKey = 'client_session_id';

  static ClientSessionService? _instance;
  static ClientSessionService get instance =>
      _instance ??= ClientSessionService._();

  ClientSessionService._();

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

    print('🔍 Client session initialization:');
    print('   - Is logged in: $_isLoggedIn');
    print('   - Has token: ${_authToken != null}');
    print('   - Token key: $_tokenKey');
    print('   - Stored token: ${_authToken?.substring(0, 10)}...');

    if (_isLoggedIn && _authToken != null) {
      final userDataString = prefs.getString(_userDataKey);
      if (userDataString != null) {
        try {
          _currentUser = json.decode(userDataString);
          print(
              '   - User data loaded: ${_currentUser?['email'] ?? 'Unknown'}');
        } catch (e) {
          print('Error parsing stored client user data: $e');
          await logout();
        }
      }
    }
  }

  // Login client and store session data
  Future<bool> login(
      Map<String, dynamic> userData, String token, String sessionId) async {
    try {
      print(
          '🔐 Storing login data for client: ${userData['email'] ?? 'Unknown'}');
      print('📱 User data received: $userData');
      print('🔑 Token received: ${token.substring(0, 10)}...');

      // Store user data and token from response
      _currentUser = userData;
      _authToken = token;
      _sessionId = sessionId;
      _isLoggedIn = true;

      print('✅ Client login successful, user data: $_currentUser');
      print('🔑 Token stored: ${_authToken?.substring(0, 10)}...');
      print('🆔 Session ID: $_sessionId');

      // Store session data
      await _saveSessionData();
      print('💾 Session data saved successfully');
      return true;
    } catch (e) {
      print('❌ Client login error: $e');
      return false;
    }
  }

  // Fetch current client data from API
  Future<Map<String, dynamic>?> fetchCurrentClientData() async {
    if (!_isLoggedIn || _authToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/company/clients/profile'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['client'] != null) {
          _currentUser = data['client'];
          await _saveSessionData();
          return _currentUser;
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        print('Client token expired or invalid, logging out');
        await logout();
      }
    } catch (e) {
      print('Error fetching client data: $e');
    }
    return null;
  }

  // Logout client
  Future<void> logout() async {
    print('Logging out client...');

    // Clear session data
    _currentUser = null;
    _authToken = null;
    _sessionId = null;
    _isLoggedIn = false;

    await _clearSessionData();
    print('Client logged out successfully');
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
      print('Client session data saved successfully');
    } catch (e) {
      print('Error saving client session data: $e');
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
      print('Client session data cleared successfully');
    } catch (e) {
      print('Error clearing client session data: $e');
    }
  }

  // Get client display name
  String getClientDisplayName() {
    if (_currentUser == null) return 'Client';

    final firstName = _currentUser!['firstName']?.toString() ?? '';
    final lastName = _currentUser!['lastName']?.toString() ?? '';
    final email = _currentUser!['email']?.toString() ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (email.isNotEmpty) {
      return email.split('@')[0]; // Use email prefix as name
    } else {
      return 'Client';
    }
  }

  // Get client email
  String getClientEmail() {
    return _currentUser?['email']?.toString() ?? 'No email';
  }

  // Get client phone
  String getClientPhone() {
    return _currentUser?['phone']?.toString() ?? 'No phone';
  }

  // Check if client has access to specific vehicle
  bool hasVehicleAccess(String vehicleId) {
    if (_currentUser == null) return false;

    final accessibleVehicles = _currentUser!['accessibleVehicles'] as List?;
    if (accessibleVehicles == null) return false;

    return accessibleVehicles.any((vehicle) =>
        vehicle['id']?.toString() == vehicleId ||
        vehicle['vehicleId']?.toString() == vehicleId);
  }
}
