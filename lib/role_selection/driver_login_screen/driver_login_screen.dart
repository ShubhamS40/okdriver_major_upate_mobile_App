import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/fleet_driver_bottom_nav.dart';
// import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:okdriver/service/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await http
            .post(
              Uri.parse(ApiConfig.vehicleLoginUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'vehicleNumber': _vehicleNumberController.text.trim(),
                'password': _passwordController.text,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // Store vehicle and company information
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'current_vehicle_number', _vehicleNumberController.text.trim());
          await prefs.setString('vehicle_token', data['data']['token']);
          await prefs.setInt('vehicle_id', data['data']['vehicle']['id']);
          await prefs.setInt('company_id', data['data']['company']['id']);
          await prefs.setString(
              'company_name', data['data']['company']['name']);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful! Navigating...')),
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    FleetDriverBottomNavScreen(),
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
        } else {
          String errorMessage = 'Login failed';
          try {
            final err = jsonDecode(response.body);
            if (err is Map && err['message'] is String) {
              errorMessage = err['message'];
            }
          } catch (_) {}

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF4CAF50)),
              SizedBox(width: 12),
              Text(
                'Forgot Password',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Please contact your company admin to reset your password.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
                          onForgotPassword: _handleForgotPassword,
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
