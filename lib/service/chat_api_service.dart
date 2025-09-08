import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal();

  String? _vehicleToken;
  int? _vehicleId;
  int? _companyId;

  // Initialize with stored data
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _vehicleToken = prefs.getString('vehicle_token');
    _vehicleId = prefs.getInt('vehicle_id');
    _companyId = prefs.getInt('company_id');

    print('🔌 Chat API Service initialized:');
    print('🔌 Token: $_vehicleToken');
    print('🔌 Vehicle ID: $_vehicleId');
    print('🔌 Company ID: $_companyId');
  }

  // Get chat history via GET API (last 24 hours)
  Future<List<Map<String, dynamic>>> getChatHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      print('🌐 Fetching chat history via POST API...');

      if (_vehicleToken == null || _vehicleId == null) {
        print('❌ Missing token or vehicle ID');
        return [];
      }

      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/company/vehicles/${_vehicleId}/chat-history?limit=$limit&offset=$offset'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_vehicleToken',
        },
      );

      print('📨 API Response Status: ${response.statusCode}');
      print('📨 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('✅ Chat history loaded: ${data['data'].length} messages');
          // Backend now returns messages in descending order (newest first)
          final messages = List<Map<String, dynamic>>.from(data['data']);
          if (limit == 1 && messages.isNotEmpty) {
            // Return only the first (most recent) message
            return [messages.first];
          }
          return messages;
        } else {
          print('❌ API returned error: ${data['message'] ?? 'Unknown error'}');
          return [];
        }
      } else {
        print('❌ API request failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching chat history: $e');
      return [];
    }
  }

  // Send message via POST API (company to vehicle)
  Future<bool> sendMessage(String message, {String? attachmentUrl}) async {
    try {
      print('📤 Sending message via POST API...');

      if (_vehicleToken == null || _vehicleId == null) {
        print('❌ Missing token or vehicle ID');
        return false;
      }

      final response = await http.post(
        Uri.parse(
            'http://localhost:5000/api/company/vehicles/${_vehicleId}/send-message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_vehicleToken',
        },
        body: jsonEncode({
          'message': message,
          'attachmentUrl': attachmentUrl,
        }),
      );

      print('📨 Send message response: ${response.statusCode}');
      print('📨 Send message body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        print('❌ Send message failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  // Mark messages as read via PUT API
  Future<bool> markMessagesAsRead(List<int> messageIds) async {
    try {
      print('👀 Marking messages as read via POST API...');

      if (_vehicleToken == null || _vehicleId == null) {
        print('❌ Missing token or vehicle ID');
        return false;
      }

      final response = await http.put(
        Uri.parse(
            'http://localhost:5000/api/company/vehicles/${_vehicleId}/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_vehicleToken',
        },
        body: jsonEncode({'messageIds': messageIds}),
      );

      print('📨 Mark read response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      return false;
    }
  }

  // Get unread count via GET API
  Future<int> getUnreadCount() async {
    try {
      print('📊 Getting unread count via POST API...');

      if (_vehicleToken == null || _vehicleId == null) {
        print('❌ Missing token or vehicle ID');
        return 0;
      }

      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/company/vehicles/${_vehicleId}/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_vehicleToken',
        },
      );

      print('📨 Unread count response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']?['unreadCount'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }
}
