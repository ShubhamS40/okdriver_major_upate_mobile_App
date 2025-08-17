import 'package:flutter/material.dart';
import 'package:okdriver/dashcam/components/camera_selection.dart';
import 'package:okdriver/driver_profile_screen/driver_profile_screen.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class BottomNavScreen extends StatefulWidget {
  @override
  _BottomNavScreenState createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    CameraSelectionScreen(),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Dashcam',
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
