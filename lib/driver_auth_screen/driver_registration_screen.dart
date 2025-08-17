import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:okdriver/bottom_navigation_bar/bottom_navigation_bar.dart';
import 'dart:convert';
import 'dart:async';

class DriverRegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  final String userId;

  const DriverRegistrationScreen({
    Key? key,
    required this.phoneNumber,
    required this.userId,
  }) : super(key: key);

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _emergencyFocus = FocusNode();

  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _loadingAnimation;

  bool _isLoading = false;
  String _registrationMessage = '';
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
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
    _firstNameController.addListener(_validateForm);
    _lastNameController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _emergencyContactController.addListener(_validateForm);

    _firstNameFocus.addListener(() => setState(() {}));
    _lastNameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _emergencyFocus.addListener(() => setState(() {}));
  }

  void _validateForm() {
    final isValid = _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(_emailController.text.trim());

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  // API call to register driver
  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _registrationMessage = '';
    });

    _loadingController.forward();
    HapticFeedback.lightImpact();

    try {
      // Simulate API delay for better UX
      await Future.delayed(const Duration(milliseconds: 1500));

      final response = await http.post(
        Uri.parse('http://98.70.99.58:5000/api/drivers/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': widget.userId,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        HapticFeedback.heavyImpact();
        _showMessage('Registration successful!', isError: false);

        // Navigate to home screen after delay
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  BottomNavScreen(),
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
        final errorData = json.decode(response.body);
        _showMessage(errorData['message'] ?? 'Registration failed',
            isError: true);
      }
    } catch (e) {
      _showMessage('Network error. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _loadingController.reset();
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    setState(() {
      _registrationMessage = message;
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

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Last name is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateEmergencyContact(String? value) {
    if (value != null && value.isNotEmpty && value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _emergencyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0A),
                  Colors.black,
                  Color(0xFF1A1A1A),
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

                          const SizedBox(height: 50),

                          // Phone Number Display
                          _buildPhoneDisplay(),

                          const SizedBox(height: 30),

                          // Form Fields
                          _buildFormFields(),

                          const SizedBox(height: 40),

                          // Register Button
                          _buildRegisterButton(),

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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Complete Profile',
                style: TextStyle(
                  color: Colors.white,
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
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Title
            const Text(
              'Complete Your\nProfile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            // Subtitle
            const Text(
              'Please provide your details to complete your driver registration and start earning.',
              style: TextStyle(
                color: Colors.white70,
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

  Widget _buildPhoneDisplay() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.phone_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verified Phone Number',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.phoneNumber,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.black,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),

          // First Name
          _buildInputField(
            controller: _firstNameController,
            focusNode: _firstNameFocus,
            label: 'First Name',
            hintText: 'Enter your first name',
            icon: Icons.person_outline,
            validator: _validateFirstName,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _lastNameFocus.requestFocus(),
          ),

          const SizedBox(height: 16),

          // Last Name
          _buildInputField(
            controller: _lastNameController,
            focusNode: _lastNameFocus,
            label: 'Last Name',
            hintText: 'Enter your last name',
            icon: Icons.person_outline,
            validator: _validateLastName,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
          ),

          const SizedBox(height: 16),

          // Email
          _buildInputField(
            controller: _emailController,
            focusNode: _emailFocus,
            label: 'Email Address',
            hintText: 'Enter your email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _emergencyFocus.requestFocus(),
          ),

          const SizedBox(height: 16),

          // Emergency Contact
          _buildInputField(
            controller: _emergencyContactController,
            focusNode: _emergencyFocus,
            label: 'Emergency Contact (Optional)',
            hintText: 'Enter emergency contact number',
            icon: Icons.emergency_outlined,
            keyboardType: TextInputType.phone,
            validator: _validateEmergencyContact,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            onFieldSubmitted: (_) => _registerDriver(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focusNode.hasFocus
                  ? Colors.white.withOpacity(0.5)
                  : controller.text.isNotEmpty
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
              width: focusNode.hasFocus ? 2 : 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            validator: validator,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            onFieldSubmitted: onFieldSubmitted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12, left: 12),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
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
    );
  }

  Widget _buildRegisterButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: _isFormValid
                ? const LinearGradient(
                    colors: [Colors.white, Colors.grey],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.grey.withOpacity(0.3),
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFormValid
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: (_isFormValid && !_isLoading) ? _registerDriver : null,
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
                            _isFormValid ? Colors.black : Colors.white54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Completing Registration...',
                        style: TextStyle(
                          color: _isFormValid ? Colors.black : Colors.white54,
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
                        'Complete Registration',
                        style: TextStyle(
                          color: _isFormValid ? Colors.black : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _isFormValid ? Colors.black : Colors.white54,
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
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.privacy_tip_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Protection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your personal information is encrypted and securely stored. We follow strict privacy guidelines and never share your data with third parties.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
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
