import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraView extends StatefulWidget {
  final Function(String) onFrameCaptured;
  final bool isMonitoring;
  final Map<String, dynamic>? detectionResult;
  final bool Function()? shouldCapture;

  // ✅ Set to true to show debug info at bottom of preview (frame dims + first point)
  static const bool kDebugLandmarks = false;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  void didUpdateWidget(CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera Feed ───────────────────────────────────────────────
          Positioned.fill(
            child: Platform.isAndroid
                ? const AndroidView(
                    viewType: 'dms_camera_preview_view',
                    creationParamsCodec: StandardMessageCodec(),
                  )
                : Container(color: Colors.black),
          ),

          // ── Face Landmark Overlay ─────────────────────────────────────
          if (widget.detectionResult != null &&
              widget.detectionResult!['face_detected'] == true)
            Positioned.fill(
              child: _buildFaceOverlay(),
            ),

          // ── Debug info overlay (enable kDebugLandmarks to see) ────────
          if (CameraView.kDebugLandmarks && widget.detectionResult != null)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: _buildDebugInfo(),
            ),

          // ── Status Badge (top-left) ───────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            child: _buildStatusIndicator(),
          ),

          // ── Monitoring Badge (top-right) ──────────────────────────────
          if (widget.isMonitoring)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'MONITORING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    final frameSize = widget.detectionResult!['frame_size'];
    final landmarks = widget.detectionResult!['landmarks'];
    String nosePt = 'null';
    String eyePt = 'null';
    if (landmarks != null) {
      final nose = landmarks['nose'] as List?;
      if (nose != null && nose.isNotEmpty)
        nosePt =
            '${nose[0][0].toStringAsFixed(0)},${nose[0][1].toStringAsFixed(0)}';
      final eye = landmarks['left_eye'] as List?;
      if (eye != null && eye.isNotEmpty)
        eyePt =
            '${eye[0][0].toStringAsFixed(0)},${eye[0][1].toStringAsFixed(0)}';
    }
    return Container(
      padding: const EdgeInsets.all(6),
      color: Colors.black.withOpacity(0.75),
      child: Text(
        'frame:${frameSize?["width"]}x${frameSize?["height"]}  nose[0]:$nosePt  leye[0]:$eyePt',
        style: const TextStyle(color: Colors.yellow, fontSize: 9),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (widget.detectionResult == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'INITIALIZING',
          style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    final status = widget.detectionResult!['status'] ?? 'UNKNOWN';
    final alertLevel = widget.detectionResult!['alert_level'] ?? 0;

    Color bg;
    String text;
    switch (status) {
      case 'DROWSY':
        bg = alertLevel >= 4 ? Colors.red : Colors.orange;
        text = alertLevel >= 4 ? 'CRITICAL' : 'DROWSY';
        break;
      case 'YAWNING':
        bg = Colors.yellow.shade700;
        text = 'YAWNING';
        break;
      case 'ALERT':
        bg = Colors.green;
        text = 'ALERT';
        break;
      case 'NO_FACE':
        bg = Colors.grey;
        text = 'NO FACE';
        break;
      default:
        bg = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFaceOverlay() {
    final landmarks = widget.detectionResult!['landmarks'];
    if (landmarks == null) return const SizedBox.shrink();

    final frameSize = widget.detectionResult!['frame_size'];
    final rawW =
        (frameSize != null ? (frameSize['width'] ?? 480) : 480).toDouble();
    final rawH =
        (frameSize != null ? (frameSize['height'] ?? 640) : 640).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: FaceLandmarksPainter(
            landmarks: landmarks,
            status: widget.detectionResult!['status'] ?? 'ALERT',
            alertLevel: widget.detectionResult!['alert_level'] ?? 0,
            rawFrameWidth: rawW,
            rawFrameHeight: rawH,
          ),
        );
      },
    );
  }
}

// =============================================================================
// FaceLandmarksPainter
// =============================================================================
class FaceLandmarksPainter extends CustomPainter {
  final Map<String, dynamic> landmarks;
  final String status;
  final int alertLevel;
  final double rawFrameWidth;
  final double rawFrameHeight;

  FaceLandmarksPainter({
    required this.landmarks,
    required this.status,
    required this.alertLevel,
    required this.rawFrameWidth,
    required this.rawFrameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = _getStatusColor();

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final allPoints = <Offset>[];

    void tryGroup(String key) {
      final raw = landmarks[key];
      if (raw != null && raw is List && raw.isNotEmpty) {
        _drawGroup(canvas, size, raw as List<dynamic>, strokePaint, fillPaint,
            allPoints);
      }
    }

    tryGroup('left_eye');
    tryGroup('right_eye');
    tryGroup('mouth');
    tryGroup('nose');
    tryGroup('face');

    // ── Bounding box ───────────────────────────────────────────────────
    if (allPoints.isNotEmpty) {
      double minX = allPoints.first.dx;
      double maxX = allPoints.first.dx;
      double minY = allPoints.first.dy;
      double maxY = allPoints.first.dy;

      for (final p in allPoints) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(minX, minY, maxX, maxY).inflate(22),
          const Radius.circular(14),
        ),
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawGroup(
    Canvas canvas,
    Size size,
    List<dynamic> points,
    Paint strokePaint,
    Paint fillPaint,
    List<Offset> allPoints,
  ) {
    if (points.isEmpty) return;

    // =========================================================================
    // HOW ANDROID CAMERAPREVIEW + OPENCV WORK:
    //
    // 1. CameraX captures frames in SENSOR orientation = LANDSCAPE
    //    e.g. frame is 640 wide × 480 tall
    //
    // 2. Your Python/OpenCV server receives this raw frame and detects
    //    landmarks in LANDSCAPE coords: x ∈ [0,640), y ∈ [0,480)
    //    frame_size = { width: 640, height: 480 }
    //
    // 3. Android PreviewView displays the stream ROTATED 90° CCW (portrait)
    //    AND MIRRORED horizontally (front camera selfie mode).
    //
    // So to map landscape coords → portrait canvas:
    //
    //   Step 1: Rotate 90° CCW (landscape → portrait)
    //     px = ly
    //     py = (rawW - 1) - lx
    //     effective: srcW = rawH = 480, srcH = rawW = 640
    //
    //   Step 2: Mirror X for front camera
    //     px = (srcW - 1) - px
    //        = (rawH - 1) - ly
    //
    //   Step 3: BoxFit.cover scale to canvas
    //     scaleX = canvasW / srcW
    //     scaleY = canvasH / srcH
    //     coverScale = max(scaleX, scaleY)
    //     offsetX = (canvasW - srcW*coverScale) / 2
    //     offsetY = (canvasH - srcH*coverScale) / 2
    //     canvasX = px * coverScale + offsetX
    //     canvasY = py * coverScale + offsetY
    //
    // IF server already sends PORTRAIT landmarks (rawH > rawW):
    //   Skip Step 1, just mirror X in portrait space.
    // =========================================================================

    final bool isLandscape = rawFrameWidth > rawFrameHeight;

    double srcW;
    double srcH;

    final path = Path();
    final processed = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final lx = pt[0].toDouble();
      final ly = pt[1].toDouble();

      double px;
      double py;

      if (isLandscape) {
        // Server sends landscape (e.g. 640×480) → rotate CCW then mirror
        srcW = rawFrameHeight; // 480
        srcH = rawFrameWidth; // 640

        // Rotate 90° CCW
        px = ly;
        py = (rawFrameWidth - 1) - lx;

        // Mirror X (front camera)
        px = (srcW - 1) - px;
      } else {
        // Server sends portrait (e.g. 480×640) → just mirror X
        srcW = rawFrameWidth; // 480
        srcH = rawFrameHeight; // 640

        px = (srcW - 1) - lx;
        py = ly;
      }

      // BoxFit.cover scale
      final scaleX = size.width / srcW;
      final scaleY = size.height / srcH;
      final coverScale = math.max(scaleX, scaleY);
      final offsetX = (size.width - srcW * coverScale) / 2;
      final offsetY = (size.height - srcH * coverScale) / 2;

      final canvasX = px * coverScale + offsetX;
      final canvasY = py * coverScale + offsetY;

      processed.add(Offset(canvasX, canvasY));
    }

    for (int i = 0; i < processed.length; i++) {
      allPoints.add(processed[i]);
      if (i == 0) {
        path.moveTo(processed[i].dx, processed[i].dy);
      } else {
        path.lineTo(processed[i].dx, processed[i].dy);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  Color _getStatusColor() {
    switch (status) {
      case 'DROWSY':
        return alertLevel >= 4 ? Colors.red : Colors.orange;
      case 'YAWNING':
        return Colors.yellow.shade700;
      case 'ALERT':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  @override
  bool shouldRepaint(covariant FaceLandmarksPainter old) =>
      old.status != status ||
      old.alertLevel != alertLevel ||
      old.landmarks != landmarks;
}
