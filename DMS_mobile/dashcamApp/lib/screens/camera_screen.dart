import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image/image.dart' as img;
import '../services/drowsiness_detector.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isDetecting = false;

  final DrowsinessDetector _detector = DrowsinessDetector();
  final AudioPlayer _audioPlayer = AudioPlayer();

  DetectionResult? _lastResult;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Use front camera
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _startDetection() {
    if (!_isInitialized || _controller == null) return;

    setState(() {
      _isDetecting = true;
    });

    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_isDetecting ||
          _controller == null ||
          !_controller!.value.isInitialized) {
        timer.cancel();
        return;
      }

      try {
        final image = await _controller!.takePicture();
        final imageBytes = await image.readAsBytes();
        final decodedImage = img.decodeImage(imageBytes);

        if (decodedImage != null) {
          // Use image as-is (image package handles format conversion internally)
          final result = await _detector.processFrame(decodedImage);

          if (mounted) {
            setState(() {
              _lastResult = result;
            });

            // Play alarm if needed
            if (result.shouldAlert && (result.alertLevel >= 3)) {
              _playAlarm();
            } else {
              _stopAlarm();
            }
          }
        }
      } catch (e) {
        print('Error processing frame: $e');
      }
    });
  }

  void _stopDetection() {
    setState(() {
      _isDetecting = false;
    });

    _detectionTimer?.cancel();
    _stopAlarm();
  }

  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      print('Error playing alarm: $e');
    }
  }

  Future<void> _stopAlarm() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // Ignore errors
    }
  }

  Color _getStatusColor() {
    if (_lastResult == null) return Colors.grey;

    switch (_lastResult!.alertLevel) {
      case 4:
        return Colors.red.shade900;
      case 3:
        return Colors.red;
      case 2:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    _detector.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DashCam - Drowsiness Detection'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isInitialized && _controller != null
          ? Column(
              children: [
                // Camera Preview
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!),

                      // Status Overlay
                      if (_lastResult != null)
                        Positioned(
                          top: 20,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: ${_lastResult!.status}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_lastResult!.message.isNotEmpty)
                                  Text(
                                    _lastResult!.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // Metrics Overlay
                      if (_lastResult != null && _lastResult!.faceDetected)
                        Positioned(
                          bottom: 100,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EAR: ${_lastResult!.ear?.toStringAsFixed(3) ?? "N/A"}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'MAR: ${_lastResult!.mar?.toStringAsFixed(3) ?? "N/A"}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'CNN: ${_lastResult!.cnnConfidence?.toStringAsFixed(2) ?? "N/A"}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'Events: ${_lastResult!.drowsyEvents}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Control Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black87,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isDetecting ? null : _startDetection,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isDetecting ? _stopDetection : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _detector.reset();
                          setState(() {
                            _lastResult = null;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
