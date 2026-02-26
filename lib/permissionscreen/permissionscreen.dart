import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:okdriver/role_selection/role_selection.dart';

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
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCameraPermission();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCameraPermission();
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

  Future<void> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      debugPrint('📷 Current camera status: $status');

      if (mounted) {
        setState(() => _cameraStatus = status);
      }
    } catch (e) {
      debugPrint('❌ Error checking camera permission: $e');
    }
  }

  Future<void> _requestCameraPermission() async {
    if (_isRequesting) return;

    HapticFeedback.lightImpact();

    setState(() => _isRequesting = true);

    try {
      debugPrint('📷 Requesting camera permission...');

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
          _showSuccessDialog();
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
                  _goNext();
                },
                child: const Text('Continue'),
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
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
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
    final isGranted = _cameraStatus.isGranted;
    final isPermanentlyDenied = _cameraStatus.isPermanentlyDenied;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                /// ICON
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: isGranted ? Colors.green : Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGranted ? Icons.check : Icons.camera_alt,
                    size: 50,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                /// TITLE
                const Text(
                  'Camera Permission',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                /// DESCRIPTION
                const Text(
                  'OK Driver requires camera access to record dashcam videos '
                  'and capture trip evidence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                /// STATUS CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isGranted ? Colors.green : Colors.grey.shade300,
                      width: isGranted ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGranted ? Icons.verified : Icons.error_outline,
                        color: isGranted ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isGranted
                              ? 'Camera permission granted ✓'
                              : isPermanentlyDenied
                                  ? 'Camera permission denied'
                                  : 'Camera permission not granted',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isGranted ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                /// MAIN BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRequesting
                        ? null
                        : isPermanentlyDenied
                            ? () async => await openAppSettings()
                            : isGranted
                                ? _goNext
                                : _requestCameraPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGranted ? Colors.green : Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
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
                            isPermanentlyDenied
                                ? 'Open Settings'
                                : isGranted
                                    ? 'Continue'
                                    : 'Enable Camera',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                /// SKIP BUTTON
                if (!isGranted)
                  TextButton(
                    onPressed: _goNext,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
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
}
