import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraType { front, back, dual }

class CameraService {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isAudioEnabled = true;
  String? _currentVideoPath;
  Timer? _recordingTimer;
  int _elapsedSeconds = 0;

  // Stream controllers for broadcasting state changes
  final _recordingStateController =
      StreamController<RecordingState>.broadcast();
  Stream<RecordingState> get recordingStateStream =>
      _recordingStateController.stream;

  // Getters for current state
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get isAudioEnabled => _isAudioEnabled;
  CameraController? get cameraController => _cameraController;
  String? get currentVideoPath => _currentVideoPath;
  int get elapsedSeconds => _elapsedSeconds;

  // Initialize camera
  Future<void> initializeCamera({
    required CameraDescription cameraDescription,
    bool enableAudio = true,
  }) async {
    _isAudioEnabled = enableAudio;

    // Dispose of any existing controller
    await _cameraController?.dispose();

    // Create a new controller
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: _isAudioEnabled,
    );

    try {
      // Initialize the controller
      await _cameraController!.initialize();
      _isInitialized = true;
      _notifyStateChange();
    } catch (e) {
      _isInitialized = false;
      _notifyStateChange();
      rethrow;
    }
  }

  // Start recording
  Future<void> startRecording() async {
    if (!_isInitialized || _cameraController == null) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) {
      return;
    }

    // Ensure storage permission is granted
    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      throw Exception('Storage permission is required to save videos');
    }

    // Create a timestamped file path for the video
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final path = '${directory.path}/dashcam_$timestamp.mp4';
    _currentVideoPath = path;

    try {
      await _cameraController!.startVideoRecording();
      _isRecording = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _startRecordingTimer();
      _notifyStateChange();
    } catch (e) {
      _isRecording = false;
      _currentVideoPath = null;
      _notifyStateChange();
      rethrow;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    if (!_isRecording || _cameraController == null) {
      return null;
    }

    _stopRecordingTimer();

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      _isRecording = false;
      _isPaused = false;
      final savedPath = videoFile.path;
      _notifyStateChange();
      return savedPath;
    } catch (e) {
      _notifyStateChange();
      rethrow;
    }
  }

  // Pause recording
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused || _cameraController == null) {
      return;
    }

    try {
      await _cameraController!.pauseVideoRecording();
      _isPaused = true;
      _stopRecordingTimer();
      _notifyStateChange();
    } catch (e) {
      _notifyStateChange();
      rethrow;
    }
  }

  // Resume recording
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused || _cameraController == null) {
      return;
    }

    try {
      await _cameraController!.resumeVideoRecording();
      _isPaused = false;
      _startRecordingTimer();
      _notifyStateChange();
    } catch (e) {
      _notifyStateChange();
      rethrow;
    }
  }

  // Toggle audio
  Future<void> toggleAudio() async {
    _isAudioEnabled = !_isAudioEnabled;

    if (_cameraController != null && _isInitialized) {
      final currentCamera = _cameraController!.description;
      await _cameraController!.dispose();
      await initializeCamera(
        cameraDescription: currentCamera,
        enableAudio: _isAudioEnabled,
      );
    }

    _notifyStateChange();
  }

  // Delete current recording
  Future<void> deleteCurrentRecording() async {
    if (_isRecording) {
      await stopRecording();
    }

    if (_currentVideoPath != null) {
      try {
        final file = File(_currentVideoPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentVideoPath = null;
      } catch (e) {
        rethrow;
      }
    }
  }

  // Get all saved videos
  Future<List<String>> getSavedVideos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = Directory(directory.path).listSync();
      return files
          .where((file) =>
              file.path.contains('dashcam_') && file.path.endsWith('.mp4'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Start recording timer
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _notifyStateChange();
    });
  }

  // Stop recording timer
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // Notify state change
  void _notifyStateChange() {
    _recordingStateController.add(
      RecordingState(
        isInitialized: _isInitialized,
        isRecording: _isRecording,
        isPaused: _isPaused,
        isAudioEnabled: _isAudioEnabled,
        elapsedSeconds: _elapsedSeconds,
        currentVideoPath: _currentVideoPath,
      ),
    );
  }

  // Dispose resources
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _cameraController?.dispose();
    await _recordingStateController.close();
  }

  // Format recording duration
  String getFormattedDuration() {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class RecordingState {
  final bool isInitialized;
  final bool isRecording;
  final bool isPaused;
  final bool isAudioEnabled;
  final int elapsedSeconds;
  final String? currentVideoPath;

  RecordingState({
    required this.isInitialized,
    required this.isRecording,
    required this.isPaused,
    required this.isAudioEnabled,
    required this.elapsedSeconds,
    this.currentVideoPath,
  });
}
