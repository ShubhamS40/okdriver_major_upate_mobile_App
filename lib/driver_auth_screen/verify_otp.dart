import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:okdriver/bottom_navigation_bar/bottom_navigation_bar.dart';
import 'package:okdriver/permissionscreen/permissionscreen.dart';
import 'package:okdriver/driver_auth_screen/driver_registration_screen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/service/usersession_service.dart';
import 'package:okdriver/service/api_config.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:async';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber; // Phone number with country code

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
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
    _initializeAnimations();
    _setupListeners();
    _startResendTimer();
    _checkExistingSession();

    // Test backend connection on init
    _testBackendConnection();

    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });
    });
  }

  // Check if user is already logged in
  void _checkExistingSession() {
    if (UserSessionService.instance.isLoggedIn) {
      // User is already logged in, navigate to appropriate screen
      final user = UserSessionService.instance.currentUser;
      final bool isNewUser = user?['isNewUser'] ?? false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isNewUser) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DriverRegistrationScreen(
                phoneNumber: widget.phoneNumber,
                userId: user?['id']?.toString() ?? '',
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BottomNavScreen()),
          );
        }
      });
    }
  }

  void _initializeAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    _mainAnimationController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _setupListeners() {
    for (int i = 0; i < _otpControllers.length; i++) {
      _otpControllers[i].addListener(() {
        _checkOtpComplete();
      });
    }
  }

  void _checkOtpComplete() {
    final otpCode = _getOTPCode();
    final isComplete = otpCode.length == 6;

    if (isComplete != _isOtpComplete) {
      setState(() {
        _isOtpComplete = isComplete;
      });

      if (isComplete) {
        HapticFeedback.lightImpact();
        // Auto verify when all fields are filled
        Future.delayed(const Duration(milliseconds: 300), () {
          _verifyOTP();
        });
      }
    }
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _resendTimer--;
        });
      }
    });
  }

  void _shakeOTPFields() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  String _getOTPCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {
      _isOtpComplete = false;
    });
  }

  // Fixed API call to verify OTP with better error handling
  Future<void> _verifyOTP() async {
    final otpCode = _getOTPCode();

    // Validation checks
    if (otpCode.length != 6) {
      _showMessage('Please enter complete OTP', isError: true);
      _shakeOTPFields();
      return;
    }

    // Check if OTP contains only digits
    if (!RegExp(r'^\d{6}$').hasMatch(otpCode)) {
      _showMessage('OTP should contain only numbers', isError: true);
      _shakeOTPFields();
      return;
    }

    setState(() {
      _isLoading = true;
      _verificationMessage = '';
    });

    _loadingController.forward();
    HapticFeedback.lightImpact();

    try {
      print('Verifying OTP for phone: ${widget.phoneNumber}');
      print('OTP Code: $otpCode');

      // Get device info
      final deviceInfo = await _getDeviceInfo();
      print('Device info: $deviceInfo');

      // Prepare request body
      final requestBody = {
        'phone': widget.phoneNumber.trim(),
        'code': otpCode.trim(),
        'deviceInfo': deviceInfo,
      };

      print('Request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(ApiConfig.verifyOtpUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('OTP verification response status: ${response.statusCode}');
      print('OTP verification response headers: ${response.headers}');
      print('OTP verification response body: ${response.body}');

      // Handle different response status codes
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Parsed response data: $data');

          // Validate response structure
          if (data == null) {
            throw Exception('Empty response from server');
          }

          HapticFeedback.heavyImpact();
          _showMessage('OTP verified successfully!', isError: false);

          // Extract user data with null safety
          final Map<String, dynamic> userData = data['user'] ?? {};
          final String token = data['token']?.toString() ?? '';
          final String sessionId = data['sessionId']?.toString() ?? '';
          final bool isNewUser = data['isNewUser'] ?? true;

          print('User data: $userData');
          print('Token: ${token.isNotEmpty ? 'Present' : 'Missing'}');
          print('Session ID: ${sessionId.isNotEmpty ? 'Present' : 'Missing'}');
          print('Is new user: $isNewUser');

          // Validate required fields
          if (userData.isEmpty) {
            throw Exception('User data missing in response');
          }

          // Use UserSessionService to handle login
          final sessionService = UserSessionService.instance;
          print('Attempting to create user session...');

          final success =
              await sessionService.login(userData, token, sessionId);

          if (success) {
            print('User session created successfully');

            // Navigate based on user status
            Future.delayed(const Duration(seconds: 1), () {
              if (isNewUser) {
                print('Navigating to driver registration for new user');
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        DriverRegistrationScreen(
                      phoneNumber: widget.phoneNumber,
                      userId: userData['id']?.toString() ?? '',
                    ),
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
                );
              } else {
                print('Navigating to permission screen for existing user');
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const PermissionScreen(),
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
                );
              }
            });
          } else {
            print('Failed to create user session');
            _showMessage('Failed to create session. Please try again.',
                isError: true);
            _shakeOTPFields();
            _clearOTP();
          }
        } catch (e) {
          print('Error parsing success response: $e');
          _showMessage('Invalid response format. Please try again.',
              isError: true);
          _shakeOTPFields();
          _clearOTP();
        }
      } else if (response.statusCode == 400) {
        // Bad request - usually invalid OTP
        try {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['error'] ?? errorData['message'] ?? 'Invalid OTP code';
          print('OTP verification failed (400): $errorMessage');
          _showMessage(errorMessage, isError: true);
        } catch (e) {
          _showMessage('Invalid OTP code', isError: true);
        }
        _shakeOTPFields();
        _clearOTP();
      } else if (response.statusCode == 401) {
        // Unauthorized - OTP expired or invalid
        _showMessage('OTP has expired. Please request a new one.',
            isError: true);
        _shakeOTPFields();
        _clearOTP();
      } else if (response.statusCode == 404) {
        // Not found - phone number not found
        _showMessage('Phone number not found. Please try again.',
            isError: true);
        _shakeOTPFields();
        _clearOTP();
      } else if (response.statusCode == 429) {
        // Too many requests
        _showMessage('Too many attempts. Please wait and try again.',
            isError: true);
        _shakeOTPFields();
      } else if (response.statusCode >= 500) {
        // Server error
        _showMessage('Server error. Please try again later.', isError: true);
        _shakeOTPFields();
        _clearOTP();
      } else {
        // Other error codes
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['error'] ??
              errorData['message'] ??
              'OTP verification failed (${response.statusCode})';
          print(
              'OTP verification failed (${response.statusCode}): $errorMessage');
          _showMessage(errorMessage, isError: true);
        } catch (e) {
          _showMessage('OTP verification failed. Please try again.',
              isError: true);
        }
        _shakeOTPFields();
        _clearOTP();
      }
    } on TimeoutException catch (e) {
      print('OTP verification timeout: $e');
      _showMessage(
          'Request timed out. Please check your internet connection and try again.',
          isError: true);
      _shakeOTPFields();
    } on http.ClientException catch (e) {
      print('HTTP client error: $e');
      _showMessage(
          'Network connection failed. Please check your internet connection.',
          isError: true);
      _shakeOTPFields();
    } on FormatException catch (e) {
      print('JSON format error: $e');
      _showMessage('Invalid server response. Please try again.', isError: true);
      _shakeOTPFields();
      _clearOTP();
    } catch (e) {
      print('OTP verification unexpected error: $e');
      String errorMessage = 'An unexpected error occurred. Please try again.';

      if (e.toString().contains('Connection refused')) {
        errorMessage =
            'Cannot connect to server. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage =
            'Network connection failed. Please check your internet connection.';
      }

      _showMessage(errorMessage, isError: true);
      _shakeOTPFields();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _loadingController.reset();
      }
    }
  }

  // API call to resend OTP
  Future<void> _resendOTP() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    HapticFeedback.lightImpact();

    try {
      print('Resending OTP to phone: ${widget.phoneNumber}');

      final response = await http
          .post(
            Uri.parse(ApiConfig.sendOtpUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'phone': widget.phoneNumber.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('Resend OTP response status: ${response.statusCode}');
      print('Resend OTP response body: ${response.body}');

      if (response.statusCode == 200) {
        HapticFeedback.heavyImpact();
        _showMessage('OTP sent successfully!', isError: false);
        _startResendTimer();
        _clearOTP();
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['error'] ??
              errorData['message'] ??
              'Failed to resend OTP';
          print('Resend OTP failed: $errorMessage');
          _showMessage(errorMessage, isError: true);
        } catch (e) {
          _showMessage('Failed to resend OTP', isError: true);
        }
      }
    } on TimeoutException catch (e) {
      print('Resend OTP timeout: $e');
      _showMessage(
          'Request timed out. Please check your internet connection and try again.',
          isError: true);
    } on http.ClientException catch (e) {
      print('HTTP client error: $e');
      _showMessage(
          'Network connection failed. Please check your internet connection.',
          isError: true);
    } catch (e) {
      print('Resend OTP error: $e');
      String errorMessage = 'Network error. Please try again.';

      if (e.toString().contains('Connection refused')) {
        errorMessage =
            'Cannot connect to server. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage =
            'Network connection failed. Please check your internet connection.';
      }

      _showMessage(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    setState(() {
      _verificationMessage = message;
    });

    if (isError) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF424242),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onOTPChanged(String value, int index) {
    HapticFeedback.selectionClick();

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
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
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: _isDarkMode
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A0A0A),
                        Colors.black,
                        Color(0xFF1A1A1A),
                      ],
                      stops: [0.0, 0.7, 1.0],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF5F5F5),
                        Colors.white,
                        Color(0xFFEEEEEE),
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildCustomAppBar(),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),

                        // Header Section
                        _buildHeaderSection(),

                        const SizedBox(height: 60),

                        // OTP Input Section
                        _buildOTPInputSection(),

                        const SizedBox(height: 40),

                        // Verify Button
                        _buildVerifyButton(),

                        const SizedBox(height: 30),

                        // Resend Section
                        _buildResendSection(),

                        const SizedBox(height: 30),

                        // Security Note
                        _buildSecurityNote(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _isDarkMode ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Verify OTP',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: _isDarkMode
                              ? [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.black.withOpacity(0.1),
                                  Colors.black.withOpacity(0.03),
                                  Colors.transparent,
                                ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.security_outlined,
                        size: 50,
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Title
            Text(
              'Enter\nVerification Code',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            // Subtitle
            Text(
              'We sent a 6-digit verification code to\n${widget.phoneNumber}',
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 16,
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPInputSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Code',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 24),

          // OTP Input Fields
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _focusNodes[index].hasFocus
                              ? _isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.5)
                              : _otpControllers[index].text.isNotEmpty
                                  ? _isDarkMode
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.black.withOpacity(0.3)
                                  : _isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.1),
                          width: _focusNodes[index].hasFocus ? 2 : 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black,
                          letterSpacing: 1,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) => _onOTPChanged(value, index),
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          // Progress indicator
          if (_isOtpComplete)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: _isDarkMode ? Colors.black : Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Code Complete',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: _isOtpComplete
                ? LinearGradient(
                    colors: _isDarkMode
                        ? [Colors.white, Colors.grey]
                        : [Colors.black, const Color(0xFF555555)],
                  )
                : LinearGradient(
                    colors: _isDarkMode
                        ? [
                            Colors.white.withOpacity(0.3),
                            Colors.grey.withOpacity(0.3),
                          ]
                        : [
                            Colors.black.withOpacity(0.2),
                            Colors.grey.withOpacity(0.2),
                          ],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isOtpComplete
                ? [
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: (_isOtpComplete && !_isLoading) ? _verifyOTP : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isOtpComplete
                                ? (_isDarkMode ? Colors.black : Colors.white)
                                : (_isDarkMode
                                    ? Colors.white54
                                    : Colors.black45),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Verifying...',
                        style: TextStyle(
                          color: _isOtpComplete
                              ? (_isDarkMode ? Colors.black : Colors.white)
                              : (_isDarkMode ? Colors.white54 : Colors.black45),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Verify Code',
                        style: TextStyle(
                          color: _isOtpComplete
                              ? (_isDarkMode ? Colors.black : Colors.white)
                              : (_isDarkMode ? Colors.white54 : Colors.black45),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.verified_outlined,
                        color: _isOtpComplete
                            ? (_isDarkMode ? Colors.black : Colors.white)
                            : (_isDarkMode ? Colors.white54 : Colors.black45),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.7),
                  ),
                ),
                if (_canResend)
                  GestureDetector(
                    onTap: _isResending ? null : _resendOTP,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isResending) ...[
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isDarkMode
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.black.withOpacity(0.8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _isResending ? 'Sending...' : 'Resend Code',
                            style: TextStyle(
                              fontSize: 14,
                              color: _isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Resend in ${_resendTimer}s',
                          style: TextStyle(
                            fontSize: 14,
                            color: _isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: _isDarkMode ? Colors.white70 : Colors.black54,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secure Verification',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This code expires in 10 minutes for your security. Enter it quickly to complete verification.',
                    style: TextStyle(
                      color: _isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
