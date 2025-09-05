import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/fleet_client_bottom_nav.dart';
import 'dart:async';
import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/service/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class FleetDriverChatScreenOld extends StatefulWidget {
  @override
  _FleetDriverChatScreenOldState createState() =>
      _FleetDriverChatScreenOldState();
}

class _FleetDriverChatScreenOldState extends State<FleetDriverChatScreenOld> {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load sample messages
    _loadSampleMessages();
  }

  void _loadSampleMessages() {
    final now = DateTime.now();

    _messages.addAll([
      ChatMessage(
        id: '1',
        message: 'Good morning! Your shift starts at 9:00 AM today.',
        senderName: 'OK Driver Fleet',
        senderEmail: 'fleet@okdriver.com',
        isCompany: true,
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isSentByMe: false,
      ),
      ChatMessage(
        id: '2',
        message: 'Good morning! I will be starting my shift on time.',
        senderName: 'Rahul Singh',
        senderEmail: 'rahul.s@gmail.com',
        isCompany: false,
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 45)),
        isSentByMe: true,
      ),
      ChatMessage(
        id: '3',
        message: 'Please pick up the delivery from Warehouse B by 10:30 AM.',
        senderName: 'OK Driver Fleet',
        senderEmail: 'fleet@okdriver.com',
        isCompany: true,
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
        isSentByMe: false,
      ),
      ChatMessage(
        id: '4',
        message:
            'I have reached Warehouse B and will pick up the delivery shortly.',
        senderName: 'Rahul Singh',
        senderEmail: 'rahul.s@gmail.com',
        isCompany: false,
        timestamp: now.subtract(const Duration(hours: 22)),
        isSentByMe: true,
      ),
      ChatMessage(
        id: '5',
        message: 'Your next delivery is scheduled for 2:00 PM at City Mall.',
        senderName: 'OK Driver Fleet',
        senderEmail: 'fleet@okdriver.com',
        isCompany: true,
        timestamp: now.subtract(const Duration(hours: 4)),
        isSentByMe: false,
      ),
      ChatMessage(
        id: '6',
        message: 'I am facing heavy traffic. Might be delayed by 15 minutes.',
        senderName: 'Rahul Singh',
        senderEmail: 'rahul.s@gmail.com',
        isCompany: false,
        timestamp: now.subtract(const Duration(hours: 2)),
        isSentByMe: true,
      ),
      ChatMessage(
        id: '7',
        message: 'No problem. Please drive safely and update when you reach.',
        senderName: 'OK Driver Fleet',
        senderEmail: 'fleet@okdriver.com',
        isCompany: true,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
        isSentByMe: false,
      ),
    ]);
  }

  void _handleSendMessage(String message) {
    if (message.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate sending message
    Future.delayed(const Duration(milliseconds: 500), () {
      final newMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: message,
        senderName: 'Rahul Singh',
        senderEmail: 'rahul.s@gmail.com',
        isCompany: false,
        timestamp: DateTime.now(),
        isSentByMe: true,
      );

      setState(() {
        _messages.add(newMessage);
        _isLoading = false;
      });

      // Simulate company reply after a delay
      if (_messages.length % 2 == 0) {
        _simulateCompanyReply();
      }
    });
  }

  void _simulateCompanyReply() {
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message:
                'Thank you for the update. Please continue to follow safety protocols.',
            senderName: 'OK Driver Fleet',
            senderEmail: 'fleet@okdriver.com',
            isCompany: true,
            timestamp: DateTime.now(),
            isSentByMe: false,
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 18,
              child: Icon(
                Icons.business,
                color: Colors.blue.shade700,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OK Driver Fleet',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Handle call action
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    padding: const EdgeInsets.all(16),
                    reverse: false,
                    itemBuilder: (context, index) {},
                  ),
          ),

          // Input field
        ],
      ),
    );
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

  final List<Widget> _screens = [
    HomeScreen(),
    FleetDriverLocationScreen(),
    ProfileScreen(),
  ];

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
