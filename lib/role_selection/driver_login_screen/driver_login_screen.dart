import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav.dart';
import 'package:okdriver/role_selection/driver_login_screen/components/driver_login_form.dart';
import 'package:okdriver/role_selection/driver_login_screen/components/driver_login_header.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({Key? key}) : super(key: key);

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _vehicleNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate login process
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });

        // Check if this is a fleet operator driver login
        // In a real app, this would be determined by API response
        bool isFleetOperatorDriver =
            true; // For now, always true as per requirements

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Login successful! Navigating to Home Screen...')),
        );

        // Navigate to home screen after successful login
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  isFleetOperatorDriver
                      ? FleetDriverBottomNavScreen()
                      : HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
            (route) => false,
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0A0A),
                  Colors.black,
                  const Color(0xFF1A1A1A).withOpacity(0.3),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 20),

                    // Header
                    const DriverLoginHeader(),

                    const SizedBox(height: 40),

                    // Login form
                    Expanded(
                      child: SingleChildScrollView(
                        child: DriverLoginForm(
                          formKey: _formKey,
                          vehicleNumberController: _vehicleNumberController,
                          passwordController: _passwordController,
                          isLoading: _isLoading,
                          onLogin: _handleLogin,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
