import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class VoiceAlertService {
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  factory VoiceAlertService() => _instance;
  VoiceAlertService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Timer? _cooldownTimer;
  DateTime? _lastAlertTime;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _beepTimer;
  bool _isBeeping = false;

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

      // Preload alarm asset for minimal latency
      try {
        await _audioPlayer.setAudioSource(
          AudioSource.asset('DMS_mobile/alarm.wav'),
        );
      } catch (e) {
        // ignore
      }

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

    // Play alarm once on drowsy event (continuous beeping controlled externally)
    await _playAlarmOnce();
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

    // Optional: single cue beep for yawning (disabled as per request)
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

    // Optional: single cue beep for no face (disabled)
  }

  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      await stopBeep();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  Future<void> dispose() async {
    _cooldownTimer?.cancel();
    await stop();
    try {
      await _audioPlayer.dispose();
    } catch (_) {}
    _isInitialized = false;
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  void _startBeepForTenSeconds() {
    // Deprecated: timer-based beeps removed
  }

  Future<void> _playAlarmOnce() async {
    try {
      if (_audioPlayer.audioSource == null) {
        await _audioPlayer.setAudioSource(
          AudioSource.asset('DMS_mobile/alarm.wav'),
        );
      }
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (_) {
      // ignore
    }
  }

  Future<void> stopBeep() async {
    _beepTimer?.cancel();
    _isBeeping = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void startBipLoop() {
    if (!_isInitialized) return;
    if (_isBeeping) return;
    _isBeeping = true;
    _beepTimer?.cancel();
    _beepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // ignore: avoid_print
      print('bip bip');
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      await _playAlarmOnce();
    });
  }
}
