import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/fleet_client_bottom_nav.dart';
import 'dart:async';
import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';
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
import 'package:okdriver/language/app_localizations.dart';

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
    _checkInitialTrackingStatus();

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

  Future<void> _checkInitialTrackingStatus() async {
    setState(() {
      _isTracking = _locationService.isTracking;
    });
  }

  Future<void> _toggleLocationSharing() async {
    if (_isTracking) {
      // Stop tracking
      _locationService.stopLocationTracking();
      print('🛑 Location tracking stopped');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.location_off, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Location sharing stopped',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } else {
      // Start tracking
      if (_vehicleNumber == null || _vehicleNumber == 'Unknown Vehicle') {
        print('⚠️ No vehicle number available for location tracking');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Vehicle number not available'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final success =
          await _locationService.startLocationTracking(_vehicleNumber!);

      if (success) {
        print('✅ Location tracking started for $_vehicleNumber');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Location sharing started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        print('❌ Failed to start location tracking');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to start location tracking'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Sharing Screen'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Simple Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isTracking ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isTracking ? Colors.green.shade200 : Colors.red.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isTracking ? Icons.check_circle : Icons.cancel,
                  color:
                      _isTracking ? Colors.green.shade700 : Colors.red.shade700,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _isTracking
                      ? 'Location Sharing Active'
                      : 'Location Sharing Inactive',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isTracking
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vehicle: ${_vehicleNumber ?? 'Loading...'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (_isTracking) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Updating every 5 seconds',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Large Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _toggleLocationSharing,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isTracking ? Colors.red.shade600 : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isTracking ? Icons.location_off : Icons.my_location,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isTracking
                          ? 'Stop Sharing Location'
                          : 'Start Sharing Location',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

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
              // isTracking: _isTracking,
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
    FleetDriverLocationScreen(),
    const FleetDriverChatScreen(),
    const ProfileScreen(mode: ProfileMode.fleetDriver),
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
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.location_on),
            label: AppLocalizations.of(context).translate('location'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat),
            label: AppLocalizations.of(context).translate('chat'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: AppLocalizations.of(context).translate('profile'),
          ),
        ],
      ),
    );
  }
}
