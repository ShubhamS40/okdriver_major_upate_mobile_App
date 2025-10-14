import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:okdriver/service/api_config.dart';
import 'package:okdriver/service/websocket_location_service.dart';
import 'package:okdriver/service/client_session_service.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/vehicle_location_history_screen.dart';

class ClientVehicleTrackingScreen extends StatefulWidget {
  const ClientVehicleTrackingScreen({Key? key}) : super(key: key);

  @override
  State<ClientVehicleTrackingScreen> createState() =>
      _ClientVehicleTrackingScreenState();
}

class _ClientVehicleTrackingScreenState
    extends State<ClientVehicleTrackingScreen> {
  final MapController _mapController = MapController();
  final WebSocketLocationService _webSocketService =
      WebSocketLocationService.instance;

  List<Map<String, dynamic>> _assignedVehicles = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isLiveTrackingEnabled = true;

  // Map state
  LatLng _mapCenter = const LatLng(20.5937, 78.9629); // Default to India center
  double _mapZoom = 5.0;

  // WebSocket subscription
  Set<String> _subscribedVehicles = {};

  @override
  void initState() {
    super.initState();
    _initializeTracking();

    // Wait for the map to be ready before using the controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // The map should be ready now
        print('🗺️ Map initialized and ready');
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _unsubscribeFromAllVehicles();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Check authentication first
      await ClientSessionService.instance.initialize();
      if (!ClientSessionService.instance.isLoggedIn) {
        setState(() {
          _errorMessage = 'Please login to access vehicle tracking';
          _isLoading = false;
        });
        return;
      }

      // Connect to WebSocket for real-time updates
      await _webSocketService.connect();

      // Load assigned vehicles
      await _loadAssignedVehicles();

      // Start periodic refresh
      _startPeriodicRefresh();

      // Listen to WebSocket updates
      _setupWebSocketListener();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize tracking: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAssignedVehicles() async {
    try {
      setState(() => _isLoading = true);

      final token = await _getClientToken();
      print('🔑 Client token: ${token != null ? 'Found' : 'Not found'}');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      print(
          '🌐 Making API request to: ${ApiConfig.baseUrl}/api/company/clients/assigned-vehicles');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/company/clients/assigned-vehicles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _assignedVehicles = List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });

          // Subscribe to WebSocket updates for all vehicles
          _subscribeToAllVehicles();

          // Update map center if vehicles have locations
          _updateMapCenter();
        } else {
          throw Exception(data['message'] ?? 'Failed to load vehicles');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load vehicles: $e';
        _isLoading = false;
      });
    }
  }

  Future<String?> _getClientToken() async {
    // Initialize the client session service if not already done
    await ClientSessionService.instance.initialize();
    return ClientSessionService.instance.authToken;
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isLiveTrackingEnabled) {
        _loadAssignedVehicles();
      }
    });
  }

  void _setupWebSocketListener() {
    _webSocketService.locationUpdates.listen((update) {
      _handleLocationUpdate(update);
    });
  }

  void _subscribeToAllVehicles() {
    for (final vehicle in _assignedVehicles) {
      final vehicleNumber = vehicle['vehicleNumber'];
      if (vehicleNumber != null &&
          !_subscribedVehicles.contains(vehicleNumber)) {
        _webSocketService.subscribeToVehicle(vehicleNumber);
        _subscribedVehicles.add(vehicleNumber);
      }
    }
  }

  void _unsubscribeFromAllVehicles() {
    for (final vehicleNumber in _subscribedVehicles) {
      _webSocketService.unsubscribeFromVehicle(vehicleNumber);
    }
    _subscribedVehicles.clear();
  }

  void _handleLocationUpdate(Map<String, dynamic> update) {
    final vehicleNumber = update['vehicleNumber'];
    final locationData = update['location'];

    setState(() {
      final vehicleIndex = _assignedVehicles
          .indexWhere((v) => v['vehicleNumber'] == vehicleNumber);

      if (vehicleIndex != -1) {
        _assignedVehicles[vehicleIndex]['currentLocation'] = locationData;
        _assignedVehicles[vehicleIndex]['lastUpdate'] =
            DateTime.now().toIso8601String();
      }
    });
  }

  void _updateMapCenter() {
    final vehiclesWithLocation =
        _assignedVehicles.where((v) => v['currentLocation'] != null).toList();

    if (vehiclesWithLocation.isNotEmpty) {
      double totalLat = 0;
      double totalLng = 0;
      int count = 0;

      for (final vehicle in vehiclesWithLocation) {
        final location = vehicle['currentLocation'];
        if (location != null) {
          totalLat += location['lat'];
          totalLng += location['lng'];
          count++;
        }
      }

      if (count > 0) {
        setState(() {
          _mapCenter = LatLng(totalLat / count, totalLng / count);
          _mapZoom = count == 1 ? 15.0 : 10.0;
        });

        // Only move map controller if the map is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_mapCenter, _mapZoom);
          }
        });
      }
    }
  }

  void _toggleLiveTracking() {
    setState(() {
      _isLiveTrackingEnabled = !_isLiveTrackingEnabled;
    });

    if (_isLiveTrackingEnabled) {
      _startPeriodicRefresh();
      _subscribeToAllVehicles();
    } else {
      _refreshTimer?.cancel();
      _unsubscribeFromAllVehicles();
    }
  }

  void _refreshData() {
    _loadAssignedVehicles();
  }

  void _logout() async {
    try {
      await ClientSessionService.instance.logout();

      if (mounted) {
        // Navigate back to role selection or login
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/role-selection',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/role-selection',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Vehicle Tracking'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(_isLiveTrackingEnabled
                ? Icons.location_on
                : Icons.location_off),
            onPressed: _toggleLiveTracking,
            tooltip: _isLiveTrackingEnabled
                ? 'Live Tracking ON'
                : 'Live Tracking OFF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_errorMessage == 'Please login to access vehicle tracking') ...[
              ElevatedButton(
                onPressed: _goToLogin,
                child: const Text('Go to Login'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    if (_assignedVehicles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Vehicles Assigned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'You don\'t have access to any vehicles yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Vehicle summary cards
        _buildVehicleSummaryCards(),

        // Map
        Expanded(
          child: _buildMap(),
        ),
      ],
    );
  }

  Widget _buildVehicleSummaryCards() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _assignedVehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _assignedVehicles[index];
          return _buildVehicleCard(vehicle);
        },
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final currentLocation = vehicle['currentLocation'];
    final speed = currentLocation?['speedKph'];
    final lastUpdate = vehicle['lastUpdate'];

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 8),
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: () => _focusOnVehicle(vehicle),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: _getVehicleStatusColor(vehicle['status']),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicle['vehicleNumber'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle['type'] ?? 'Unknown'} - ${vehicle['model'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (currentLocation != null) ...[
                  Row(
                    children: [
                      Icon(Icons.speed, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text(
                        speed != null
                            ? '${speed.toStringAsFixed(1)} km/h'
                            : 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatLastUpdate(lastUpdate),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'No location data',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        onMapReady: () {
          print('🗺️ FlutterMap is ready and rendered');
        },
        onTap: (tapPosition, point) {
          // Handle map tap if needed
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.okdriver.app',
          maxZoom: 18,
        ),
        MarkerLayer(
          markers: _buildVehicleMarkers(),
        ),
        // Add route layer if needed for navigation
      ],
    );
  }

  List<Marker> _buildVehicleMarkers() {
    final markers = <Marker>[];

    for (final vehicle in _assignedVehicles) {
      final currentLocation = vehicle['currentLocation'];
      if (currentLocation != null) {
        final lat = currentLocation['lat'];
        final lng = currentLocation['lng'];
        final heading = currentLocation['headingDeg'];
        final speed = currentLocation['speedKph'];

        markers.add(
          Marker(
            width: 60.0,
            height: 60.0,
            point: LatLng(lat, lng),
            child: _buildVehicleMarker(vehicle, heading, speed),
          ),
        );
      }
    }

    return markers;
  }

  Widget _buildVehicleMarker(
      Map<String, dynamic> vehicle, int? heading, double? speed) {
    return GestureDetector(
      onTap: () => _showVehicleDetails(vehicle),
      child: Column(
        children: [
          // Vehicle icon with rotation
          Transform.rotate(
            angle: heading != null ? (heading * 3.14159) / 180 : 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Speed indicator
          if (speed != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getVehicleStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'INACTIVE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatLastUpdate(String? lastUpdate) {
    if (lastUpdate == null) return 'Never';

    try {
      final updateTime = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(updateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _focusOnVehicle(Map<String, dynamic> vehicle) {
    final currentLocation = vehicle['currentLocation'];
    if (currentLocation != null) {
      final lat = currentLocation['lat'];
      final lng = currentLocation['lng'];

      setState(() {
        _mapCenter = LatLng(lat, lng);
        _mapZoom = 15.0;
      });

      // Only move map controller if the map is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(_mapCenter, _mapZoom);
        }
      });
    }
  }

  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildVehicleDetailsSheet(vehicle),
    );
  }

  Widget _buildVehicleDetailsSheet(Map<String, dynamic> vehicle) {
    final currentLocation = vehicle['currentLocation'];
    final speed = currentLocation?['speedKph'];
    final heading = currentLocation?['headingDeg'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car,
                size: 32,
                color: _getVehicleStatusColor(vehicle['status']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle['vehicleNumber'],
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      '${vehicle['type'] ?? 'Unknown'} - ${vehicle['model'] ?? 'N/A'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 32),
          if (currentLocation != null) ...[
            _buildDetailRow('Location',
                '${currentLocation['lat'].toStringAsFixed(6)}, ${currentLocation['lng'].toStringAsFixed(6)}'),
            _buildDetailRow('Speed',
                speed != null ? '${speed.toStringAsFixed(1)} km/h' : 'N/A'),
            _buildDetailRow('Heading', heading != null ? '${heading}°' : 'N/A'),
            _buildDetailRow(
                'Last Update', _formatLastUpdate(vehicle['lastUpdate'])),
          ] else ...[
            const Text(
              'No location data available',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentLocation != null
                      ? () => _navigateToVehicle(vehicle)
                      : null,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewLocationHistory(vehicle),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToVehicle(Map<String, dynamic> vehicle) {
    final currentLocation = vehicle['currentLocation'];
    if (currentLocation != null) {
      final lat = currentLocation['lat'];
      final lng = currentLocation['lng'];

      // Open in external navigation app
      final url =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

      // You can use url_launcher package to open this URL
      // launchUrl(Uri.parse(url));

      // For now, just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening navigation to ${vehicle['vehicleNumber']}'),
          action: SnackBarAction(
            label: 'Copy Coordinates',
            onPressed: () {
              // Copy coordinates to clipboard
              // Clipboard.setData(ClipboardData(text: '$lat, $lng'));
            },
          ),
        ),
      );

      Navigator.pop(context); // Close bottom sheet
    }
  }

  void _viewLocationHistory(Map<String, dynamic> vehicle) {
    // Navigate to location history screen
    Navigator.pop(context); // Close bottom sheet

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleLocationHistoryScreen(vehicle: vehicle),
      ),
    );
  }
}
