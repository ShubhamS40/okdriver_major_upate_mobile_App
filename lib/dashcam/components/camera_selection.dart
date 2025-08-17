import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:okdriver/dashcam/dashcam_screen.dart';

class CameraSelectionScreen extends StatefulWidget {
  const CameraSelectionScreen({Key? key}) : super(key: key);

  @override
  State<CameraSelectionScreen> createState() => _CameraSelectionScreenState();
}

class _CameraSelectionScreenState extends State<CameraSelectionScreen> {
  bool _isLoading = true;
  List<CameraDescription> _cameras = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status.isGranted) {
        // Get available cameras
        final cameras = await availableCameras();
        setState(() {
          _cameras = cameras;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Camera permission is required to use the dashcam feature';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize cameras: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Camera'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choose Camera for Dashcam Recording',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      _buildCameraOption(
                        title: 'Front Camera',
                        icon: Icons.camera_front,
                        onTap: () => _navigateToDashcam(CameraType.front),
                      ),
                      const SizedBox(height: 16),
                      _buildCameraOption(
                        title: 'Back Camera',
                        icon: Icons.camera_rear,
                        onTap: () => _navigateToDashcam(CameraType.back),
                      ),
                      const SizedBox(height: 16),
                      _buildCameraOption(
                        title: 'Dual Camera (Simulated)',
                        icon: Icons.camera,
                        onTap: () => _navigateToDashcam(CameraType.dual),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCameraOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDashcam(CameraType cameraType) {
    // Check if we have the required cameras
    if (_cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cameras available on this device')),
      );
      return;
    }

    // Find front and back cameras
    CameraDescription? frontCamera;
    CameraDescription? backCamera;

    for (var camera in _cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
      } else if (camera.lensDirection == CameraLensDirection.back) {
        backCamera = camera;
      }
    }

    // Validate camera selection based on type
    switch (cameraType) {
      case CameraType.front:
        if (frontCamera == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Front camera not available')),
          );
          return;
        }
        break;
      case CameraType.back:
        if (backCamera == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Back camera not available')),
          );
          return;
        }
        break;
      case CameraType.dual:
        // For dual mode, we need at least one camera (preferably front)
        if (frontCamera == null && backCamera == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available for dual mode')),
          );
          return;
        }
        break;
    }

    // Navigate to dashcam screen with selected camera type
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DashcamScreen(
          cameraType: cameraType,
          frontCamera: frontCamera,
          backCamera: backCamera,
        ),
      ),
    );
  }
}

// Enum to represent camera types
enum CameraType { front, back, dual }
