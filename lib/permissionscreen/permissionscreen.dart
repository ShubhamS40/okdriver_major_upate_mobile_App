import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:okdriver/bottom_navigation_bar/bottom_navigation_bar.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({Key? key}) : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPermissions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();
  }

  Future<void> _refreshPermissions() async {
    try {
      final camera = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final notif = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _cameraStatus = camera;
          _micStatus = mic;
          _notificationStatus = notif;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
    }
  }

  bool get _allGranted =>
      _cameraStatus.isGranted &&
      _micStatus.isGranted &&
      _notificationStatus.isGranted;

  Future<void> _requestAll() async {
    if (_isRequesting) return;
    HapticFeedback.lightImpact();
    setState(() => _isRequesting = true);

    try {
      await Permission.camera.request();
      await Permission.microphone.request();
      await Permission.notification.request();
      await _refreshPermissions();

      if (_allGranted) {
        HapticFeedback.mediumImpact();
        _goNext();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please allow all important permissions to continue.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    if (_isRequesting) return;

    HapticFeedback.lightImpact();

    setState(() => _isRequesting = true);

    try {
      final status = await Permission.camera.request();

      debugPrint('📷 Permission result: $status');
      debugPrint('📷 isGranted: ${status.isGranted}');
      debugPrint('📷 isDenied: ${status.isDenied}');
      debugPrint('📷 isPermanentlyDenied: ${status.isPermanentlyDenied}');

      if (mounted) {
        setState(() {
          _cameraStatus = status;
          _isRequesting = false;
        });

        if (status.isGranted) {
          HapticFeedback.mediumImpact();
          _refreshPermissions();
        } else if (status.isPermanentlyDenied) {
          _showSettingsDialog();
        } else if (status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Camera permission is required for dashcam features'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting camera permission: $e');

      if (mounted) {
        setState(() => _isRequesting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 70, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Camera Enabled!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera permission has been granted successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission Required'),
        content: const Text(
          'Camera permission was denied. Please enable it from Settings to use dashcam features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _goNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BottomNavScreen()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Brand / logo style header
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [
                        Colors.white24,
                        Colors.white10,
                        Colors.transparent
                      ],
                      stops: [0, 0.7, 1],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 52,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                // TITLE
                const Text(
                  'Allow OK Driver Permissions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                // SUBTITLE
                const Text(
                  'We use these permissions to keep your trips safe, record dashcam video and send important alerts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // PERMISSION CARDS
                _buildPermissionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera',
                  description:
                      'Required for dashcam recording and drowsiness monitoring.',
                  status: _cameraStatus,
                  onTap: _requestCameraPermission,
                ),
                const SizedBox(height: 12),
                _buildPermissionTile(
                  icon: Icons.mic_none_outlined,
                  title: 'Microphone',
                  description:
                      'Required for assistant voice control and alerts.',
                  status: _micStatus,
                  onTap: () async {
                    await Permission.microphone.request();
                    await _refreshPermissions();
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications',
                  description: 'For drowsiness alerts and important updates.',
                  status: _notificationStatus,
                  onTap: () async {
                    await Permission.notification.request();
                    await _refreshPermissions();
                  },
                ),

                const Spacer(),

                // MAIN BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRequesting
                        ? null
                        : () async {
                            if (_allGranted) {
                              _goNext();
                            } else {
                              await _requestAll();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allGranted
                          ? Colors.greenAccent.shade400
                          : Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            _allGranted
                                ? 'Continue to OK Driver'
                                : 'Allow All Permissions',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    final granted = status.isGranted;
    final permanentlyDenied = status.isPermanentlyDenied;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted ? Colors.greenAccent.shade400 : Colors.white12,
            width: granted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              granted ? 'Allowed' : (permanentlyDenied ? 'Settings' : 'Allow'),
              style: TextStyle(
                color: granted ? Colors.greenAccent.shade400 : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
