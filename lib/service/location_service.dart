import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:okdriver/service/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okdriver/service/websocket_location_service.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  Timer? _locationTimer;
  bool _isTracking = false;
  String? _currentVehicleNumber;
  StreamSubscription<Position>? _positionStream;

  // WebSocket service for real-time updates
  final WebSocketLocationService _webSocketService =
      WebSocketLocationService.instance;

  // Location tracking state
  Position? _lastKnownPosition;
  DateTime? _lastUpdateTime;

  // API call state
  bool _isUpdatingLocation = false;
  int _consecutiveFailures = 0;
  static const int _maxFailures = 5;

  /// Start location tracking for a specific vehicle
  Future<bool> startLocationTracking(String vehicleNumber) async {
    try {
      print('🚀 Starting location tracking for vehicle: $vehicleNumber');

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return false;
      }

      // Store vehicle number
      _currentVehicleNumber = vehicleNumber;
      await _saveVehicleNumber(vehicleNumber);

      // Connect to WebSocket for real-time updates
      await _webSocketService.connect();
      _webSocketService.subscribeToVehicle(vehicleNumber);

      // Start periodic location updates every 5 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _updateLocation();
      });

      // Also start high-accuracy position stream for real-time updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update if moved 10+ meters
        ),
      ).listen(
        (Position position) {
          _lastKnownPosition = position;
          _lastUpdateTime = DateTime.now();
          print(
              '📍 New position received: ${position.latitude}, ${position.longitude}');
        },
        onError: (error) {
          print('❌ Position stream error: $error');
        },
      );

      _isTracking = true;
      print('✅ Location tracking started successfully');
      return true;
    } catch (e) {
      print('❌ Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    print('🛑 Stopping location tracking');

    _locationTimer?.cancel();
    _locationTimer = null;

    _positionStream?.cancel();
    _positionStream = null;

    // Unsubscribe from WebSocket and disconnect
    if (_currentVehicleNumber != null) {
      _webSocketService.unsubscribeFromVehicle(_currentVehicleNumber!);
    }
    _webSocketService.disconnect();

    _isTracking = false;
    _currentVehicleNumber = null;
    _lastKnownPosition = null;
    _lastUpdateTime = null;

    print('✅ Location tracking stopped');
  }

  /// Update location and send to backend
  Future<void> _updateLocation() async {
    if (!_isTracking || _currentVehicleNumber == null) {
      print('⚠️ Cannot update location: tracking not active or no vehicle');
      return;
    }

    if (_isUpdatingLocation) {
      print('⚠️ Location update already in progress, skipping');
      return;
    }

    try {
      _isUpdatingLocation = true;

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastKnownPosition = position;
      _lastUpdateTime = DateTime.now();

      print(
          '📍 Location update: ${position.latitude}, ${position.longitude} at ${DateTime.now()}');

      // Send to backend
      await _sendLocationToBackend(position);

      // Reset failure counter on success
      _consecutiveFailures = 0;
    } catch (e) {
      print('❌ Error updating location: $e');
      _consecutiveFailures++;

      if (_consecutiveFailures >= _maxFailures) {
        print('⚠️ Too many consecutive failures, stopping location updates');
        stopLocationTracking();
      }
    } finally {
      _isUpdatingLocation = false;
    }
  }

  /// Send location data to backend API
  Future<void> _sendLocationToBackend(Position position) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.vehicleLocationUpdateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'vehicleNumber': _currentVehicleNumber,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'speedKph': position.speed * 3.6, // Convert m/s to km/h
              'headingDeg': position.heading.toInt(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Location sent to backend: ${data['message']}');
      } else {
        print(
            '❌ Backend location update failed: ${response.statusCode} - ${response.body}');
        throw Exception('Backend update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending location to backend: $e');
      rethrow;
    }
  }

  /// Get current tracking status
  bool get isTracking => _isTracking;
  String? get currentVehicleNumber => _currentVehicleNumber;
  Position? get lastKnownPosition => _lastKnownPosition;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Save vehicle number to SharedPreferences
  Future<void> _saveVehicleNumber(String vehicleNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_vehicle_number', vehicleNumber);
    } catch (e) {
      print('❌ Error saving vehicle number: $e');
    }
  }

  /// Load vehicle number from SharedPreferences
  Future<String?> _loadVehicleNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('current_vehicle_number');
    } catch (e) {
      print('❌ Error loading vehicle number: $e');
      return null;
    }
  }

  /// Resume tracking if vehicle number is stored
  Future<bool> resumeTrackingIfPossible() async {
    final vehicleNumber = await _loadVehicleNumber();
    if (vehicleNumber != null && !_isTracking) {
      print('🔄 Resuming location tracking for vehicle: $vehicleNumber');
      return await startLocationTracking(vehicleNumber);
    }
    return false;
  }

  /// Get formatted location string
  String getFormattedLocation() {
    if (_lastKnownPosition == null) return 'No location data';

    final lat = _lastKnownPosition!.latitude.toStringAsFixed(6);
    final lng = _lastKnownPosition!.longitude.toStringAsFixed(6);
    final time = _lastUpdateTime?.toString().substring(11, 19) ?? 'Unknown';

    return 'Lat: $lat, Lng: $lng (Updated: $time)';
  }

  /// Get speed in km/h
  double? getSpeedKmh() {
    if (_lastKnownPosition?.speed == null) return null;
    return _lastKnownPosition!.speed * 3.6;
  }

  /// Get heading in degrees
  double? getHeading() {
    return _lastKnownPosition?.heading;
  }
}
