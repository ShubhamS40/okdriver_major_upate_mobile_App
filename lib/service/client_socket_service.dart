import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ClientSocketService {
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  String? _clientId;
  String? _authToken;
  String? _companyId;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> initializeSocket() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getInt('client_id')?.toString();
    _authToken = prefs.getString('client_auth_token');
    _companyId = prefs.getInt('company_id')?.toString();

    print('🔌 Initializing client socket...');
    print('🔌 Client ID: $_clientId');
    print('🔌 Company ID: $_companyId');

    if (_clientId == null || _authToken == null) {
      print('❌ Missing client ID or auth token for socket');
      return;
    }

    // Company ID is optional for client socket connection
    if (_companyId == null) {
      print('⚠️ Company ID is null, but continuing with socket connection');
    }

    try {
      print('🔌 Creating socket connection to: http://localhost:5000');
      print('🔌 Auth token: ${_authToken?.substring(0, 20)}...');

      // Test server connectivity first
      print('🔍 Testing server connectivity...');
      try {
        final response = await http.get(
          Uri.parse('http://localhost:5000/test-socketio'),
          headers: {'Authorization': 'Bearer $_authToken'},
        );
        print('✅ Server is reachable: ${response.statusCode}');
        print('📡 Response: ${response.body}');
      } catch (e) {
        print('❌ Server connectivity test failed: $e');
      }

      _socket = IO.io(
        'http://localhost:5000',
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // Try both transports
            .setAuth({'token': _authToken}) // Send token in auth object
            .setExtraHeaders({
              'Authorization': 'Bearer $_authToken'
            }) // Also send in headers as backup
            .enableAutoConnect()
            .setTimeout(10000) // 10 second timeout
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket!.onConnect((_) {
        print('✅ Client socket connected');
        _isConnected = true;
        _connectionController.add(true);

        // Join client room
        print(
            '🔌 Joining client room with ID: $_clientId, Company ID: $_companyId');
        _socket!.emit('join_client_room', {
          'clientId': _clientId,
          'companyId': _companyId,
        });
      });

      _socket!.onDisconnect((_) {
        print('❌ Client socket disconnected');
        _isConnected = false;
        _connectionController.add(false);
      });

      _socket!.onConnectError((error) {
        print('❌ Client socket connection error: $error');
        print('❌ Error details: ${error.toString()}');
        print('❌ Error type: ${error.runtimeType}');
        print('❌ Error message: ${error.message}');
        print('❌ Error description: ${error.description}');
        _isConnected = false;
        _connectionController.add(false);
      });

      // Listen for new messages
      _socket!.on('new_message', (data) {
        print('📨 Received new message: $data');
        _messageController.add(Map<String, dynamic>.from(data));
      });

      // Listen for message status updates
      _socket!.on('message_status', (data) {
        print('📊 Message status update: $data');
        // Handle message status updates if needed
      });

      // Listen for typing indicators
      _socket!.on('typing', (data) {
        print('⌨️ Typing indicator: $data');
        // Handle typing indicators if needed
      });

      _socket!.on('stop_typing', (data) {
        print('⌨️ Stop typing: $data');
        // Handle stop typing if needed
      });
    } catch (e) {
      print('❌ Error initializing client socket: $e');
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  void sendMessageToCompany(String message) {
    if (_socket == null || !_isConnected) {
      print('❌ Socket not connected, cannot send message');
      return;
    }

    print('📤 Sending message to company via socket: $message');

    _socket!.emit('client_message', {
      'clientId': _clientId,
      'companyId': _companyId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void markMessagesAsRead(List<int> messageIds) {
    if (_socket == null || !_isConnected) {
      print('❌ Socket not connected, cannot mark messages as read');
      return;
    }

    print('👀 Marking messages as read via socket: $messageIds');

    _socket!.emit('mark_messages_read', {
      'clientId': _clientId,
      'messageIds': messageIds,
    });
  }

  void sendTypingIndicator() {
    if (_socket == null || !_isConnected) return;

    _socket!.emit('typing', {
      'clientId': _clientId,
      'companyId': _companyId,
    });
  }

  void stopTypingIndicator() {
    if (_socket == null || !_isConnected) return;

    _socket!.emit('stop_typing', {
      'clientId': _clientId,
      'companyId': _companyId,
    });
  }

  void retryConnection() {
    print('🔄 Retrying client socket connection...');
    disconnect();
    Future.delayed(const Duration(seconds: 1), () {
      initializeSocket();
    });
  }

  void disconnect() {
    if (_socket != null) {
      print('🔌 Disconnecting client socket...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  // Load chat history via HTTP as fallback
  Future<void> _loadChatHistoryViaHTTP() async {
    if (_clientId == null || _authToken == null) return;

    try {
      print('🌐 Loading chat history via HTTP fallback...');

      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/company/clients/$_clientId/chat-history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Backend now returns messages in descending order (newest first)
          // Reverse to show oldest first in chat UI
          final messages =
              List<Map<String, dynamic>>.from(data['data']).reversed.toList();
          for (var chat in messages) {
            _messageController.add(Map<String, dynamic>.from(chat));
          }
          print(
              '✅ Real chat history loaded via HTTP: ${data['data'].length} messages');
          return;
        }
      }

      print('❌ Failed to load chat history via HTTP: ${response.statusCode}');
    } catch (e) {
      print('❌ Exception loading chat history via HTTP: $e');
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
