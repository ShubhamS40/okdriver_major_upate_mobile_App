import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:okdriver/utlis/android14_storage_helper.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
      print('Already recording, skipping start');
      return;
    }

    try {
      // Start the native Android camera recording
      final result = await _channel.invokeMethod('startBackgroundRecording');
      print('Native recording result: $result');

      if (result is Map && result['success'] == true) {
        _isRecording = true;
        _currentVideoPath = result['filePath'] as String?;
        _elapsedSeconds = 0;
        _isServiceRunning = true;

        // Start duration timer
        _startDurationTimer();

        // Set up automatic stop
        _setupAutomaticStop();

        print('Background recording started successfully');
      } else {
        throw Exception('Failed to start native recording: $result');
      }
    } catch (e) {
      print('Error starting background recording: $e');
      throw Exception('Failed to start background recording: $e');
    }
  }

  // Stop background recording
  Future<void> stopBackgroundRecording() async {
    if (!_isRecording) return;

    try {
      // Stop the native Android camera recording
      final result = await _channel.invokeMethod('stopBackgroundRecording');
      print('Native recording stop result: $result');

      _isRecording = false;
      _autoStopTimer?.cancel();
      _durationTimer?.cancel();
      _elapsedSeconds = 0;

      if (result is Map && result['filePath'] != null) {
        _currentVideoPath = result['filePath'] as String?;

        // Save to gallery if we have a video file
        if (_currentVideoPath != null) {
          try {
            await _saveVideoToGallery(_currentVideoPath!);
            print('Video saved to gallery: $_currentVideoPath');
          } catch (e) {
            print('Error saving to gallery: $e');
          }
        }
      }

      print('Background recording stopped successfully');
    } catch (e) {
      print('Error stopping background recording: $e');
      // Reset state even if there's an error
      _isRecording = false;
      _autoStopTimer?.cancel();
      _durationTimer?.cancel();
      _elapsedSeconds = 0;
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

  // Save video to gallery
  Future<void> _saveVideoToGallery(String videoPath) async {
    try {
      // Use the storage helper to get the appropriate directory
      final storageDir = await Android14StorageHelper.getAppStorageDirectory();

      final result = await ImageGallerySaver.saveFile(
        videoPath,
        name: 'dashcam_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      if (result['isSuccess'] == true) {
        print('Video saved to gallery successfully');
      } else {
        print('Failed to save video to gallery: $result');
      }
    } catch (e) {
      print('Error saving video to gallery: $e');
      throw e;
    }
  }

  // Dispose resources
  void dispose() {
    if (_isRecording) {
      stopBackgroundRecording();
    }
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
