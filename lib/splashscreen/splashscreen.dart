import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/permissionscreen/permissionscreen.dart';
import 'package:okdriver/bottom_navigation_bar/bottom_navigation_bar.dart';
import 'package:okdriver/service/usersession_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _navigateToNextScreen();
  }

  _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

    if (mounted) {
      final sessionService = UserSessionService.instance;

      if (sessionService.isLoggedIn && sessionService.authToken != null) {
        // User is logged in, verify session with backend
        try {
          final userData = await sessionService.fetchCurrentUserData();
          if (userData != null) {
            // Session is valid, go to main app
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BottomNavScreen()),
            );
          } else {
            // Session expired or invalid, go to login
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PermissionScreen()),
            );
          }
        } catch (e) {
          print('Error verifying session: $e');
          // On error, go to login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PermissionScreen()),
          );
        }
      } else {
        // User is not logged in, go to permission screen (which leads to role selection)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PermissionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splashscreen.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
