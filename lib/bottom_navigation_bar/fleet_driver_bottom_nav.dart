import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/components/chat_input_field.dart';
import 'package:okdriver/bottom_navigation_bar/components/chat_message_bubble.dart';
import 'package:okdriver/bottom_navigation_bar/components/location_map.dart';
import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';

// Import for OpenStreetMap
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FleetDriverLocationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location'),
        backgroundColor: Colors.blue,
      ),
      body: LocationMap(
        initialPosition: LatLng(28.6139, 77.2090), // Default to Delhi, India
        driverName: 'Rahul Singh',
        vehicleNumber: 'DL 01 AB 1234',
      ),
    );
  }
}

class FleetDriverChatScreen extends StatefulWidget {
  @override
  _FleetDriverChatScreenState createState() => _FleetDriverChatScreenState();
}

class _FleetDriverChatScreenState extends State<FleetDriverChatScreen> {
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
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatMessageBubble(
                        message: message.message,
                        senderName: message.senderName,
                        senderEmail: message.senderEmail,
                        isCompany: message.isCompany,
                        timestamp: message.timestamp,
                        isSentByMe: message.isSentByMe,
                      );
                    },
                  ),
          ),

          // Input field
          ChatInputField(
            onSendMessage: _handleSendMessage,
            isLoading: _isLoading,
          ),
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
    FleetDriverChatScreen(),
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
