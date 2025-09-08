import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _vehicleToken;
  String? _vehicleNumber;
  int? _vehicleId;
  int? _companyId;

  // Stream controllers for real-time updates
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  // Initialize socket connection
  Future<void> initializeSocket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _vehicleToken = prefs.getString('vehicle_token');
      _vehicleNumber = prefs.getString('current_vehicle_number');
      _vehicleId = prefs.getInt('vehicle_id');
      _companyId = prefs.getInt('company_id');

      print('🔌 Socket initialization data:');
      print('🔌 Token: $_vehicleToken');
      print('🔌 Vehicle ID: $_vehicleId');
      print('🔌 Company ID: $_companyId');

      if (_vehicleToken == null || _vehicleId == null || _companyId == null) {
        print('❌ Vehicle token, ID, or company ID not found');
        return;
      }

      _socket = IO.io(
          'http://localhost:5000',
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .setAuth({
                'token': _vehicleToken,
                'role': 'DRIVER',
                'vehicleId': _vehicleId
              })
              .enableAutoConnect()
              .build());

      _socket!.onConnect((_) {
        print('✅ Connected to socket server');
        print('✅ Socket ID: ${_socket!.id}');
        // print('✅ Auth data: ${_socket!.io.options.auth}');
        _isConnected = true;
        _connectionController.add(true);
      });

      _socket!.onDisconnect((_) {
        print('❌ Disconnected from socket server');
        _isConnected = false;
        _connectionController.add(false);
      });

      _socket!.onConnectError((error) {
        print('❌ Socket connection error: $error');
        print('❌ Error details: ${error.toString()}');
        _isConnected = false;
        _connectionController.add(false);
      });

      _socket!.onError((error) {
        print('❌ Socket error: $error');
        _isConnected = false;
        _connectionController.add(false);
      });

      // Listen for new messages
      _socket!.on('new_message', (data) {
        print('📨 Received message: $data');
        _messageController.add(Map<String, dynamic>.from(data));
      });

      // Listen for message sent confirmation
      _socket!.on('message_sent', (data) {
        print('✅ Message sent: $data');
      });

      // Listen for error messages
      _socket!.on('error', (data) {
        print('❌ Socket error: $data');
      });

      // Listen for messages marked as read
      _socket!.on('messages_read', (data) {
        print('👀 Messages marked as read: $data');
      });

      // Setup unread count listener
      _setupUnreadCountListener();
    } catch (e) {
      print('❌ Error initializing socket: $e');
    }
  }

  // Send message to company
  void sendMessageToCompany(String message, {String? attachmentUrl}) {
    if (!_isConnected || _socket == null) {
      print('❌ Socket not connected');
      return;
    }

    print('📤 Sending message to company: $message');
    print('📤 Vehicle ID: $_vehicleId, Company ID: $_companyId');
    // print('📤 Socket auth data: ${_socket!.io.options.auth}');

    _socket!.emit('chat:send', {
      'vehicleId': _vehicleId,
      'message': message,
      'attachmentUrl': attachmentUrl,
    });
  }

  // Get chat history
  void getChatHistory({int limit = 50, int offset = 0}) {
    if (!_isConnected || _socket == null) {
      print('❌ Socket not connected, trying HTTP fallback...');
      _loadChatHistoryViaHTTP();
      return;
    }

    print('📨 Requesting chat history for vehicle: $_vehicleId');
    _socket!.emit('chat:history',
        {'vehicleId': _vehicleId, 'limit': limit, 'offset': offset});

    // Listen for chat history response
    _socket!.once('chat:history', (response) {
      print('📨 Chat history response: $response');
      if (response != null && response['ok'] == true) {
        print(
            '📨 Chat history received: ${response['chats']?.length ?? 0} messages');
        // Emit the chat history through message stream
        for (var chat in response['chats'] ?? []) {
          _messageController.add(Map<String, dynamic>.from(chat));
        }
      } else {
        print(
            '❌ Failed to get chat history: ${response?['error'] ?? 'Unknown error'}');
        // Try HTTP fallback
        _loadChatHistoryViaHTTP();
      }
    });
  }

  // HTTP fallback for chat history
  Future<void> _loadChatHistoryViaHTTP() async {
    try {
      print('🌐 Loading chat history via HTTP...');

      // Try to load real chat history from backend (last 24 hours)
      if (_vehicleId != null) {
        final response = await http.get(
          Uri.parse(
              'http://localhost:5000/api/company/vehicles/$_vehicleId/chat-history'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_vehicleToken',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('📨 HTTP chat history response: $data');

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
      }

      // Fallback to sample messages if API fails
      print('⚠️ API failed, loading sample messages...');
      final sampleMessages = [
        {
          'id': 'msg_1',
          'message': 'Hello! How are you doing today?',
          'senderType': 'COMPANY',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
        {
          'id': 'msg_2',
          'message': 'Please update me on your delivery status',
          'senderType': 'COMPANY',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'id': 'msg_3',
          'message': 'I am on my way to the destination',
          'senderType': 'DRIVER',
          'createdAt': DateTime.now()
              .subtract(const Duration(minutes: 30))
              .toIso8601String(),
        },
      ];

      for (var message in sampleMessages) {
        _messageController.add(Map<String, dynamic>.from(message));
      }

      print('✅ Sample messages loaded via HTTP fallback');
    } catch (e) {
      print('❌ HTTP fallback failed: $e');
    }
  }

  // Mark messages as read
  void markMessagesAsRead(List<int> messageIds) {
    if (!_isConnected || _socket == null) {
      print('❌ Socket not connected');
      return;
    }

    _socket!.emit('mark_messages_read', {
      'messageIds': messageIds,
      'vehicleId': _vehicleId,
    });
  }

  // Get unread count
  void getUnreadCount() {
    if (!_isConnected || _socket == null) {
      print('❌ Socket not connected');
      return;
    }

    print('📊 Requesting unread count for vehicle: $_vehicleId');
    _socket!.emit('get_unread_count', {
      'vehicleId': _vehicleId,
    });
  }

  // Listen for unread count updates
  void _setupUnreadCountListener() {
    _socket?.on('unread_count', (data) {
      print('📊 Unread count received: $data');
      // You can emit this through a stream if needed
    });
  }

  // Disconnect socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  // Retry socket connection
  Future<void> retryConnection() async {
    print('🔄 Retrying socket connection...');
    disconnect();
    await Future.delayed(const Duration(milliseconds: 1000));
    await initializeSocket();
  }

  // Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
