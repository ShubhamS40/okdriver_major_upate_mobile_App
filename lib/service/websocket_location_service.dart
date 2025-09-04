import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:okdriver/service/api_config.dart';

class WebSocketLocationService {
  static WebSocketLocationService? _instance;
  static WebSocketLocationService get instance =>
      _instance ??= WebSocketLocationService._();

  WebSocketLocationService._();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _currentVehicleNumber;

  // Stream controllers for different types of updates
  final StreamController<Map<String, dynamic>> _locationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get locationUpdates =>
      _locationUpdateController.stream;
  Stream<String> get connectionStatus => _connectionStatusController.stream;
  Stream<String> get errors => _errorController.stream;

  // Connection status
  bool get isConnected => _isConnected;
  String? get currentVehicleNumber => _currentVehicleNumber;

  /// Connect to WebSocket server
  Future<bool> connect() async {
    try {
      if (_isConnected) {
        print('⚠️ Already connected to WebSocket');
        return true;
      }

      final wsUrl = ApiConfig.baseUrl.replaceFirst('http', 'ws') + '/ws';
      print('🔌 Connecting to WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for messages
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _handleError('WebSocket error: $error'),
        onDone: () => _handleDisconnection(),
      );

      _isConnected = true;
      _connectionStatusController.add('connected');
      print('✅ WebSocket connected successfully');

      return true;
    } catch (e) {
      _handleError('Failed to connect: $e');
      return false;
    }
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    try {
      if (_channel != null) {
        _channel!.sink.close(status.goingAway);
        _channel = null;
      }
      _isConnected = false;
      _currentVehicleNumber = null;
      _connectionStatusController.add('disconnected');
      print('🛑 WebSocket disconnected');
    } catch (e) {
      print('❌ Error disconnecting WebSocket: $e');
    }
  }

  /// Subscribe to location updates for a specific vehicle
  void subscribeToVehicle(String vehicleNumber) {
    if (!_isConnected) {
      _handleError('Cannot subscribe: WebSocket not connected');
      return;
    }

    try {
      final message = {
        'type': 'subscribe_vehicle',
        'vehicleNumber': vehicleNumber,
      };

      _channel!.sink.add(jsonEncode(message));
      _currentVehicleNumber = vehicleNumber;
      print('📍 Subscribed to location updates for vehicle: $vehicleNumber');
    } catch (e) {
      _handleError('Failed to subscribe to vehicle: $e');
    }
  }

  /// Unsubscribe from location updates
  void unsubscribeFromVehicle(String vehicleNumber) {
    if (!_isConnected) {
      return;
    }

    try {
      final message = {
        'type': 'unsubscribe_vehicle',
        'vehicleNumber': vehicleNumber,
      };

      _channel!.sink.add(jsonEncode(message));

      if (_currentVehicleNumber == vehicleNumber) {
        _currentVehicleNumber = null;
      }

      print(
          '📍 Unsubscribed from location updates for vehicle: $vehicleNumber');
    } catch (e) {
      _handleError('Failed to unsubscribe from vehicle: $e');
    }
  }

  /// Send ping to keep connection alive
  void ping() {
    if (!_isConnected) return;

    try {
      final message = {
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      _handleError('Failed to send ping: $e');
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());

      switch (data['type']) {
        case 'connection_established':
          print('✅ WebSocket connection confirmed');
          break;

        case 'subscription_confirmed':
          print('✅ Vehicle subscription confirmed: ${data['vehicleNumber']}');
          break;

        case 'unsubscription_confirmed':
          print('✅ Vehicle unsubscription confirmed: ${data['vehicleNumber']}');
          break;

        case 'location_update':
          _handleLocationUpdate(data);
          break;

        case 'pong':
          // Handle pong response if needed
          break;

        case 'error':
          _handleError('Server error: ${data['message']}');
          break;

        default:
          print('⚠️ Unknown message type: ${data['type']}');
      }
    } catch (e) {
      _handleError('Failed to parse message: $e');
    }
  }

  /// Handle location update messages
  void _handleLocationUpdate(Map<String, dynamic> data) {
    try {
      final vehicleNumber = data['vehicleNumber'];
      final locationData = data['data'];
      final timestamp = data['timestamp'];

      final update = {
        'vehicleNumber': vehicleNumber,
        'location': locationData,
        'timestamp': timestamp,
        'receivedAt': DateTime.now().millisecondsSinceEpoch,
      };

      print(
          '📍 Location update received for vehicle $vehicleNumber: ${locationData['lat']}, ${locationData['lng']}');

      // Broadcast to subscribers
      _locationUpdateController.add(update);
    } catch (e) {
      _handleError('Failed to handle location update: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(String error) {
    print('❌ WebSocket error: $error');
    _errorController.add(error);
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    print('🔌 WebSocket disconnected');
    _isConnected = false;
    _currentVehicleNumber = null;
    _connectionStatusController.add('disconnected');

    // Attempt to reconnect after a delay
    Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('🔄 Attempting to reconnect...');
        connect();
      }
    });
  }

  /// Get current connection status
  String getConnectionStatus() {
    if (_isConnected) {
      return 'Connected';
    } else if (_channel != null) {
      return 'Connecting...';
    } else {
      return 'Disconnected';
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _locationUpdateController.close();
    _connectionStatusController.close();
    _errorController.close();
  }
}
