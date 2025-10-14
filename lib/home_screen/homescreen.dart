import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/drowsiness_monitoring/dms.dart';
import 'package:okdriver/service/usersession_service.dart';
import 'package:okdriver/dashcam/components/camera_selection.dart';
import 'package:okdriver/okdriver_virtual_assistant/index.dart';
import 'package:okdriver/role_selection/role_selection.dart';

import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/language/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late bool _isDarkMode; // Will be initialized from ThemeProvider
  String _driverName = "Driver"; // Default name until API data is loaded
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });

      // Load driver data from session
      _loadDriverData();
    });
  }

  // Load driver data from session service
  Future<void> _loadDriverData() async {
    final sessionService = UserSessionService.instance;

    // Get user data from session
    final userData = sessionService.currentUser;
    if (userData != null) {
      setState(() {
        _driverName = sessionService.getUserDisplayName();
        _isLoading = false;
      });
    } else {
      // Try to fetch fresh data from API
      final freshData = await sessionService.fetchCurrentUserData();
      if (freshData != null) {
        setState(() {
          _driverName = sessionService.getUserDisplayName();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme();
    setState(() {
      _isDarkMode = themeProvider.isDarkTheme;
    });
  }

  void _onFeatureTap(String feature) {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          AppLocalizations.of(context)
              .translate('feature_coming_soon_title', [feature]),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          AppLocalizations.of(context)
              .translate('feature_coming_soon_message', [feature]),
          style: TextStyle(
            color: _isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).translate('ok'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : const Color(0xFF2196F3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header
            _buildHeader(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),

                    // Safety Features
                    _buildSafetyFeatures(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Driver Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isDarkMode
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3))
                      .withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/only_logo.png', // Replace with your driver icon asset
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 16),

          // Greeting Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading
                      ? AppLocalizations.of(context).translate('hello')
                      : '${_driverName}',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_getTimeGreeting()}! ${AppLocalizations.of(context).translate('drive_safe_today')}',
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Buttons removed
        ],
      ),
    );
  }

  void _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Perform logout
      final sessionService = UserSessionService.instance;
      await sessionService.logout();

      // Navigate back to role selection screen (login flow)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildSafetyFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('safety_features'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // First row - DashCam and Emergency SOS
        Row(
          children: [
            _buildDashCamCard(),
            const SizedBox(width: 16),
            _buildEmergencySOSCard(),
          ],
        ),

        const SizedBox(height: 16),

        // Second row - Drowsiness Monitoring and OkDriver Assistant
        Row(
          children: [
            _buildDrowsinessCard(),
            const SizedBox(width: 16),
            _buildOkDriverCard(),
          ],
        ),
      ],
    );
  }

  Widget _buildDashCamCard() {
    return Expanded(
      child: _buildFeatureCard(
        title: AppLocalizations.of(context).translate('dashcam_title'),
        description: AppLocalizations.of(context).translate('dashcam_desc'),
        icon: Icons.videocam_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraSelectionScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmergencySOSCard() {
    return Expanded(
      child: _buildFeatureCard(
        title: AppLocalizations.of(context).translate('emergency_sos'),
        description:
            AppLocalizations.of(context).translate('emergency_sos_desc'),
        icon: Icons.sos_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
        ),
        onTap: () => _onFeatureTap('Emergency SOS'),
      ),
    );
  }

  Widget _buildDrowsinessCard() {
    return Expanded(
      child: _buildFeatureCard(
        title: AppLocalizations.of(context).translate('drowsiness_monitoring'),
        description: AppLocalizations.of(context)
            .translate('drowsiness_monitoring_desc'),
        icon: Icons.visibility_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        onTap: () async {
          final hasPremium = UserSessionService.instance.hasPremiumPlan();
          if (!hasPremium) {
            _showPremiumRequiredDialog();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DrowsinessMonitoringScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOkDriverCard() {
    return Expanded(
      child: _buildFeatureCard(
        title: AppLocalizations.of(context).translate('assistant_title'),
        description: AppLocalizations.of(context).translate('assistant_desc'),
        icon: Icons.smart_toy_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        ),
        onTap: () async {
          final hasPremium = UserSessionService.instance.hasPremiumPlan();
          if (!hasPremium) {
            _showPremiumRequiredDialog();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OkDriverVirtualAssistantScreen(),
            ),
          );
        },
      ),
    );
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Premium Required',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Please purchase a subscription to access this feature.',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: TextStyle(
                    color:
                        _isDarkMode ? Colors.white : const Color(0xFF2196F3))),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
}
