import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/fleet_client_bottom_nav.dart';
import 'package:okdriver/home_screen/homescreen.dart';
import 'package:okdriver/role_selection/client_login_screen/client_otp_screem.dart';
import 'package:okdriver/role_selection/client_login_screen/component/client_login_form.dart';
import 'package:okdriver/role_selection/client_login_screen/component/clinet_login_header.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:okdriver/service/api_config.dart';
import 'package:okdriver/service/client_session_service.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({Key? key}) : super(key: key);

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  final _otpController = TextEditingController();

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
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final resp = await http
            .post(
              Uri.parse(ApiConfig.clientOtpSendUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': _emailController.text.trim()}),
            )
            .timeout(const Duration(seconds: 20));

        if (!mounted) return;

        if (resp.statusCode == 200) {
          setState(() {
            _otpSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent to ${_emailController.text}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          String msg = 'Failed to send OTP';
          try {
            final m = jsonDecode(resp.body);
            if (m['message'] is String) msg = m['message'];
          } catch (_) {}
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Network error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final resp = await http
            .post(
              Uri.parse(ApiConfig.clientOtpVerifyUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': _emailController.text.trim(),
                'code': _otpController.text.trim()
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (!mounted) return;

        if (resp.statusCode == 200) {
          try {
            final responseData = jsonDecode(resp.body);
            print('🔍 OTP verification response: $responseData');

            // Check if we have a token (successful verification)
            final token = responseData['token'] ?? responseData['accessToken'];

            if (token != null) {
              // Extract user data from response
              final userData = responseData['client'] ??
                  responseData['user'] ??
                  {
                    'email': _emailController.text.trim(),
                    'firstName': responseData['firstName'] ?? '',
                    'lastName': responseData['lastName'] ?? '',
                  };

              print('🔑 Token found: ${token.substring(0, 10)}...');
              print('👤 User data: $userData');

              // Store authentication data
              final loginSuccess = await ClientSessionService.instance.login(
                userData,
                token,
                DateTime.now()
                    .millisecondsSinceEpoch
                    .toString(), // Generate session ID
              );

              if (loginSuccess) {
                print('✅ Login successful, navigating to dashboard...');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('OTP verified! Redirecting...'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Navigate to client dashboard
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        FleetClientBottomNavScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);
                      return SlideTransition(
                          position: offsetAnimation, child: child);
                    },
                  ),
                );
              } else {
                throw Exception('Failed to store authentication data');
              }
            } else {
              // No token means verification failed
              String msg = responseData['message'] ?? 'Invalid or expired OTP';
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            }
          } catch (parseError) {
            print('❌ Error parsing OTP response: $parseError');
            print('📄 Raw response body: ${resp.body}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error processing response: $parseError'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          String msg = 'Invalid or expired OTP';
          try {
            final m = jsonDecode(resp.body);
            if (m['message'] is String) msg = m['message'];
          } catch (_) {}
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Network error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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
                    ClientLoginHeader(otpSent: _otpSent),

                    const SizedBox(height: 40),

                    // Login form
                    Expanded(
                      child: SingleChildScrollView(
                        child: ClientLoginForm(
                          formKey: _formKey,
                          emailController: _emailController,
                          otpController: _otpController,
                          isLoading: _isLoading,
                          otpSent: _otpSent,
                          onSendOTP: _sendOTP,
                          onVerifyOTP: _verifyOTP,
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
