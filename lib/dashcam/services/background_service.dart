import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/utlis/android14_storage_helper.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:okdriver/utils/android14_storage_helper.dart';

class DashcamBackgroundService {
  static final DashcamBackgroundService _instance =
      DashcamBackgroundService._internal();
  factory DashcamBackgroundService() => _instance;
  DashcamBackgroundService._internal();

  // Native method channel for Android camera service
  static const MethodChannel _channel =
      MethodChannel('com.example.okdriver/background_recording');

  // Recording state
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  String? _currentVideoPath;
  int _maxRecordingDurationSeconds = 15 * 60; // Default 15 minutes
  Timer? _autoStopTimer;
  Timer? _durationTimer;

  // Background service
  FlutterBackgroundService? _backgroundService;
  bool _isServiceRunning = false;

  // Getters
  bool get isRecording => _isRecording;
  int get elapsedSeconds => _elapsedSeconds;
  String? get currentVideoPath => _currentVideoPath;
  bool get isServiceRunning => _isServiceRunning;

  // Initialize the background service
  Future<void> initialize({
    CameraController? cameraController,
    int maxRecordingDurationMinutes = 15,
  }) async {
    _maxRecordingDurationSeconds = maxRecordingDurationMinutes * 60;

    try {
      // Initialize the native Android camera service
      final result =
          await _channel.invokeMethod('initializeBackgroundRecording');
      print('Native camera service initialized: $result');

      // Initialize the background service
      await initializeService();

      print('Background service initialized successfully');
    } catch (e) {
      print('Error initializing background service: $e');
      throw Exception('Failed to initialize background service: $e');
    }
  }

  // Initialize the Flutter background service
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure notification settings
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'dashcam_recording_channel',
      'Dashcam Recording',
      description: 'Shows dashcam recording status',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'dashcam_recording_channel',
        initialNotificationTitle: 'Dashcam Service',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: 1001,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _backgroundService = service;
  }

  // Start background recording
  Future<void> startBackgroundRecording() async {
    if (_isRecording) {
      print('Background recording already in progress');
      return;
    }

    try {
      // Start the native Android camera service
      final result = await _channel.invokeMethod('startBackgroundRecording');
      String? startedPath;
      if (result is Map && result['success'] == true) {
        startedPath = result['filePath'] as String?;
      } else if (result is String) {
        startedPath = result;
      }
      print('Native background recording start result: $result');
      _currentVideoPath = startedPath;

      // Start the background service
      final service = FlutterBackgroundService();
      await service.startService();
      _backgroundService = service;
      _isServiceRunning = true;

      // Start timers
      _startRecordingTimers();

      _isRecording = true;
      print('Background recording started successfully');
    } catch (e) {
      print('Error starting background recording: $e');
      throw Exception('Failed to start background recording: $e');
    }
  }

  // Save video to gallery
  Future<bool> saveVideoToGallery(String videoPath) async {
    try {
      final hasPerm =
          await Android14StorageHelper.areStoragePermissionsGranted();
      if (!hasPerm) {
        await Android14StorageHelper.requestStoragePermissions();
      }
      final baseDir = await Android14StorageHelper.getAppStorageDirectory();
      if (baseDir == null) {
        return false;
      }
      final dstDir = Directory('$baseDir/dashcam_videos');
      if (!await dstDir.exists()) {
        await dstDir.create(recursive: true);
      }
      final fileName = 'dashcam_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final destPath = '${dstDir.path}/$fileName';
      await File(videoPath).copy(destPath);
      print('Video saved to storage: $destPath');
      return true;
    } catch (e) {
      print('Error saving video to storage: $e');
      return false;
    }
  }

  // Stop background recording
  Future<String?> stopBackgroundRecording() async {
    if (!_isRecording) {
      print('Not recording, skipping stop');
      return null;
    }

    try {
      // Stop the native Android camera recording
      final result = await _channel.invokeMethod('stopBackgroundRecording');
      print('Native stop recording result: $result');

      // Stop timers
      _stopRecordingTimers();

      // Update state
      _isRecording = false;
      _elapsedSeconds = 0;

      // Stop the background service
      // if (_backgroundService != null && _isServiceRunning) {
      //   await _backgroundService!.invoke('stopService');
      //   _isServiceRunning = false;
      // }

      // Return the path to the recorded video
      if (result is Map && result['success'] == true) {
        _currentVideoPath = result['filePath'] as String?;

        // Automatically save to gallery
        if (_currentVideoPath != null) {
          await saveVideoToGallery(_currentVideoPath!);
        }

        return _currentVideoPath;
      } else {
        return null;
      }
    } catch (e) {
      print('Error stopping background recording: $e');
      return null;
    }
  }

  // Stop the background service completely
  Future<void> stopService() async {
    if (_isRecording) {
      await stopBackgroundRecording();
    }

    try {
      _backgroundService?.invoke('stopService');
      _isServiceRunning = false;
    } catch (e) {
      print('Error stopping background service: $e');
      // Reset state even if there's an error
      _isServiceRunning = false;
    }
  }

  // Start duration timer
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording) {
        _elapsedSeconds++;

        // Update notification with current duration
        if (_backgroundService != null) {
          final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

          _backgroundService!.invoke('updateNotification', {
            'title': 'Dashcam Recording',
            'content': 'Recording in background: $minutes:$seconds',
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Set up automatic stop based on max duration
  void _setupAutomaticStop() {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(Duration(seconds: _maxRecordingDurationSeconds), () {
      if (_isRecording) {
        stopBackgroundRecording();
      }
    });
  }

  // Get formatted duration
  String getFormattedDuration() {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Get remaining time in seconds
  int get remainingSeconds => _maxRecordingDurationSeconds - _elapsedSeconds;

  // Get formatted remaining time
  String getFormattedRemainingTime() {
    final remaining = remainingSeconds;
    if (remaining <= 0) return '00:00';

    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Start both recording timers
  void _startRecordingTimers() {
    _startDurationTimer();
    _setupAutomaticStop();
  }

  // Stop both recording timers
  void _stopRecordingTimers() {
    _autoStopTimer?.cancel();
    _durationTimer?.cancel();
  }

  // Save video to gallery
  Future<void> _saveVideoToGallery(String videoPath) async {
    try {
      final hasPerm =
          await Android14StorageHelper.areStoragePermissionsGranted();
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
      final fileName = 'dashcam_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final destPath = '${dstDir.path}/$fileName';
      await File(videoPath).copy(destPath);
      print('Video saved to storage: $destPath');
    } catch (e) {
      print('Error saving video to storage: $e');
      throw e;
    }
  }

  // Dispose resources
  void dispose() {
    _autoStopTimer?.cancel();
    _durationTimer?.cancel();
    _autoStopTimer = null;
    _durationTimer = null;
  }
}

// Background service callbacks
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // This is called when the background service starts
  print('Background service started');

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Handle service events
  service.on('updateNotification').listen((event) async {
    if (event != null) {
      final title = event['title'] as String? ?? 'Dashcam Recording';
      final content =
          event['content'] as String? ?? 'Recording in background...';

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
