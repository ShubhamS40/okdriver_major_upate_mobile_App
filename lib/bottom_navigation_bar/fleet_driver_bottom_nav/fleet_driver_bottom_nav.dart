import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/fleet_client_bottom_nav.dart';
import 'dart:async';
import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/role_selection/driver_login_screen/driver_login_screen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/service/location_service.dart';
import 'package:okdriver/service/vehicle_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/recent_chat_screen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/select_user_scren.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/individual_chat_screen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/model/chat_type.dart';

// Import for OpenStreetMap
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FleetDriverLocationScreen extends StatefulWidget {
  @override
  _FleetDriverLocationScreenState createState() =>
      _FleetDriverLocationScreenState();
}

class _FleetDriverLocationScreenState extends State<FleetDriverLocationScreen> {
  final LocationService _locationService = LocationService.instance;
  String? _vehicleNumber;
  bool _isTracking = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadVehicleNumber();
    _startLocationTracking();

    // Update UI every second to show live status
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _isTracking = _locationService.isTracking;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVehicleNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final vehicleNumber =
        prefs.getString('current_vehicle_number') ?? 'Unknown Vehicle';
    setState(() {
      _vehicleNumber = vehicleNumber;
    });
  }

  Future<void> _startLocationTracking() async {
    if (_vehicleNumber == null || _vehicleNumber == 'Unknown Vehicle') {
      print('⚠️ No vehicle number available for location tracking');
      return;
    }

    final success =
        await _locationService.startLocationTracking(_vehicleNumber!);
    if (success) {
      print('✅ Location tracking started for $_vehicleNumber');
    } else {
      print('❌ Failed to start location tracking');
    }
  }

  void _stopLocationTracking() {
    _locationService.stopLocationTracking();
    print('🛑 Location tracking stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.location_on : Icons.location_off),
            onPressed:
                _isTracking ? _stopLocationTracking : _startLocationTracking,
            tooltip: _isTracking ? 'Stop Tracking' : 'Start Tracking',
          ),
        ],
      ),
      body: Column(
        children: [
          // Location Status Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isTracking ? Icons.location_on : Icons.location_off,
                        color: _isTracking ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isTracking
                            ? 'Location Tracking Active'
                            : 'Location Tracking Inactive',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isTracking ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Vehicle: ${_vehicleNumber ?? 'Loading...'}'),
                  const SizedBox(height: 8),
                  Text(
                      'Status: ${_isTracking ? 'Sending updates every 5 seconds' : 'Not tracking'}'),
                  if (_locationService.lastKnownPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                        'Last Update: ${_locationService.getFormattedLocation()}'),
                    if (_locationService.getSpeedKmh() != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          'Speed: ${_locationService.getSpeedKmh()!.toStringAsFixed(1)} km/h'),
                    ],
                    if (_locationService.getHeading() != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          'Heading: ${_locationService.getHeading()!.toStringAsFixed(0)}°'),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Map
          Expanded(
            child: LocationMap(
              initialPosition: _locationService.lastKnownPosition != null
                  ? LatLng(
                      _locationService.lastKnownPosition!.latitude,
                      _locationService.lastKnownPosition!.longitude,
                    )
                  : const LatLng(28.6139, 77.2090), // Default to Delhi, India
              driverName: 'Fleet Driver',
              vehicleNumber: _vehicleNumber ?? 'Unknown',
            ),
          ),
        ],
      ),
    );
  }
}

class FleetDriverChatScreen extends StatefulWidget {
  const FleetDriverChatScreen({Key? key}) : super(key: key);

  @override
  State<FleetDriverChatScreen> createState() => _FleetDriverChatScreenState();
}

class _FleetDriverChatScreenState extends State<FleetDriverChatScreen> {
  @override
  Widget build(BuildContext context) {
    return const RecentChatScreen();
  }
}

class ChatMessage {
  final String id;
  final String message;
  final String senderName;
  final String senderEmail;
  final bool isCompany;
  final DateTime timestamp;
  final bool isSentByMe;

  ChatMessage({
    required this.id,
    required this.message,
    required this.senderName,
    required this.senderEmail,
    required this.isCompany,
    required this.timestamp,
    required this.isSentByMe,
  });
}

class FleetDriverBottomNavScreen extends StatefulWidget {
  const FleetDriverBottomNavScreen({Key? key}) : super(key: key);

  @override
  _FleetDriverBottomNavScreenState createState() =>
      _FleetDriverBottomNavScreenState();
}

class _FleetDriverBottomNavScreenState
    extends State<FleetDriverBottomNavScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    FleetDriverLocationScreen(),
    const FleetDriverChatScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await VehicleAuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking auth status
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show login screen if not authenticated
    if (!_isLoggedIn) {
      return const DriverLoginScreen();
    }

    // Access the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey : Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Location',
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
