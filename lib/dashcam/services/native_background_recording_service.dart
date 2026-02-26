import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:okdriver/utlis/android14_storage_helper.dart';

class NativeBackgroundRecordingService {
  static const MethodChannel _channel =
      MethodChannel('com.example.okdriver/background_recording');

  static final NativeBackgroundRecordingService _instance =
      NativeBackgroundRecordingService._internal();
  factory NativeBackgroundRecordingService() => _instance;
  NativeBackgroundRecordingService._internal();

  bool _isRecording = false;
  String? _currentVideoPath;
  Timer? _statusTimer;
  StreamController<Map<String, dynamic>>? _statusController;

  // Stream to listen to recording status changes
  Stream<Map<String, dynamic>> get statusStream {
    _statusController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _statusController!.stream;
  }

  // Check if currently recording
  bool get isRecording => _isRecording;

  // Get current video path
  String? get currentVideoPath => _currentVideoPath;

  // Initialize the service
  Future<void> initialize() async {
    try {
      // Set up method call handler for responses from native code
      _channel.setMethodCallHandler(_handleMethodCall);

      // Start periodic status check
      _startStatusTimer();

      print('Native background recording service initialized');
    } catch (e) {
      print('Error initializing native background recording service: $e');
    }
  }

  // Handle method calls from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRecordingStarted':
        _isRecording = true;
        _currentVideoPath = call.arguments['filePath'] as String?;
        _notifyStatusChange();
        print('Native recording started: $_currentVideoPath');
        break;

      case 'onRecordingStopped':
        _isRecording = false;
        final filePath = call.arguments['filePath'] as String?;
        if (filePath != null) {
          _currentVideoPath = filePath;
          // Save to gallery
          await _saveToGallery(filePath);
        }
        _notifyStatusChange();
        print('Native recording stopped: $_currentVideoPath');
        break;

      case 'onRecordingError':
        _isRecording = false;
        final error = call.arguments['error'] as String?;
        print('Native recording error: $error');
        _notifyStatusChange();
        break;

      default:
        print('Unknown method call: ${call.method}');
    }
  }

  // Start background recording
  Future<Map<String, dynamic>> startBackgroundRecording() async {
    if (_isRecording) {
      return {'success': false, 'message': 'Already recording'};
    }

    try {
      final result = await _channel.invokeMethod('startBackgroundRecording');

      if (result is Map<String, dynamic>) {
        final success = result['success'] as bool? ?? false;
        final message = result['message'] as String? ?? 'Unknown error';

        if (success) {
          print('Background recording request sent: $message');
        } else {
          print('Failed to start background recording: $message');
        }

        return {'success': success, 'message': message};
      }

      return {'success': false, 'message': 'Invalid response from native code'};
    } catch (e) {
      print('Error starting background recording: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Stop background recording
  Future<Map<String, dynamic>> stopBackgroundRecording() async {
    if (!_isRecording) {
      return {'success': false, 'message': 'Not recording'};
    }

    try {
      final result = await _channel.invokeMethod('stopBackgroundRecording');

      if (result is Map<String, dynamic>) {
        final success = result['success'] as bool? ?? false;
        final message = result['message'] as String? ?? 'Unknown error';
        final filePath = result['filePath'] as String?;

        if (success) {
          _isRecording = false;
          if (filePath != null) {
            _currentVideoPath = filePath;
            // Save to gallery
            await _saveToGallery(filePath);
          }
          _notifyStatusChange();
          print('Background recording stopped: $filePath');
        } else {
          print('Failed to stop background recording: $message');
        }

        return {'success': success, 'message': message, 'filePath': filePath};
      }

      return {'success': false, 'message': 'Invalid response from native code'};
    } catch (e) {
      print('Error stopping background recording: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Check recording status
  Future<Map<String, dynamic>> getRecordingStatus() async {
    try {
      final result = await _channel.invokeMethod('getRecordingStatus');

      if (result is Map<String, dynamic>) {
        final isRecording = result['isRecording'] as bool? ?? false;
        final filePath = result['filePath'] as String?;

        _isRecording = isRecording;
        _currentVideoPath = filePath;

        return {'isRecording': isRecording, 'filePath': filePath};
      }

      return {'isRecording': false, 'filePath': null};
    } catch (e) {
      print('Error getting recording status: $e');
      return {'isRecording': false, 'filePath': null};
    }
  }

  // Save video to gallery
  Future<void> _saveToGallery(String filePath) async {
    try {
      final hasPerm = await Android14StorageHelper.areStoragePermissionsGranted();
      if (!hasPerm) {
        await Android14StorageHelper.requestStoragePermissions();
      }
      final baseDir = await Android14StorageHelper.getAppStorageDirectory();
      if (baseDir == null) {
        return;
      }
      final dstDir = Directory('$baseDir/dashcam_videos');
      if (!await dstDir.exists()) {
        await dstDir.create(recursive: true);
      }
      final name = 'dashcam_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final destPath = '${dstDir.path}/$name';
      await File(filePath).copy(destPath);
      print('Video saved to storage: $destPath');
    } catch (e) {
      print('Error saving video to storage: $e');
    }
  }

  // Start periodic status check
  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isRecording) return; // Only check when recording

      try {
        final status = await getRecordingStatus();
        if (status['isRecording'] != _isRecording) {
          _isRecording = status['isRecording'] as bool;
          _currentVideoPath = status['filePath'] as String?;
          _notifyStatusChange();
        }
      } catch (e) {
        print('Error checking recording status: $e');
      }
    });
  }

  // Notify status change
  void _notifyStatusChange() {
    _statusController?.add({
      'isRecording': _isRecording,
      'filePath': _currentVideoPath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Dispose resources
  void dispose() {
    _statusTimer?.cancel();
    _statusController?.close();
    _statusController = null;
  }

  // Get formatted duration (placeholder - you might want to track this separately)
  String getFormattedDuration() {
    // This would need to be implemented with a timer tracking elapsed time
    return '00:00';
  }

  // Get remaining time (placeholder)
  String getFormattedRemainingTime() {
    // This would need to be implemented based on your max duration logic
    return '00:00';
  }
}
