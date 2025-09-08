import 'package:flutter/material.dart';

import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/vechile_list_item.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/client_vehicle_tracking_screen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/recent_chat_screen.dart';

import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/service/client_session_service.dart';

// Import for OpenStreetMap
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationMap extends StatefulWidget {
  final LatLng initialPosition;
  final String driverName;
  final String vehicleNumber;

  const LocationMap({
    Key? key,
    required this.initialPosition,
    required this.driverName,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  bool _isLiveLocationEnabled = true;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                // Handle map tap if needed
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.okdriver.app',
                maxZoom: 18,
                errorTileCallback: (tile, error, stackTrace) {
                  // Handle tile loading errors
                  debugPrint('Tile loading error: $error');
                },
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: widget.initialPosition,
                    child: _buildCarMarker(),
                  ),
                ],
              ),
            ],
          ),

          // Controls overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              children: [
                // Zoom controls
                _buildMapControl(
                  icon: Icons.add,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapControl(
                  icon: Icons.remove,
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom < 18.0) {
        _mapController.move(
          _mapController.camera.center,
          (currentZoom + 1).clamp(5.0, 18.0),
        );
      }
    } catch (e) {
      debugPrint('Error zooming in: $e');
    }
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom > 5.0) {
        _mapController.move(
          _mapController.camera.center,
          (currentZoom - 1).clamp(5.0, 18.0),
        );
      }
    } catch (e) {
      debugPrint('Error zooming out: $e');
    }
  }

  Widget _buildCarMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vehicle number card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.vehicleNumber.isNotEmpty ? widget.vehicleNumber : 'N/A',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        // Car icon with live indicator
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_car,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            if (_isLiveLocationEnabled)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// Vehicle class definition
class Vehicle {
  final String id;
  final String name;
  final String vehicleNumber;
  final String driverName;
  final String status;
  final DateTime lastUpdated;
  final LatLng location;

  Vehicle({
    required this.id,
    required this.name,
    required this.vehicleNumber,
    required this.driverName,
    required this.status,
    required this.lastUpdated,
    required this.location,
  });
}

class FleetClientBottomNavScreen extends StatefulWidget {
  @override
  _FleetClientBottomNavScreenState createState() =>
      _FleetClientBottomNavScreenState();
}

class _FleetClientBottomNavScreenState
    extends State<FleetClientBottomNavScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Removed FleetClientHomeScreen() from the screens list
    _screens = [
      const ClientVehicleTrackingScreen(),
      const RecentChatScreen(),
      ProfileScreen(),
    ];

    // Initialize client session service
    _initializeClientSession();
  }

  Future<void> _initializeClientSession() async {
    try {
      await ClientSessionService.instance.initialize();
      print('Client session service initialized successfully');
    } catch (e) {
      print('Error initializing client session service: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey : Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8.0,
        // Removed the Home tab from items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
