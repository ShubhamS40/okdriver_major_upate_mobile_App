import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/service/api_config.dart';
import 'components/camera_view.dart';
import 'components/metrics_display.dart';
import 'components/voice_alert_service.dart';
import 'components/assistant_dialog.dart';
import 'dart:convert';
import 'dart:async';

class DrowsinessMonitoringScreen extends StatefulWidget {
  const DrowsinessMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<DrowsinessMonitoringScreen> createState() =>
      _DrowsinessMonitoringScreenState();
}

class _DrowsinessMonitoringScreenState extends State<DrowsinessMonitoringScreen>
    with TickerProviderStateMixin {
  late bool _isDarkMode;
  bool _isMonitoring = false;
  bool _isConnected = false;
  bool _isInitializing = true;

  WebSocketChannel? _channel;
  Map<String, dynamic>? _detectionResult;
  Map<String, dynamic>? _metrics;
  bool _canSendFrame = true;
  String? _latestFramePending;
  int? _localDrowsyFrames;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final VoiceAlertService _voiceAlertService = VoiceAlertService();
  Timer? _connectionTimer;
  Timer? _pingTimer;

  // Assistant dialog state
  bool _showAssistantDialog = false;
  int _drowsyEvents = 0;
  bool _assistantDialogShown = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
    // Initialize local metrics trackers with default value 10
    _localDrowsyFrames = 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _connectionTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _voiceAlertService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServices() async {
    await _voiceAlertService.initialize();

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _connectToWebSocket() async {
    try {
      // Prefer device-local network. If running backend on same device, use 127.0.0.1 via Android emulator mapping.
      // Consider exposing this from ApiConfig if needed.
      final wsUrl = "ws://20.204.177.196:8000/ws";

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) => _handleWebSocketError(error),
        onDone: () => _handleWebSocketClosed(),
      );

      setState(() {
        _isConnected = true;
      });

      // Start ping timer
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (_isConnected && _channel != null) {
          _channel!.sink.add(json.encode({'type': 'ping'}));
        }
      });

      print('WebSocket connected successfully');
    } catch (e) {
      print('WebSocket connection error: $e');
      setState(() {
        _isConnected = false;
      });

      // Retry connection after 5 seconds
      _connectionTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_isConnected) {
          _connectToWebSocket();
        }
      });
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final message = json.decode(data);

      if (message['type'] == 'detection_result') {
        final result = message['data'];

        // Copy metrics to mutate locally
        final Map<String, dynamic> newMetrics =
            Map<String, dynamic>.from(result['metrics'] ?? {});

        // Apply EAR-based local drowsy frame increment when ear <= 0.05
        final earValue = (newMetrics['ear'] is num)
            ? (newMetrics['ear'] as num).toDouble()
            : 0.0;
        if (earValue > 0 && earValue <= 0.05) {
          _localDrowsyFrames = (_localDrowsyFrames ?? 0) + 1;
          // ignore: avoid_print
          print(
              '[DMS] EAR threshold hit (<= 0.05). Local drowsy_frames=$_localDrowsyFrames');
        }

        // Merge local drowsy frames with server value (take the max)
        final serverDrowsy = (newMetrics['drowsy_frames'] is num)
            ? (newMetrics['drowsy_frames'] as num).toInt()
            : 0;
        final mergedDrowsyFrames = (_localDrowsyFrames ?? 0) > serverDrowsy
            ? (_localDrowsyFrames ?? 0)
            : serverDrowsy;
        newMetrics['drowsy_frames'] = mergedDrowsyFrames;

        setState(() {
          _detectionResult = result;
          _metrics = newMetrics;
        });

        // Handle alerts
        _handleAlerts(result);

        // Allow next frame and flush latest pending (drop older ones)
        if (_isMonitoring && _isConnected) {
          _canSendFrame = true;
          if (_latestFramePending != null && _channel != null) {
            _channel!.sink.add(json.encode({
              'type': 'frame',
              'data': _latestFramePending,
            }));
            _latestFramePending = null;
            _canSendFrame = false;
          }
        }
      } else if (message['type'] == 'pong') {
        // Connection is alive
        print('WebSocket ping successful');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _handleAlerts(Map<String, dynamic> result) {
    final status = result['status'];
    final shouldAlert =
        result['should_alert'] ?? (result['alert_level'] ?? 0) >= 2;
    final alertLevel = result['alert_level'] ?? 0;

    if (shouldAlert && status == 'DROWSY') {
      _voiceAlertService.alertDrowsy(isCritical: alertLevel >= 4);
      _voiceAlertService.startBipLoop();
      _pulseController.repeat(reverse: true);

      // Increment drowsy events counter
      _drowsyEvents++;

      // Show assistant dialog after 2 drowsy events
      if (_drowsyEvents >= 2 && !_assistantDialogShown) {
        _showAssistantBottomSheet();
      }
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
    setState(() {
      _assistantDialogShown = true;
    });

    // Stop beeping while assistant is talking
    _voiceAlertService.stopBeep();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssistantDialog(
        drowsyEvents: _drowsyEvents,
        onDialogClosed: (responded) {
          setState(() {
            _assistantDialogShown = false;
            // Reset drowsy events counter if driver responded
            if (responded) {
              _drowsyEvents = 0;
            }
          });
        },
      ),
    );
  }

  void _handleWebSocketError(error) {
    print('WebSocket error: $error');
    setState(() {
      _isConnected = false;
    });
  }

  void _handleWebSocketClosed() {
    print('WebSocket connection closed');
    setState(() {
      _isConnected = false;
    });
  }

  void _toggleMonitoring() {
    if (!_isConnected) {
      _connectToWebSocket();
      return;
    }

    setState(() {
      _isMonitoring = !_isMonitoring;
    });

    if (!_isMonitoring) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _resetDetection() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(json.encode({'type': 'reset'}));
    }

    setState(() {
      _detectionResult = null;
      _metrics = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Camera View
                    _buildCameraSection(),

                    const SizedBox(height: 20),

                    // Metrics Display
                    MetricsDisplay(
                      metrics: _metrics,
                      isDarkMode: _isDarkMode,
                    ),

                    const SizedBox(height: 20),

                    // Control Buttons
                    _buildControlButtons(),

                    const SizedBox(height: 20),

                    // Status Information
                    _buildStatusInfo(),

                    const SizedBox(height: 20),

                    // Disclaimer
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

          // Connection Status
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
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CameraView(
              onFrameCaptured: (frameData) {
                if (_isMonitoring && _isConnected && _channel != null) {
                  if (_canSendFrame) {
                    _canSendFrame = false;
                    _channel!.sink.add(json.encode({
                      'type': 'frame',
                      'data': frameData,
                    }));
                  } else {
                    // Only keep the latest frame; drop older pending
                    _latestFramePending = frameData;
                  }
                }
              },
              isMonitoring: _isMonitoring,
              detectionResult: _detectionResult,
              shouldCapture: () => _canSendFrame || _latestFramePending == null,
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isMonitoring ? Icons.stop : Icons.play_arrow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
            icon: Icon(
              Icons.refresh,
              color: _isDarkMode ? Colors.white : Colors.black,
              size: 24,
            ),
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
          Text(
            'Status Information',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            'Connection',
            _isConnected ? 'Connected' : 'Disconnected',
            _isConnected ? Colors.green : Colors.red,
            Icons.wifi,
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            'Monitoring',
            _isMonitoring ? 'Active' : 'Inactive',
            _isMonitoring ? Colors.green : Colors.grey,
            Icons.visibility,
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            'Voice Alerts',
            _voiceAlertService.isInitialized ? 'Enabled' : 'Disabled',
            _voiceAlertService.isInitialized ? Colors.green : Colors.grey,
            Icons.volume_up,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.orange.withOpacity(0.1)
            : Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Background service feature is coming soon. Currently, monitoring works only when the app is active.',
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
