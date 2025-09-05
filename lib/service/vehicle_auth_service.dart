import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class VehicleAuthService {
  // For Android Emulator: use 10.0.2.2 instead of localhost
  // For iOS Simulator: use localhost or your computer's IP
  // For real device: use your computer's actual IP address
  static const String baseUrl =
      'http://localhost:5000/api/company/vehicles/login';

  // Alternatively, use your computer's IP address for real devices:
  // static const String baseUrl = 'http://192.168.1.100:5000/api/driver';

  static const Duration timeoutDuration = Duration(seconds: 30);

  // Vehicle login using vehicle number and password
  static Future<Map<String, dynamic>> vehicleLogin({
    required String vehicleNumber,
    required String password,
  }) async {
    try {
      debugPrint('Making request to: $baseUrl/vehicle-login');
      debugPrint('Vehicle Number: $vehicleNumber');

      final response = await http
          .post(
            Uri.parse('$baseUrl/vehicle-login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'vehicleNumber': vehicleNumber,
              'password': password,
            }),
          )
          .timeout(timeoutDuration);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Raw Response: ${response.body}');

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint('Server returned HTML instead of JSON');
        return {
          'success': false,
          'message':
              'Server connection failed. Please check if the server is running.',
        };
      }

      // Check for empty response
      if (response.body.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Empty response from server',
        };
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } on FormatException catch (e) {
        debugPrint('JSON Parse Error: $e');
        debugPrint('Response body: ${response.body}');
        return {
          'success': false,
          'message': 'Invalid response from server. Please try again.',
        };
      }

      if (response.statusCode == 200 && data['success'] == true) {
        // Store authentication data
        try {
          final prefs = await SharedPreferences.getInstance();

          // Safely access nested data
          final responseData = data['data'];
          if (responseData != null) {
            await prefs.setString('vehicle_token', responseData['token'] ?? '');
            await prefs.setString('current_vehicle_number', vehicleNumber);

            // Handle vehicle data
            final vehicle = responseData['vehicle'];
            if (vehicle != null) {
              await prefs.setInt('vehicle_id', vehicle['id'] ?? 0);
              await prefs.setString('vehicle_model', vehicle['model'] ?? '');
              await prefs.setString('vehicle_type', vehicle['type'] ?? '');
            }

            // Handle company data
            final company = responseData['company'];
            if (company != null) {
              await prefs.setInt('company_id', company['id'] ?? 0);
              await prefs.setString('company_name', company['name'] ?? '');
            }
          }

          return {
            'success': true,
            'data': responseData,
            'message': 'Login successful',
          };
        } catch (e) {
          debugPrint('Error storing data: $e');
          return {
            'success': false,
            'message': 'Login successful but failed to store data',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid vehicle number or password',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Vehicle login service not found. Please contact support.',
        };
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } on SocketException catch (e) {
      debugPrint('Network Error: $e');
      return {
        'success': false,
        'message':
            'Cannot connect to server. Please check your internet connection and ensure the server is running.',
      };
    } on HttpException catch (e) {
      debugPrint('HTTP Error: $e');
      return {
        'success': false,
        'message': 'HTTP error occurred. Please try again.',
      };
    } on FormatException catch (e) {
      debugPrint('Format Error: $e');
      return {
        'success': false,
        'message': 'Server returned invalid response format.',
      };
    } on TimeoutException catch (e) {
      debugPrint('Timeout Error: $e');
      return {
        'success': false,
        'message':
            'Request timeout. Please check your connection and try again.',
      };
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get stored vehicle info
  static Future<Map<String, dynamic>?> getStoredVehicleInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vehicle_token');
      final vehicleNumber = prefs.getString('current_vehicle_number');
      final vehicleId = prefs.getInt('vehicle_id');
      final companyId = prefs.getInt('company_id');
      final companyName = prefs.getString('company_name');
      final vehicleModel = prefs.getString('vehicle_model');
      final vehicleType = prefs.getString('vehicle_type');

      if (token == null || vehicleId == null) {
        return null;
      }

      return {
        'token': token,
        'vehicleNumber': vehicleNumber,
        'vehicleId': vehicleId,
        'companyId': companyId,
        'companyName': companyName,
        'vehicleModel': vehicleModel,
        'vehicleType': vehicleType,
      };
    } catch (e) {
      debugPrint('Error getting stored vehicle info: $e');
      return null;
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('vehicle_token');
      await prefs.remove('current_vehicle_number');
      await prefs.remove('vehicle_id');
      await prefs.remove('company_id');
      await prefs.remove('company_name');
      await prefs.remove('vehicle_model');
      await prefs.remove('vehicle_type');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('vehicle_token');
      final vehicleId = prefs.getInt('vehicle_id');
      return token != null && vehicleId != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Test server connectivity
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'), // Add a health check endpoint
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
}

// Network configuration helper
class NetworkConfig {
  // Method to get the correct base URL based on platform
  static String getBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:5000/api/driver';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api/driver'; // Android emulator
    } else {
      return 'http://localhost:5000/api/driver'; // iOS simulator
    }
  }

  // For real device testing, use your computer's IP
  static String getRealDeviceUrl() {
    // Replace with your computer's actual IP address
    return 'http://192.168.1.100:5000/api/driver';
  }
}
