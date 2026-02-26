import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// VoiceAlertService — Flutter side
///
/// Alarm is now played natively via Android MediaPlayer (in DrowsinessMonitoringService).
/// This class only handles Flutter-side TTS and coordination.
/// just_audio / ExoPlayer are completely removed — they caused UnrecognizedInputFormatException.
class VoiceAlertService {
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  factory VoiceAlertService() => _instance;
  VoiceAlertService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  DateTime? _lastAlertTime;

  // MethodChannel to trigger native alarm in Android service
  static const _dmsChannel = MethodChannel('com.example.okdriver/drowsiness');

  static const Map<String, String> _alertMessages = {
    'drowsy': 'Driver stay alert! Drowsiness detected!',
    'critical': 'Warning! Critical drowsiness detected! Pull over immediately!',
    'yawning': 'You are yawning. Stay alert and focused.',
    'no_face': 'Face not detected. Please position yourself properly.',
    'check_in': 'Driver, are you alright? Please respond.',
  };

  Future<void> initializeSilent() async {
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() => _isSpeaking = false);
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[TTS] Error: $msg');
      });
      _isInitialized = true;
      debugPrint('[VoiceAlert] ✅ Initialized (native alarm, Flutter TTS)');
    } catch (e) {
      debugPrint('[VoiceAlert] ❌ Init error: $e');
    }
  }

  /// Triggers native alarm (2s) via Android service, then speaks TTS check-in.
  /// The AssistantDialog is now launched natively as BackgroundAssistantActivity —
  /// this method just handles Flutter-foreground TTS portion if needed.
  Future<void> playAlarmThenCheckIn() async {
    if (!_isInitialized) return;

    debugPrint('[VoiceAlert] === playAlarmThenCheckIn START ===');

    // 1. Trigger native alarm play via method channel
    try {
      await _dmsChannel.invokeMethod('playAlarm');
    } catch (e) {
      debugPrint('[VoiceAlert] Native alarm invoke error (non-fatal): $e');
    }

    // 2. Haptic feedback
    await HapticFeedback.heavyImpact();

    // 3. Wait 2s (alarm duration)
    await Future.delayed(const Duration(seconds: 2));

    // 4. Stop native alarm
    try {
      await _dmsChannel.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('[VoiceAlert] Stop alarm error (non-fatal): $e');
    }

    // 5. Short pause
    await Future.delayed(const Duration(milliseconds: 400));

    // 6. TTS check-in
    debugPrint('[VoiceAlert] 🗣 Speaking check-in...');
    await _speakAndWait(_alertMessages['check_in']!);

    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('[VoiceAlert] === playAlarmThenCheckIn DONE ===');
  }

  Future<void> _speakAndWait(String text) async {
    final completer = Completer<void>();

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    });
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    });

    try {
      _isSpeaking = true;
      final result = await _flutterTts.speak(text);
      debugPrint('[TTS] speak() result: $result');
      if (result != 1) {
        _isSpeaking = false;
        if (!completer.isCompleted) completer.complete();
        return;
      }
    } catch (e) {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
      return;
    }

    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _isSpeaking = false;
      },
    );

    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
  }

  Future<void> speak(String message) async {
    if (!_isInitialized || _isSpeaking) return;
    try {
      _isSpeaking = true;
      await _flutterTts.speak(message);
    } catch (e) {
      _isSpeaking = false;
    }
  }

  Future<void> alertDrowsy({bool isCritical = false}) async {
    if (!_isInitialized) return;
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!).inSeconds < 3) return;
    final message =
        isCritical ? _alertMessages['critical']! : _alertMessages['drowsy']!;
    await speak(message);
    _lastAlertTime = DateTime.now();
    HapticFeedback.heavyImpact();
    // Trigger native alarm once
    try {
      await _dmsChannel.invokeMethod('playAlarm');
    } catch (_) {}
  }

  Future<void> alertYawning() async {
    if (!_isInitialized) return;
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!).inSeconds < 5) return;
    await speak(_alertMessages['yawning']!);
    _lastAlertTime = DateTime.now();
    HapticFeedback.lightImpact();
  }

  Future<void> alertNoFace() async {
    if (!_isInitialized) return;
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!).inSeconds < 10) return;
    await speak(_alertMessages['no_face']!);
    _lastAlertTime = DateTime.now();
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      await stopBeep();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }

  Future<void> stopBeep() async {
    try {
      await _dmsChannel.invokeMethod('stopAlarm');
    } catch (_) {}
  }

  /// startBipLoop: triggers native alarm through the service
  void startBipLoop() {
    if (!_isInitialized) return;
    try {
      _dmsChannel.invokeMethod('playAlarm');
    } catch (_) {}
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;
}
