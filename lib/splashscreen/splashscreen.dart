import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/permissionscreen/permissionscreen.dart';
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

    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

    if (mounted) {
      final sessionService = UserSessionService.instance;

      if (sessionService.isLoggedIn) {
        // User is logged in, go to main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PermissionScreen()),
        );
      } else {
        // User is not logged in, go to permission screen (which leads to login)
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
