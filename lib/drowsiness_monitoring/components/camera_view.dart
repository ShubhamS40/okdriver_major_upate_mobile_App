import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class CameraView extends StatefulWidget {
  final Function(String) onFrameCaptured;
  final bool isMonitoring;
  final Map<String, dynamic>? detectionResult;
  final bool Function()? shouldCapture;

  const CameraView({
    Key? key,
    required this.onFrameCaptured,
    required this.isMonitoring,
    this.detectionResult,
    this.shouldCapture,
  }) : super(key: key);

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  bool _isInitialized = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PlatformView preview is managed natively; lifecycle handled via MethodChannel in screen
  }

  void _startCapturing() {}
  void _stopCapturing() {}

  @override
  void didUpdateWidget(CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No-op: capturing handled natively
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            // ── Camera Feed ────────────────────────────────────────────────
            Positioned.fill(
              child: Platform.isAndroid
                  ? const AndroidView(
                      viewType: 'dms_camera_preview_view',
                      creationParamsCodec: StandardMessageCodec(),
                    )
                  : Container(color: Colors.black),
            ),

            // ── Face Landmarks Overlay ─────────────────────────────────────
            // ✅ FIX: Sirf DROWSY aur YAWNING par overlay dikhao
            // ALERT status par green overlay nahi aayegi
            if (widget.detectionResult != null &&
                widget.detectionResult!['face_detected'] == true &&
                _shouldShowOverlay(widget.detectionResult!['status']))
              Positioned.fill(
                child: _buildFaceOverlay(),
              ),

            // ── Status Indicator (top-left) ────────────────────────────────
            Positioned(
              top: 20,
              left: 20,
              child: _buildStatusIndicator(),
            ),

            // ── Monitoring Badge (top-right) ───────────────────────────────
            if (widget.isMonitoring)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'MONITORING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ✅ FIX: Sirf DROWSY aur YAWNING par face landmark overlay dikhao
  /// ALERT par transparent/koi overlay nahi
  bool _shouldShowOverlay(String? status) {
    if (status == null) return false;
    switch (status) {
      case 'DROWSY':
      case 'YAWNING':
        return true;
      case 'ALERT':
      case 'NO_FACE':
      default:
        return false;
    }
  }

  Widget _buildStatusIndicator() {
    if (widget.detectionResult == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'INITIALIZING',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final status = widget.detectionResult!['status'] ?? 'UNKNOWN';
    final alertLevel = widget.detectionResult!['alert_level'] ?? 0;

    Color backgroundColor;
    String statusText;

    switch (status) {
      case 'DROWSY':
        backgroundColor = alertLevel >= 4 ? Colors.red : Colors.orange;
        statusText = alertLevel >= 4 ? 'CRITICAL' : 'DROWSY';
        break;
      case 'YAWNING':
        backgroundColor = Colors.yellow.shade700;
        statusText = 'YAWNING';
        break;
      case 'ALERT':
        backgroundColor = Colors.green;
        statusText = 'ALERT';
        break;
      case 'NO_FACE':
        backgroundColor = Colors.grey;
        statusText = 'NO FACE';
        break;
      default:
        backgroundColor = Colors.grey;
        statusText = 'UNKNOWN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFaceOverlay() {
    final landmarks = widget.detectionResult!['landmarks'];
    if (landmarks == null) return const SizedBox.shrink();

    final frameSize = widget.detectionResult!['frame_size'];
    final srcW = (frameSize != null ? (frameSize['width'] ?? 0) : 0).toDouble();
    final srcH =
        (frameSize != null ? (frameSize['height'] ?? 0) : 0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: CustomPaint(
            painter: FaceLandmarksPainter(
              landmarks: landmarks,
              status: widget.detectionResult!['status'] ?? 'ALERT',
              alertLevel: widget.detectionResult!['alert_level'] ?? 0,
              sourceWidth: srcW,
              sourceHeight: srcH,
              mirrorHorizontally: true,
            ),
          ),
        );
      },
    );
  }
}

class FaceLandmarksPainter extends CustomPainter {
  final Map<String, dynamic> landmarks;
  final String status;
  final int alertLevel;
  final double sourceWidth;
  final double sourceHeight;
  final bool mirrorHorizontally;

  FaceLandmarksPainter({
    required this.landmarks,
    required this.status,
    required this.alertLevel,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.mirrorHorizontally,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ✅ FIX: ALERT par kuch mat draw karo — transparent return
    final color = _getStatusColor();
    if (color == Colors.transparent) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color =
          color.withOpacity(0.15) // ✅ Fill opacity kam ki — zyada visible nahi
      ..style = PaintingStyle.fill;

    // Draw left eye
    if (landmarks['left_eye'] != null) {
      _drawLandmarks(canvas, size, landmarks['left_eye'], paint, fillPaint);
    }

    // Draw right eye
    if (landmarks['right_eye'] != null) {
      _drawLandmarks(canvas, size, landmarks['right_eye'], paint, fillPaint);
    }

    // Draw mouth
    if (landmarks['mouth'] != null) {
      _drawLandmarks(canvas, size, landmarks['mouth'], paint, fillPaint);
    }
  }

  void _drawLandmarks(Canvas canvas, Size size, List<dynamic> points,
      Paint paint, Paint fillPaint) {
    if (points.isEmpty) return;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      double x = point[0].toDouble();
      double y = point[1].toDouble();

      if (sourceWidth > 0 && sourceHeight > 0) {
        final sx = size.width / sourceWidth;
        final sy = size.height / sourceHeight;
        x *= sx;
        y *= sy;
      }

      if (mirrorHorizontally) {
        x = size.width - x;
      }

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  /// ✅ FIX: ALERT aur default par transparent return karo
  /// Sirf DROWSY → orange/red, YAWNING → yellow
  Color _getStatusColor() {
    switch (status) {
      case 'DROWSY':
        return alertLevel >= 4 ? Colors.red : Colors.orange;
      case 'YAWNING':
        return Colors.yellow.shade700;
      case 'ALERT':
        return Colors.transparent; // ✅ Koi overlay nahi
      default:
        return Colors.transparent; // ✅ Koi overlay nahi
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
