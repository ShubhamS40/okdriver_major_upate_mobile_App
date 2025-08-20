import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

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
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  Timer? _captureTimer;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _isFront = frontCamera.lensDirection == CameraLensDirection.front;

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startCapturing() {
    if (!_isInitialized || _isCapturing) return;

    _isCapturing = true;
    _captureTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final allow =
          widget.shouldCapture == null ? true : widget.shouldCapture!();
      if (widget.isMonitoring && _isCapturing && allow) {
        _captureFrame();
      } else {
        if (!widget.isMonitoring || !_isCapturing) {
          timer.cancel();
          _isCapturing = false;
        }
      }
    });
  }

  void _stopCapturing() {
    _captureTimer?.cancel();
    _isCapturing = false;
  }

  Future<void> _captureFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      widget.onFrameCaptured(dataUrl);
    } catch (e) {
      print('Error capturing frame: $e');
    }
  }

  @override
  void didUpdateWidget(CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isMonitoring && !oldWidget.isMonitoring) {
      _startCapturing();
    } else if (!widget.isMonitoring && oldWidget.isMonitoring) {
      _stopCapturing();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
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
        child: Stack(
          children: [
            // FIXED: Camera preview that fills entire container
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: _isFront
                    ? (Matrix4.identity()..rotateY(math.pi))
                    : Matrix4.identity(),
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            if (widget.detectionResult != null &&
                                widget.detectionResult!['face_detected'] ==
                                    true)
                              _buildFaceOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Status indicator
            Positioned(
              top: 20,
              left: 20,
              child: _buildStatusIndicator(),
            ),

            // Monitoring indicator
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
              mirrorHorizontally: _isFront,
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
    final paint = Paint()
      ..color = _getStatusColor()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = _getStatusColor().withOpacity(0.2)
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

  Color _getStatusColor() {
    switch (status) {
      case 'DROWSY':
        return alertLevel >= 4 ? Colors.red : Colors.orange;
      case 'YAWNING':
        return Colors.yellow.shade700;
      case 'ALERT':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
