import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/fleet_client_bottom_nav.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/service/usersession_service.dart';
import 'package:okdriver/service/api_config.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:async';

// Import the fleet client bottom navigation
// import 'package:okdriver_3_0_mobile_app/fleet_client_bottom_nav/fleet_client_bottom_nav.dart';

class ClientOTPVerificationScreen extends StatefulWidget {
  final String phoneNumber; // Phone number with country code

  const ClientOTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<ClientOTPVerificationScreen> createState() =>
      _ClientOTPVerificationScreenState();
}

class _ClientOTPVerificationScreenState
    extends State<ClientOTPVerificationScreen> with TickerProviderStateMixin {
  late bool _isDarkMode = false;
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _loadingController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _loadingAnimation;

  bool _isLoading = false;
  bool _isResending = false;
  String _verificationMessage = '';
  bool _isOtpComplete = false;

  // Timer for resend OTP
  Timer? _timer;
  int _resendTimer = 30;
  bool _canResend = false;

  // Get device information
  Future<String> _getDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} - ${androidInfo.model}';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
      }
      return 'Unknown Device';
    } catch (e) {
      print('Error getting device info: $e');
      return 'Unknown Device';
    }
  }

  // Test backend connection
  Future<void> _testBackendConnection() async {
    try {
      print('Testing backend connection...');
      final response = await http.get(
        Uri.parse(ApiConfig.healthCheckUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('Backend connection test response: ${response.statusCode}');
      print('Backend connection test body: ${response.body}');

      if (response.statusCode == 200) {
        print('Backend connection successful');
      } else {
        print('Backend connection failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Backend connection test error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _testBackendConnection();

    // Initialize animation controllers
    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Setup animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOut,
    ));

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 1,
      ),
    ]).animate(_pulseController);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 10),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 10, end: -10),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -10, end: 10),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 10, end: -10),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -10, end: 0),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    ));

    _loadingController.repeat();
    _mainAnimationController.forward();

    // Start resend timer
    _startResendTimer();

    // Add listeners to OTP controllers
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].addListener(() {
        _checkOtpCompletion();
      });
    }
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 30;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  void _checkOtpCompletion() {
    bool isComplete = true;
    for (var controller in _otpControllers) {
      if (controller.text.isEmpty) {
        isComplete = false;
        break;
      }
    }

    if (isComplete != _isOtpComplete) {
      setState(() {
        _isOtpComplete = isComplete;
      });

      if (isComplete) {
        _pulseController.forward().then((_) => _pulseController.reset());
      }
    }
  }

  String _getOtpValue() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _verificationMessage = '';
    });

    try {
      // Simulate OTP verification
      await Future.delayed(const Duration(seconds: 2));

      // For demo purposes, any 6-digit OTP is considered valid
      final String otpValue = _getOtpValue();
      if (otpValue.length == 6) {
        // Successful verification
        _navigateToHome();
      } else {
        // Failed verification
        setState(() {
          _verificationMessage = 'Invalid OTP. Please try again.';
          _isLoading = false;
        });
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    } catch (e) {
      setState(() {
        _verificationMessage = 'Verification failed: ${e.toString()}';
        _isLoading = false;
      });
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _verificationMessage = '';
    });

    try {
      // Simulate OTP resend
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _verificationMessage = 'OTP resent successfully!';
        _isResending = false;
      });

      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }

      // Focus on first field
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }

      // Restart timer
      _startResendTimer();
    } catch (e) {
      setState(() {
        _verificationMessage = 'Failed to resend OTP: ${e.toString()}';
        _isResending = false;
      });
    }
  }

  void _navigateToHome() {
    // Navigate to the fleet client bottom navigation
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FleetClientBottomNavScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _loadingController.dispose();

    for (var controller in _otpControllers) {
      controller.dispose();
    }

    for (var node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
        elevation: 0,
        backgroundColor: _isDarkMode ? Colors.black : Colors.blue,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Verification Code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We have sent the verification code to\n${widget.phoneNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      6,
                      (index) => _buildOtpTextField(index),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_verificationMessage.isNotEmpty)
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _verificationMessage.contains('success')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _verificationMessage,
                          style: TextStyle(
                            color: _verificationMessage.contains('success')
                                ? Colors.green
                                : Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isOtpComplete ? _pulseAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: ElevatedButton(
                      onPressed:
                          _isOtpComplete && !_isLoading ? _verifyOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Verifying...',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                              ],
                            )
                          : const Text(
                              'Verify',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: TextStyle(
                          color:
                              _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _canResend && !_isResending ? _resendOtp : null,
                        child: _isResending
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _canResend
                                    ? 'Resend'
                                    : 'Resend in $_resendTimer s',
                                style: TextStyle(
                                  color: _canResend ? Colors.blue : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpTextField(int index) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
        },
      ),
    );
  }
}
