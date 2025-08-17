import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:http/http.dart' as http;
import 'package:okdriver/driver_auth_screen/verify_otp.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

class SendOtpScreen extends StatefulWidget {
  const SendOtpScreen({Key? key}) : super(key: key);

  @override
  State<SendOtpScreen> createState() => _SendOtpScreenState();
}

class _SendOtpScreenState extends State<SendOtpScreen>
    with TickerProviderStateMixin {
  late bool _isDarkMode = false;
  final TextEditingController phoneController = TextEditingController();
  final FocusNode phoneFocusNode = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _loadingAnimation;

  String _countryCode = "+91";
  String _countryFlag = "🇮🇳";
  String _countryName = "India";
  bool _isLoading = false;
  bool _isPhoneValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();

    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });
    });
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
    phoneController.addListener(() {
      final phone = phoneController.text.trim();
      final isValid = phone.length >= 10 &&
          phone.length <= 15 &&
          RegExp(r'^[0-9]+$').hasMatch(phone);

      if (isValid != _isPhoneValid) {
        setState(() {
          _isPhoneValid = isValid;
        });
      }
    });

    phoneFocusNode.addListener(() {
      setState(() {});
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    _loadingController.forward();
    HapticFeedback.lightImpact();

    try {
      final String fullNumber = '$_countryCode${phoneController.text.trim()}';

      // Simulate API delay for better UX
      await Future.delayed(const Duration(milliseconds: 1500));

      final url = Uri.parse('http://98.70.99.58:5000/api/driver/send-otp');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": fullNumber}),
      );

      if (response.statusCode == 200) {
        HapticFeedback.heavyImpact();
        _showSuccessAnimation();

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  OTPVerificationScreen(phoneNumber: fullNumber),
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
      } else {
        _showErrorSnackBar("Failed to send OTP. Please try again.");
      }
    } catch (e) {
      _showErrorSnackBar("Network error. Please check your connection.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _loadingController.reset();
      }
    }
  }

  void _showSuccessAnimation() {
    HapticFeedback.mediumImpact();
    // Add success visual feedback here if needed
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF424242),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (value.length > 15) {
      return 'Phone number must be less than 15 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  @override
  void dispose() {
    phoneController.dispose();
    phoneFocusNode.dispose();
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),

                          // Header Section
                          _buildHeaderSection(),

                          const SizedBox(height: 60),

                          // Phone Input Section
                          _buildPhoneInputSection(),

                          const SizedBox(height: 40),

                          // Send OTP Button
                          _buildSendOtpButton(),

                          const SizedBox(height: 30),

                          // Privacy Note
                          _buildPrivacyNote(),

                          const SizedBox(height: 40),
                        ],
                      ),
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
                'Phone Verification',
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
                        Icons.phone_android_outlined,
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
              'Enter Your\nPhone Number',
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
              'We\'ll send you a verification code to confirm your number and keep your account secure.',
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

  Widget _buildPhoneInputSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone Number',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Phone Input Container
          Container(
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: phoneFocusNode.hasFocus
                    ? (_isDarkMode
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.5))
                    : _isPhoneValid
                        ? (_isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3))
                        : (_isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1)),
                width: phoneFocusNode.hasFocus ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Country Code Picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: CountryCodePicker(
                    onChanged: (code) {
                      setState(() {
                        _countryCode = code.dialCode ?? "+91";
                        _countryFlag = code.flagUri ?? "🇮🇳";
                        _countryName = code.name ?? "India";
                      });
                      HapticFeedback.selectionClick();
                    },
                    initialSelection: 'IN',
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                    padding: EdgeInsets.zero,
                    textStyle: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    dialogTextStyle: const TextStyle(
                      color: Colors.black,
                    ),
                    searchStyle: const TextStyle(
                      color: Colors.black,
                    ),
                    dialogBackgroundColor: Colors.white,
                    barrierColor: Colors.black54,
                    boxDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Phone Number Input
                Expanded(
                  child: TextFormField(
                    controller: phoneController,
                    focusNode: phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    validator: _validatePhone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      hintStyle: TextStyle(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black.withOpacity(0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      suffixIcon: _isPhoneValid
                          ? Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color:
                                    _isDarkMode ? Colors.white : Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color:
                                    _isDarkMode ? Colors.black : Colors.white,
                                size: 16,
                              ),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Country Info
          if (_countryName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(
                    _countryFlag,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _countryName,
                    style: TextStyle(
                      color: _isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _countryCode,
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSendOtpButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: _isPhoneValid
                ? LinearGradient(
                    colors: _isDarkMode
                        ? [Colors.white, Colors.grey]
                        : [const Color(0xFF333333), Colors.black],
                  )
                : LinearGradient(
                    colors: _isDarkMode
                        ? [
                            Colors.white.withOpacity(0.3),
                            Colors.grey.withOpacity(0.3),
                          ]
                        : [
                            Colors.black.withOpacity(0.3),
                            Colors.grey.withOpacity(0.3),
                          ],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isPhoneValid
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
            onPressed: (_isPhoneValid && !_isLoading) ? _sendOtp : null,
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
                            _isPhoneValid
                                ? (_isDarkMode ? Colors.black : Colors.white)
                                : (_isDarkMode
                                    ? Colors.white54
                                    : Colors.black54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sending OTP...',
                        style: TextStyle(
                          color: _isPhoneValid
                              ? (_isDarkMode ? Colors.black : Colors.white)
                              : (_isDarkMode ? Colors.white54 : Colors.black54),
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
                        'Send Verification Code',
                        style: TextStyle(
                          color: _isPhoneValid
                              ? (_isDarkMode ? Colors.black : Colors.white)
                              : (_isDarkMode ? Colors.white54 : Colors.black54),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _isPhoneValid
                            ? (_isDarkMode ? Colors.black : Colors.white)
                            : (_isDarkMode ? Colors.white54 : Colors.black54),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
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
                Icons.security_outlined,
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
                    'Privacy Protected',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your phone number is encrypted and will only be used for verification. We never share your personal information.',
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
