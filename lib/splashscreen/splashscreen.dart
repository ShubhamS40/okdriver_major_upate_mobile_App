import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/bottom_navigation_bar/bottom_navigation_bar.dart';
import 'package:okdriver/role_selection/role_selection.dart';
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
        // User is logged in -> go directly to app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BottomNavScreen()),
        );
      } else {
        // User not logged-in -> go to role selection / login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
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
