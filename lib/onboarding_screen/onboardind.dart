import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/driver_auth_screen/send_otp.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late bool _isDarkMode = false;
  late PageController _pageController;
  late AnimationController _mainAnimationController;
  late AnimationController _progressAnimationController;
  late AnimationController _floatingController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _floatingAnimation;

  int currentPage = 0;
  final int totalPages = 4;

  final List<OnboardingData> onboardingPages = [
    OnboardingData(
      title: "Smart Dashcam",
      subtitle: "Record Every Mile",
      description:
          "Advanced HD recording with dual cameras captures your entire journey. Protect yourself with automatic loop recording and emergency lock features.",
      icon: Icons.videocam_outlined,
      features: [
        "Dual Camera System",
        "4K HD Recording",
        "Auto Loop Storage",
        "Emergency Protection"
      ],
      primaryColor: const Color(0xFF2196F3),
      accentColor: const Color(0xFFBBDEFB),
    ),
    OnboardingData(
      title: "AI Sleep Monitor",
      subtitle: "Stay Alert & Safe",
      description:
          "Advanced AI technology monitors your alertness levels and provides intelligent warnings to prevent drowsy driving accidents.",
      icon: Icons.remove_red_eye_outlined,
      features: [
        "Real-time Monitoring",
        "Smart Alert System",
        "Fatigue Analysis",
        "Rest Suggestions"
      ],
      primaryColor: const Color(0xFFFF9800),
      accentColor: const Color(0xFFFFE0B2),
    ),
    OnboardingData(
      title: "Emergency SOS",
      subtitle: "Instant Help Available",
      description:
          "One-touch emergency system instantly connects you with family and emergency services when you need help the most.",
      icon: Icons.emergency_outlined,
      features: [
        "Instant Emergency Alert",
        "Family Auto-Notification",
        "Hospital Locator",
        "Live Location Sharing"
      ],
      primaryColor: const Color(0xFFF44336),
      accentColor: const Color(0xFFFFCDD2),
    ),
    OnboardingData(
      title: "AI Companion",
      subtitle: "Your Smart Co-Pilot",
      description:
          "Voice-controlled AI assistant provides navigation, traffic updates, and hands-free communication for safer driving.",
      icon: Icons.psychology_outlined,
      features: [
        "Voice Control",
        "Smart Navigation",
        "Live Traffic Data",
        "Hands-free Calls"
      ],
      primaryColor: const Color(0xFF4CAF50),
      accentColor: const Color(0xFFC8E6C9),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _startAnimations();

    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });
    });
  }

  void _initializeControllers() {
    _pageController = PageController();

    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
  }

  void _initializeAnimations() {
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
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

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _floatingAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _mainAnimationController.forward();
    _progressAnimationController.forward();
    _floatingController.repeat(reverse: true);
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToNext();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _navigateToNext() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SendOtpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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

  @override
  void dispose() {
    _pageController.dispose();
    _mainAnimationController.dispose();
    _progressAnimationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        children: [
          // Animated background
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

          // Floating particles
          ...List.generate(
              15,
              (index) =>
                  _buildFloatingParticle(index, screenWidth, screenHeight)),

          SafeArea(
            child: Column(
              children: [
                // Top section with progress
                _buildTopSection(),

                // Main content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        currentPage = index;
                      });
                      _mainAnimationController.reset();
                      _mainAnimationController.forward();
                      _progressAnimationController.reset();
                      _progressAnimationController.forward();
                    },
                    itemCount: totalPages,
                    itemBuilder: (context, index) {
                      final page = onboardingPages[index];
                      return _buildPageContent(page, screenHeight);
                    },
                  ),
                ),

                // Bottom navigation
                _buildBottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingParticle(
      int index, double screenWidth, double screenHeight) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Positioned(
          left: (screenWidth / 15 * index) % screenWidth,
          top: (screenHeight / 15 * index) % screenHeight +
              _floatingAnimation.value,
          child: Container(
            width: 3 + (index % 3),
            height: 3 + (index % 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1 + (index % 3) * 0.05),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${currentPage + 1} of $totalPages',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${((currentPage + 1) / totalPages * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor:
                    ((currentPage + 1) / totalPages) * _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Colors.white70],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageContent(OnboardingData page, double screenHeight) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight * 0.6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Animated icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatingAnimation.value * 0.5),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                page.primaryColor.withOpacity(0.2),
                                page.primaryColor.withOpacity(0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7, 1.0],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: page.primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            page.icon,
                            size: 70,
                            color: page.primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 50),

                // Title
                Text(
                  page.title,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : const Color(0xFF333333),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Subtitle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: page.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: page.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    page.subtitle,
                    style: TextStyle(
                      color: page.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                // Description
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    page.description,
                    style: TextStyle(
                      color: _isDarkMode
                          ? Colors.white70
                          : const Color(0xFF666666),
                      fontSize: 17,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Features list
                Column(
                  children: page.features.asMap().entries.map((entry) {
                    final index = entry.key;
                    final feature = entry.value;

                    return AnimatedContainer(
                      duration: Duration(milliseconds: 200 + (index * 100)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child:
                          _buildFeatureCard(feature, page.primaryColor, index),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String feature, Color primaryColor, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.03)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.8),
                  primaryColor.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : const Color(0xFF333333),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            if (currentPage > 0) ...[
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: TextButton(
                    onPressed: _previousPage,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],

            // Next/Get Started button
            Expanded(
              flex: currentPage == 0 ? 1 : 2,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.grey],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentPage == totalPages - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Onboarding Data Model
class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<String> features;
  final Color primaryColor;
  final Color accentColor;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.features,
    required this.primaryColor,
    required this.accentColor,
  });
}
