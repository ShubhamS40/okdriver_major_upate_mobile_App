import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class VoiceAlertService {
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  factory VoiceAlertService() => _instance;
  VoiceAlertService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Timer? _cooldownTimer;
  DateTime? _lastAlertTime;

  // Alert messages
  static const Map<String, String> _alertMessages = {
    'drowsy': 'Driver stay alert! Drowsiness detected!',
    'critical': 'Warning! Critical drowsiness detected! Pull over immediately!',
    'yawning': 'You are yawning. Stay alert and focused.',
    'no_face': 'Face not detected. Please position yourself properly.',
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _isInitialized = true;
      print('Voice Alert Service initialized successfully');
    } catch (e) {
      print('Error initializing Voice Alert Service: $e');
    }
  }

  Future<void> speak(String message) async {
    if (!_isInitialized || _isSpeaking) return;

    try {
      _isSpeaking = true;
      await _flutterTts.speak(message);
    } catch (e) {
      print('Error speaking message: $e');
      _isSpeaking = false;
    }
  }

  Future<void> alertDrowsy({bool isCritical = false}) async {
    if (!_isInitialized) return;

    // Check cooldown to prevent spam
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
      if (timeSinceLastAlert.inSeconds < 3) return; // 3 second cooldown
    }

    final message =
        isCritical ? _alertMessages['critical']! : _alertMessages['drowsy']!;

    await speak(message);
    _lastAlertTime = DateTime.now();

    // Haptic feedback
    HapticFeedback.heavyImpact();
  }

  Future<void> alertYawning() async {
    if (!_isInitialized) return;

    // Check cooldown
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
      if (timeSinceLastAlert.inSeconds < 5)
        return; // 5 second cooldown for yawning
    }

    await speak(_alertMessages['yawning']!);
    _lastAlertTime = DateTime.now();

    // Light haptic feedback
    HapticFeedback.lightImpact();
  }

  Future<void> alertNoFace() async {
    if (!_isInitialized) return;

    // Check cooldown
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
      if (timeSinceLastAlert.inSeconds < 10)
        return; // 10 second cooldown for no face
    }

    await speak(_alertMessages['no_face']!);
    _lastAlertTime = DateTime.now();
  }

  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  Future<void> dispose() async {
    _cooldownTimer?.cancel();
    await stop();
    _isInitialized = false;
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;
}
