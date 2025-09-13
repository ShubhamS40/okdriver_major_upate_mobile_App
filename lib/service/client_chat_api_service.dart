import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClientChatApiService {
  String? _clientId;
  String? _authToken;
  String? _companyId;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getInt('client_id')?.toString();
    _authToken = prefs.getString('client_auth_token');
    _companyId = prefs.getInt('company_id')?.toString();

    print('🔧 ClientChatApiService initialized:');
    print('🔧 Client ID: $_clientId');
    print('🔧 Company ID: $_companyId');
    print('🔧 Auth Token: ${_authToken?.substring(0, 10)}...');
  }

  // Get chat history via GET API (last 24 hours)
  Future<List<Map<String, dynamic>>> getChatHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    if (_clientId == null || _authToken == null) {
      print('❌ Missing client ID or auth token');
      return [];
    }

    try {
      print('🌐 Getting chat history for client $_clientId...');

      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/company/clients/$_clientId/chat-history?limit=$limit&offset=$offset'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      print('📡 Chat history API response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

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
        print('❌ API request failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception getting chat history: $e');
      return [];
    }
  }

  // Send message to company
  Future<bool> sendMessage(String message) async {
    if (_clientId == null || _authToken == null) {
      print('❌ Missing client ID or auth token');
      return false;
    }

    try {
      print('📤 Sending message to company: $message');

      final response = await http.post(
        Uri.parse(
            'http://localhost:5000/api/company/clients/$_clientId/send-message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'message': message,
        }),
      );

      print('📡 Send message API response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Message sent successfully');
          return true;
        } else {
          print('❌ API returned error: ${data['message'] ?? 'Unknown error'}');
          return false;
        }
      } else {
        print('❌ API request failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception sending message: $e');
      return false;
    }
  }

  // -------- Client ↔ Vehicle chat (client token) --------
  Future<List<Map<String, dynamic>>> getVehicleChatHistory(
      int vehicleId) async {
    if (_authToken == null) return [];
    try {
      final res = await http.get(
        Uri.parse(
            'http://localhost:5000/api/company/clients/vehicles/$vehicleId/chat-history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['data'] ?? []);
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<bool> sendMessageToVehicle(int vehicleId, String message) async {
    if (_authToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse(
            'http://localhost:5000/api/company/clients/vehicles/$vehicleId/send-message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'message': message}),
      );
      if (res.statusCode == 200) return true;
    } catch (_) {}
    return false;
  }

  // Mark messages as read
  Future<bool> markMessagesAsRead(List<int> messageIds) async {
    if (_clientId == null || _authToken == null) {
      print('❌ Missing client ID or auth token');
      return false;
    }

    try {
      print('👀 Marking messages as read: $messageIds');

      final response = await http.put(
        Uri.parse(
            'http://localhost:5000/api/company/clients/$_clientId/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'messageIds': messageIds,
        }),
      );

      print('📡 Mark read API response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Messages marked as read');
          return true;
        } else {
          print('❌ API returned error: ${data['message'] ?? 'Unknown error'}');
          return false;
        }
      } else {
        print('❌ API request failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception marking messages as read: $e');
      return false;
    }
  }

  // Get unread message count
  Future<int> getUnreadCount() async {
    if (_clientId == null || _authToken == null) {
      print('❌ Missing client ID or auth token');
      return 0;
    }

    try {
      print('📊 Getting unread count for client $_clientId...');

      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/company/clients/$_clientId/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      print('📡 Unread count API response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['count'] != null) {
          final count = data['count'] as int;
          print('✅ Unread count: $count');
          return count;
        } else {
          print('❌ API returned error: ${data['message'] ?? 'Unknown error'}');
          return 0;
        }
      } else {
        print('❌ API request failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return 0;
      }
    } catch (e) {
      print('❌ Exception getting unread count: $e');
      return 0;
    }
  }
}
