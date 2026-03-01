import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'components/camera_view.dart';
import 'components/metrics_display.dart';
import 'components/voice_alert_service.dart';
import 'components/assistant_dialog.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class DrowsinessMonitoringScreen extends StatefulWidget {
  const DrowsinessMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<DrowsinessMonitoringScreen> createState() =>
      _DrowsinessMonitoringScreenState();
}

class _DrowsinessMonitoringScreenState extends State<DrowsinessMonitoringScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late bool _isDarkMode;
  bool _isMonitoring = false;
  bool _isInitializing = true;

  static const EventChannel _dmsFrames =
      EventChannel('com.example.okdriver/drowsiness_frames');
  static const MethodChannel _dmsChannel =
      MethodChannel('com.example.okdriver/drowsiness');

  StreamSubscription<dynamic>? _framesSub;
  Map<String, dynamic>? _detectionResult;
  Map<String, dynamic>? _metrics;
  bool _isConnected = false;
  int _localDrowsyFrames = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final VoiceAlertService _voiceAlertService = VoiceAlertService();

  int _drowsyEvents = 0;
  int _lastDialogEvent = 0;
  bool _isDialogShowing = false;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _framesSub?.cancel();
    _voiceAlertService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (_isMonitoring) {
      _dmsChannel.invokeMethod('updateVisibility', {
        'visible': state == AppLifecycleState.resumed,
      }).catchError((e) => debugPrint('[DMS] updateVisibility error: $e'));
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    await _voiceAlertService.initializeSilent();
    if (mounted) setState(() => _isInitializing = false);
  }

  // =========================================================================
  // ✅ Permission request — Camera + Overlay (background alert ke liye)
  // =========================================================================
  Future<bool> _requestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    // Step 1: Camera + Mic permission
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.speech,
    ].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    if (!cameraGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission required for monitoring'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // Step 2: Overlay permission check (background alert ke liye zaroori)
    try {
      final hasOverlay =
          await _dmsChannel.invokeMethod<bool>('checkOverlayPermission') ??
              false;

      if (!hasOverlay && mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor:
                _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Background Alert',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              'Background mein drowsiness alert screen par dikhane ke liye "Display over other apps" permission chahiye.\n\nSettings mein OKDriver ko Allow karo.',
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Give Permission',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        );

        if (shouldRequest == true) {
          await _dmsChannel.invokeMethod('requestOverlayPermission');
          // Settings se wapas aane ka wait karo
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Settings mein OKDriver ko Allow karke wapas aao'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('[DMS] Overlay permission check error: $e');
    }

    await _voiceAlertService.initialize();
    return true;
  }

  // =========================================================================
  // Detection message handler
  // =========================================================================
  void _handleDetectionMessage(dynamic data) {
    try {
      final message = data is String ? json.decode(data) : data;

      if (message['type'] == 'show_dialog') {
        final events = message['drowsy_events'] ?? _drowsyEvents;
        if (mounted) {
          setState(() {
            _drowsyEvents = events;
            _lastDialogEvent = _drowsyEvents;
          });
        }

        // ✅ Foreground mein Flutter dialog, background mein WindowManager overlay
        if (_lifecycleState == AppLifecycleState.resumed &&
            !_isDialogShowing &&
            mounted) {
          _showAssistantBottomSheet();
        } else {
          debugPrint(
              '[DMS] show_dialog skipped — lifecycle: $_lifecycleState, dialogShowing: $_isDialogShowing');
        }
        return;
      }

      if (message['type'] == 'detection_result') {
        final result = message['data'];
        final Map<String, dynamic> newMetrics =
            Map<String, dynamic>.from(result['metrics'] ?? {});

        final earValue = (newMetrics['ear'] is num)
            ? (newMetrics['ear'] as num).toDouble()
            : 0.0;
        if (earValue > 0 && earValue <= 0.05) _localDrowsyFrames++;

        final serverDrowsy = (newMetrics['drowsy_frames'] is num)
            ? (newMetrics['drowsy_frames'] as num).toInt()
            : 0;
        newMetrics['drowsy_frames'] = _localDrowsyFrames > serverDrowsy
            ? _localDrowsyFrames
            : serverDrowsy;

        if (mounted) {
          setState(() {
            _detectionResult = result;
            _metrics = newMetrics;
          });
        }

        _handleAlerts(result);
      }
    } catch (e) {
      debugPrint('Error parsing detection message: $e');
    }
  }

  void _handleAlerts(Map<String, dynamic> result) {
    final status = result['status'];
    final shouldAlert =
        result['should_alert'] ?? (result['alert_level'] ?? 0) >= 2;
    final alertLevel = result['alert_level'] ?? 0;

    if (shouldAlert && status == 'DROWSY') {
      _voiceAlertService.alertDrowsy(isCritical: alertLevel >= 4);
      _pulseController.repeat(reverse: true);
      _drowsyEvents++;
    } else if (status == 'YAWNING') {
      _voiceAlertService.alertYawning();
    } else if (status == 'NO_FACE') {
      _voiceAlertService.alertNoFace();
    } else if (status == 'ALERT') {
      _voiceAlertService.stopBeep();
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _showAssistantBottomSheet() {
    if (!mounted || _isDialogShowing) return;
    _isDialogShowing = true;
    _voiceAlertService.stopBeep();
    _pulseController.stop();

    debugPrint('[DMS] Flutter foreground: alarm → TTS → dialog...');

    _voiceAlertService.playAlarmThenCheckIn().then((_) {
      if (!mounted) {
        _isDialogShowing = false;
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => AssistantDialog(
          drowsyEvents: _drowsyEvents,
          onDialogClosed: (responded) {
            _isDialogShowing = false;
            if (responded) {
              setState(() {
                _drowsyEvents = 0;
                _lastDialogEvent = 0;
              });
            }
          },
        ),
      ).then((_) => _isDialogShowing = false);
    }).catchError((e) {
      debugPrint('[DMS] playAlarmThenCheckIn error: $e');
      _isDialogShowing = false;
      if (!mounted) return;
      _isDialogShowing = true;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => AssistantDialog(
          drowsyEvents: _drowsyEvents,
          onDialogClosed: (responded) {
            _isDialogShowing = false;
            if (responded) {
              setState(() {
                _drowsyEvents = 0;
                _lastDialogEvent = 0;
              });
            }
          },
        ),
      ).then((_) => _isDialogShowing = false);
    });
  }

  void _toggleMonitoring() {
    if (!_isMonitoring) {
      _startNativeDMS();
    } else {
      setState(() => _isMonitoring = false);
      _stopNativeDMS();
    }
  }

  Future<void> _startNativeDMS() async {
    final granted = await _requestAllPermissions();
    if (!granted) return;

    setState(() {
      _isMonitoring = true;
      _drowsyEvents = 0;
      _lastDialogEvent = 0;
      _localDrowsyFrames = 0;
      _detectionResult = null;
      _metrics = null;
      _isConnected = false;
      _isDialogShowing = false;
    });

    try {
      await _dmsChannel.invokeMethod('startService');
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _dmsChannel.invokeMethod('updateVisibility', {'visible': true});
      } catch (e) {
        debugPrint('[DMS] updateVisibility (non-fatal): $e');
      }

      _framesSub?.cancel();
      _framesSub = _dmsFrames.receiveBroadcastStream().listen(
            (dynamic data) => _handleDetectionMessage(data),
            onError: (e) => debugPrint('[DMS] Stream error: $e'),
          );
      setState(() => _isConnected = true);
    } catch (e) {
      debugPrint('[DMS] Error starting: $e');
      setState(() {
        _isMonitoring = false;
        _isConnected = false;
      });
    }
  }

  Future<void> _stopNativeDMS() async {
    _pulseController.stop();
    _pulseController.reset();
    _voiceAlertService.stopBeep();
    setState(() {
      _drowsyEvents = 0;
      _lastDialogEvent = 0;
      _localDrowsyFrames = 0;
      _detectionResult = null;
      _metrics = null;
      _isConnected = false;
      _isDialogShowing = false;
    });
    try {
      _framesSub?.cancel();
      _framesSub = null;
      await _dmsChannel.invokeMethod('stopService');
    } catch (_) {}
  }

  void _resetDetection() {
    setState(() {
      _detectionResult = null;
      _metrics = null;
      _drowsyEvents = 0;
      _lastDialogEvent = 0;
      _localDrowsyFrames = 0;
    });
  }

  // =========================================================================
  // UI
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildCameraSection(),
                    const SizedBox(height: 20),
                    MetricsDisplay(metrics: _metrics, isDarkMode: _isDarkMode),
                    const SizedBox(height: 20),
                    _buildControlButtons(),
                    const SizedBox(height: 20),
                    _buildStatusInfo(),
                    const SizedBox(height: 20),
                    _buildDisclaimer(),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drowsiness Monitoring',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'AI-powered drowsiness detection',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: _isMonitoring
                      ? Colors.green.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: _isMonitoring
                    ? Colors.green.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CameraView(
                  onFrameCaptured: (frameData) {},
                  isMonitoring: _isMonitoring,
                  detectionResult: _detectionResult,
                  shouldCapture: () => false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isInitializing ? null : _toggleMonitoring,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMonitoring ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isMonitoring ? Icons.stop : Icons.play_arrow, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _resetDetection,
            icon: Icon(Icons.refresh,
                color: _isDarkMode ? Colors.white : Colors.black, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Information',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_drowsyEvents > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _drowsyEvents >= 3 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Events: $_drowsyEvents',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
              'Connection',
              _isConnected ? 'Connected' : 'Disconnected',
              _isConnected ? Colors.green : Colors.red,
              Icons.wifi),
          const SizedBox(height: 8),
          _buildStatusRow('Monitoring', _isMonitoring ? 'Active' : 'Inactive',
              _isMonitoring ? Colors.green : Colors.grey, Icons.visibility),
          const SizedBox(height: 8),
          _buildStatusRow(
              'Voice Alerts',
              _voiceAlertService.isInitialized ? 'Enabled' : 'Disabled',
              _voiceAlertService.isInitialized ? Colors.green : Colors.grey,
              Icons.volume_up),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 14)),
        ),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.blue.withOpacity(0.1)
            : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Background Monitoring Active',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitoring continues in background. Alerts appear as native overlay dialog.',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
