import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

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

      if (_vehicleToken == null || _vehicleId == null) {
        print('❌ Vehicle token or ID not found');
        return;
      }

      _socket = IO.io(
          'http://localhost:5000',
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .setAuth({'token': _vehicleToken})
              .enableAutoConnect()
              .build());

      _socket!.onConnect((_) {
        print('✅ Connected to socket server');
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

    _socket!.emit('driver:send_message_to_company', {
      'message': message,
      'attachmentUrl': attachmentUrl,
    });
  }

  // Get chat history
  void getChatHistory({int limit = 50, int offset = 0}) {
    if (!_isConnected || _socket == null) {
      print('❌ Socket not connected');
      return;
    }

    _socket!.emit('get_chat_history', {
      'limit': limit,
      'offset': offset,
    });
  }

  // Mark messages as read
  void markMessagesAsRead(List<int> messageIds) {
    if (!_isConnected || _socket == null) {
      print('❌ Socket not connected');
      return;
    }

    _socket!.emit('mark_messages_read', {
      'messageIds': messageIds,
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

  // Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
