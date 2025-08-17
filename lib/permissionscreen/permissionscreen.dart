import 'package:flutter/material.dart';
import 'package:okdriver/onboarding_screen/onboardind.dart';
import 'package:okdriver/utlis/android14_storage_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:io';

// Theme Provider for managing light/dark themes
class ThemeProvider extends ChangeNotifier {
  bool _isDarkTheme = false;

  bool get isDarkTheme => _isDarkTheme;

  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  ThemeData get currentTheme => _isDarkTheme ? _darkTheme : _lightTheme;

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    textTheme: const TextTheme(
      titleLarge:
          TextStyle(color: Color(0xFF212121), fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFF424242)),
      bodyMedium: TextStyle(color: Color(0xFF757575)),
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF2A2A2A),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
      bodyMedium: TextStyle(color: Color(0xFFBDBDBD)),
    ),
  );
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({Key? key}) : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _staggerAnimation;

  // Theme management
  final ThemeProvider _themeProvider = ThemeProvider();

  // Permission status tracking
  Map<Permission, PermissionStatus> permissionStatuses = {};
  bool isCheckingPermissions = false;
  bool allPermissionsGranted = false;
  int grantedCount = 0;

  // List of required permissions - Updated for Android 14 compatibility
  List<PermissionData> get requiredPermissions {
    final List<PermissionData> permissions = [
      PermissionData(
        permission: Permission.camera,
        title: 'Camera Access',
        description: 'Capture photos and videos for your profile',
        icon: Icons.camera_alt_outlined,
        color: const Color(0xFF424242),
      ),
      PermissionData(
        permission: Permission.microphone,
        title: 'Microphone',
        description: 'Record audio for calls and voice messages',
        icon: Icons.mic_outlined,
        color: const Color(0xFF424242),
      ),
      PermissionData(
        permission: Permission.location,
        title: 'Location Services',
        description: 'Find nearby drivers and optimize routes',
        icon: Icons.location_on_outlined,
        color: const Color(0xFF424242),
      ),
      PermissionData(
        permission: Permission.notification,
        title: 'Push Notifications',
        description: 'Receive ride updates and important alerts',
        icon: Icons.notifications_outlined,
        color: const Color(0xFF424242),
      ),
      PermissionData(
        permission: Permission.bluetooth,
        title: 'Bluetooth',
        description: 'Connect with in-car systems seamlessly',
        icon: Icons.bluetooth_outlined,
        color: const Color(0xFF424242),
      ),
      PermissionData(
        permission: Permission.phone,
        title: 'Phone Access',
        description: 'Make emergency calls and contact support',
        icon: Icons.phone_outlined,
        color: const Color(0xFF424242),
      ),
    ];

    // Add storage permissions based on Android version
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use granular media permissions
      if (_isAndroid13Plus()) {
        // Add media permissions for Android 13+
        permissions.addAll([
          PermissionData(
            permission: Permission.photos,
            title: 'Photos & Videos',
            description: 'Access photos and videos for profile pictures',
            icon: Icons.photo_library_outlined,
            color: const Color(0xFF424242),
          ),
          PermissionData(
            permission: Permission.videos,
            title: 'Video Access',
            description: 'Access videos for dashcam recordings',
            icon: Icons.video_library_outlined,
            color: const Color(0xFF424242),
          ),
          PermissionData(
            permission: Permission.audio,
            title: 'Audio Access',
            description: 'Access audio files for voice messages',
            icon: Icons.audiotrack_outlined,
            color: const Color(0xFF424242),
          ),
        ]);
      } else {
        // For older Android versions, use storage permission
        permissions.add(
          PermissionData(
            permission: Permission.storage,
            title: 'Storage Access',
            description: 'Save trip data and offline maps',
            icon: Icons.folder_outlined,
            color: const Color(0xFF424242),
          ),
        );
      }
    } else {
      // For iOS, use storage permission
      permissions.add(
        PermissionData(
          permission: Permission.storage,
          title: 'Storage Access',
          description: 'Save trip data and offline maps',
          icon: Icons.folder_outlined,
          color: const Color(0xFF424242),
        ),
      );
    }

    return permissions;
  }

  // Helper method to safely check if running on Android 13+
  bool _isAndroid13Plus() {
    if (!Platform.isAndroid) return false;

    try {
      final version = Platform.operatingSystemVersion;
      print('Android version string: $version');

      // Handle different version string formats
      if (version.contains('release-keys') || version.contains('user')) {
        // This is a build fingerprint, not a version number
        // We'll assume it's a recent Android version and use granular permissions
        print('Detected build fingerprint, assuming Android 13+');
        return true;
      }

      // Try to extract API level from version string
      final parts = version.split(' ');
      for (final part in parts) {
        final apiLevel = int.tryParse(part);
        if (apiLevel != null && apiLevel >= 33) {
          print('Detected Android API level: $apiLevel');
          return true;
        }
      }

      // If we can't parse the version, assume it's a recent Android version
      print('Could not parse Android version, assuming Android 13+');
      return true;
    } catch (e) {
      print('Error parsing Android version: $e');
      // Default to using granular permissions for safety
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkInitialPermissions();
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

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOutQuart,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _staggerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuart),
    ));

    _mainAnimationController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _checkInitialPermissions() async {
    for (var permissionData in requiredPermissions) {
      final status = await permissionData.permission.status;
      permissionStatuses[permissionData.permission] = status;
    }
    _updatePermissionCounts();
    setState(() {});
  }

  void _updatePermissionCounts() {
    grantedCount = permissionStatuses.values
        .where((status) => status == PermissionStatus.granted)
        .length;
    allPermissionsGranted = grantedCount == requiredPermissions.length;
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      isCheckingPermissions = true;
    });

    // Add haptic feedback
    HapticFeedback.lightImpact();

    try {
      for (int i = 0; i < requiredPermissions.length; i++) {
        final permissionData = requiredPermissions[i];
        if (permissionStatuses[permissionData.permission] !=
            PermissionStatus.granted) {
          // Special handling for storage permissions on Android 13+
          if (Platform.isAndroid &&
              Android14StorageHelper.getStoragePermissions()
                  .contains(permissionData.permission)) {
            // Use the helper for storage permissions
            try {
              final storageResults =
                  await Android14StorageHelper.requestStoragePermissions();

              // Update the permission statuses
              for (final entry in storageResults.entries) {
                permissionStatuses[entry.key] = entry.value;
              }

              // Check if any storage permissions were denied
              final deniedPermissions = storageResults.entries
                  .where((entry) => entry.value != PermissionStatus.granted)
                  .map((entry) => entry.key)
                  .toList();

              if (deniedPermissions.isNotEmpty) {
                _showAndroid14StorageGuidance();
              }
            } catch (e) {
              print('Error requesting storage permissions: $e');
              _showAndroid14StorageGuidance();
            }
          } else {
            // Standard permission request for other permissions
            final status = await permissionData.permission.request();
            permissionStatuses[permissionData.permission] = status;
          }

          setState(() {
            _updatePermissionCounts();
          });

          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      HapticFeedback.mediumImpact();

      if (allPermissionsGranted) {
        _showSuccessAnimation();
      } else {
        _showPartialPermissionDialog();
      }
    } catch (e) {
      _showErrorDialog('Error requesting permissions: $e');
    } finally {
      setState(() {
        isCheckingPermissions = false;
      });
    }
  }

  void _showSuccessAnimation() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(),
    );
  }

  Widget _buildSuccessDialog() {
    final isDark = _themeProvider.isDarkTheme;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: isDark ? Colors.black : Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Perfect!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'All permissions granted successfully.\nYou\'re ready to go!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToNextScreen();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPartialPermissionDialog() {
    final isDark = _themeProvider.isDarkTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF757575),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Almost There!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Some permissions were not granted.\nYou can enable them later in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _navigateToNextScreen();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    final isDark = _themeProvider.isDarkTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF757575),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Text(
              'Error',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => OnboardingScreen()),
    );
  }

  void _showAndroid14StorageGuidance() {
    final isDark = _themeProvider.isDarkTheme;
    final instructions = Android14StorageHelper.getPermissionInstructions();
    final message = Android14StorageHelper.getStoragePermissionMessage();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF757575),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.info_outline, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                Android14StorageHelper.isAndroid14
                    ? 'Android 14 Storage Access'
                    : 'Storage Permission Required',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...instructions.map((instruction) => _buildGuidanceStep(
                instruction.split('.')[0],
                instruction.substring(instruction.indexOf('.') + 1).trim(),
                isDark)),
            const SizedBox(height: 16),
            Text(
              'This is required for saving dashcam recordings and profile pictures.',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Skip',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceStep(String number, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, child) {
        final isDark = _themeProvider.isDarkTheme;
        final theme = _themeProvider.currentTheme;

        return Theme(
          data: theme,
          child: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
            body: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // Header Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildHeader(isDark),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Progress Indicator
                    FadeTransition(
                      opacity: _staggerAnimation,
                      child: _buildProgressIndicator(isDark),
                    ),

                    const SizedBox(height: 30),

                    // Permissions List
                    Expanded(
                      child: FadeTransition(
                        opacity: _staggerAnimation,
                        child: _buildPermissionsList(isDark),
                      ),
                    ),

                    // Bottom Section
                    FadeTransition(
                      opacity: _staggerAnimation,
                      child: _buildBottomSection(isDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.security_outlined,
                  color: isDark ? Colors.black : Colors.white,
                  size: 45,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 25),
        Text(
          'App Permissions',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'To deliver the best experience, OK Driver\nneeds access to these features',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
            height: 1.5,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final progress = grantedCount / requiredPermissions.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '$grantedCount/${requiredPermissions.length}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor:
                isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsList(bool isDark) {
    return ListView.builder(
      itemCount: requiredPermissions.length,
      itemBuilder: (context, index) {
        final permissionData = requiredPermissions[index];
        final status = permissionStatuses[permissionData.permission];
        final isGranted = status == PermissionStatus.granted;

        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildPermissionCard(permissionData, isGranted, isDark),
        );
      },
    );
  }

  Widget _buildPermissionCard(
      PermissionData data, bool isGranted, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? (isDark ? Colors.white : Colors.black).withOpacity(0.3)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
          width: isGranted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isGranted
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              data.icon,
              color: isGranted
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF757575)),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF757575),
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isGranted
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE0E0E0)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : Icons.close_rounded,
              color: isGranted
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark
                      ? const Color(0xFF757575)
                      : const Color(0xFF9E9E9E)),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(bool isDark) {
    return Column(
      children: [
        // Main Action Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isCheckingPermissions ? null : _requestAllPermissions,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              disabledBackgroundColor:
                  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: isCheckingPermissions
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Requesting Access...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Grant All Permissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Privacy Note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your privacy matters. Permissions are used only to enhance your experience.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF757575),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Permission Data Model
class PermissionData {
  final Permission permission;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  PermissionData({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
