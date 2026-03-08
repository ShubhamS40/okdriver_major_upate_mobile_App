import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

// ── Import VoicePreferences from assistant_service ────────────────────────
// This gives us the shared voiceMode setting the user chose in VA screen
import '../../okdriver_virtual_assistant/service/assistant_service.dart'
    show VoiceMode, VoicePreferences;

// ── Server config ─────────────────────────────────────────────────────────
const String _serverWs = 'ws://20.204.177.196:4000/ws/talk';

class AssistantDialog extends StatefulWidget {
  final int drowsyEvents;
  final Function(bool) onDialogClosed;

  const AssistantDialog({
    Key? key,
    required this.drowsyEvents,
    required this.onDialogClosed,
  }) : super(key: key);

  @override
  _AssistantDialogState createState() => _AssistantDialogState();
}

class _AssistantDialogState extends State<AssistantDialog>
    with SingleTickerProviderStateMixin {
  // ── STT ───────────────────────────────────────────────────────
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _hasMicPermission = false;
  String _text = '';

  // ── TTS ───────────────────────────────────────────────────────
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // ── XTTS audio playback (just_audio) ─────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlayingAudio = false;

  // ── WebSocket ─────────────────────────────────────────────────
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  bool _wsConnected = false;

  // ── UI state ──────────────────────────────────────────────────
  String _assistantResponse = 'Driver, are you alright? Please respond.';
  bool _hasResponded = false;
  bool _conversationActive = true;
  bool _isProcessing = false;

  // ── Current voice mode (from global preference) ───────────────
  VoiceMode get _voiceMode => VoicePreferences.voiceMode;

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  Timer? _watchdogTimer;

  // ── Recorder (for XTTS mode — send raw audio to backend) ──────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    _initTts();
    _connectWebSocket();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _conversationActive) _bootSequence();
    });
  }

  @override
  void dispose() {
    _conversationActive = false;
    _watchdogTimer?.cancel();
    _animationController.dispose();
    _flutterTts.stop();
    _speech.stop();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── TTS init ──────────────────────────────────────────────────
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('hi-IN');
    await _flutterTts.setSpeechRate(0.55);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      debugPrint('[DialogTTS] Done');
      if (mounted && _conversationActive) {
        setState(() => _isSpeaking = false);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _conversationActive) _startListeningLoop();
        });
      }
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint('[DialogTTS] Error: $msg');
      if (mounted) setState(() => _isSpeaking = false);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _conversationActive) _startListeningLoop();
      });
    });
  }

  // ── WebSocket connect ─────────────────────────────────────────
  Future<void> _connectWebSocket() async {
    try {
      _wsChannel = IOWebSocketChannel.connect(Uri.parse(_serverWs));
      _wsSub = _wsChannel!.stream.listen(
        _handleWsMessage,
        onError: (e) {
          debugPrint('[DialogWS] Error: $e');
          if (mounted) setState(() => _wsConnected = false);
        },
        onDone: () {
          debugPrint('[DialogWS] Closed');
          if (mounted) setState(() => _wsConnected = false);
        },
        cancelOnError: false,
      );
      setState(() => _wsConnected = true);
      debugPrint('[DialogWS] Connected');
    } catch (e) {
      debugPrint('[DialogWS] Connect failed: $e');
      setState(() => _wsConnected = false);
    }
  }

  // ── Send config to backend ────────────────────────────────────
  void _sendConfig() {
    if (!_wsConnected) return;
    final useXtts = _voiceMode == VoiceMode.xtts;
    try {
      _wsChannel!.sink.add(jsonEncode({
        'type': 'config',
        'generate_tts': useXtts,
      }));
      debugPrint('[DialogWS] Config → generate_tts=$useXtts');
    } catch (e) {
      debugPrint('[DialogWS] Config error: $e');
    }
  }

  // ── Handle WebSocket messages ─────────────────────────────────
  void _handleWsMessage(dynamic rawData) {
    try {
      final msg = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      switch (type) {
        case 'transcript':
          // STT from backend (only in XTTS mode with recorder)
          final t = msg['text'] as String? ?? '';
          if (t.isNotEmpty && mounted) setState(() => _text = t);
          break;

        case 'text_chunk':
          final chunk = msg['text'] as String? ?? '';
          if (mounted) {
            setState(() {
              _assistantResponse = _assistantResponse ==
                      'Driver, are you alright? Please respond.'
                  ? chunk
                  : _assistantResponse + chunk;
            });
          }
          break;

        case 'audio_chunk':
          // XTTS mode: queue and play WAV chunks
          if (_voiceMode == VoiceMode.xtts) {
            final audioB64 = msg['audio'] as String? ?? '';
            if (audioB64.isNotEmpty) {
              _enqueueAudio(base64Decode(audioB64));
            }
          }
          break;

        case 'done':
          final fullText = msg['full_text'] as String? ?? _assistantResponse;
          debugPrint('[DialogWS] Done: $fullText');
          if (mounted) {
            setState(() {
              _assistantResponse = fullText;
              _isProcessing = false;
            });
          }

          // Flutter TTS mode: speak locally
          if (_voiceMode == VoiceMode.flutterTts && fullText.isNotEmpty) {
            _speakFlutter(fullText);
          } else if (_voiceMode == VoiceMode.xtts) {
            // XTTS: wait for audio queue to finish, then resume listening
            _waitForAudioThenListen();
          }
          break;

        case 'status':
          break;

        case 'error':
          final err = msg['msg'] as String? ?? 'Server error';
          debugPrint('[DialogWS] Server error: $err');
          if (mounted) setState(() => _isProcessing = false);
          // Fallback local response
          final fallback = _localSafeResponse(_text);
          _speakFlutter(fallback);
          break;
      }
    } catch (e) {
      debugPrint('[DialogWS] Parse error: $e');
    }
  }

  // ── XTTS audio queue ──────────────────────────────────────────
  void _enqueueAudio(Uint8List bytes) {
    _audioQueue.add(bytes);
    if (!_isPlayingAudio) _playNextChunk();
  }

  Future<void> _playNextChunk() async {
    if (_audioQueue.isEmpty) {
      _isPlayingAudio = false;
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    _isPlayingAudio = true;
    if (mounted) setState(() => _isSpeaking = true);

    final bytes = _audioQueue.removeAt(0);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/dialog_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(bytes);
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
      await _audioPlayer.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed);
      await file.delete();
    } catch (e) {
      debugPrint('[DialogAudio] Error: $e');
    }
    _playNextChunk();
  }

  void _waitForAudioThenListen() {
    // Poll until queue is empty and not playing
    Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!mounted || !_conversationActive) {
        t.cancel();
        return;
      }
      if (_audioQueue.isEmpty && !_isPlayingAudio) {
        t.cancel();
        if (mounted) setState(() => _isSpeaking = false);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _conversationActive) _startListeningLoop();
        });
      }
    });
  }

  // ── Flutter TTS speak ─────────────────────────────────────────
  Future<void> _speakFlutter(String text) async {
    if (!mounted || !_conversationActive) return;
    setState(() => _isSpeaking = true);
    await _flutterTts.stop();
    await _flutterTts.speak(text);
    // completion handler → _startListeningLoop
  }

  // ── Boot sequence ─────────────────────────────────────────────
  Future<void> _bootSequence() async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) micStatus = await Permission.microphone.request();

    if (mounted) setState(() => _hasMicPermission = micStatus.isGranted);

    if (!micStatus.isGranted) {
      setState(() =>
          _assistantResponse = 'Mic permission needed. Use buttons below.');
      return;
    }

    // Speak greeting
    await _speakFlutter(_assistantResponse);
  }

  // ── Send text to backend via WebSocket ────────────────────────
  // We wrap user text as a fake transcript since backend expects audio.
  // For dialog, we use Flutter STT + send text-based query via HTTP fallback
  // OR send as a special text message. Here we use local LLM fallback
  // because dialog's STT is Flutter-side.
  Future<void> _processUserText(String userText) async {
    if (!mounted || _isProcessing) return;
    setState(() {
      _hasResponded = true;
      _isProcessing = true;
      _assistantResponse = '...';
    });

    // Try backend WebSocket text mode first
    if (_wsConnected) {
      try {
        _sendConfig();
        // Send as JSON text message — backend will use Groq for response
        _wsChannel!.sink.add(jsonEncode({
          'type': 'text_query',
          'text': userText,
        }));
        // Response will come via _handleWsMessage → 'done'
        return;
      } catch (e) {
        debugPrint('[DialogWS] text_query send failed: $e');
      }
    }

    // Fallback: local response
    final response = _localSafeResponse(userText);
    if (mounted) {
      setState(() {
        _assistantResponse = response;
        _isProcessing = false;
      });
    }
    await _speakFlutter(response);
  }

  // ── Local fallback responses ──────────────────────────────────
  String _localSafeResponse(String userText) {
    final lower = userText.toLowerCase();
    if (lower.contains('fine') ||
        lower.contains('okay') ||
        lower.contains('ok') ||
        lower.contains('ठीक') ||
        lower.contains('good')) {
      return 'Good to hear! Stay alert and keep your eyes on the road. Drive safe!';
    } else if (lower.contains('help') ||
        lower.contains('tired') ||
        lower.contains('sleepy') ||
        lower.contains('drowsy') ||
        lower.contains('थका')) {
      return 'Please pull over safely. Take a short break and have some water. Your safety matters most.';
    } else if (lower.contains('stop') || lower.contains('close')) {
      return 'Alright, stay focused. Drive safely!';
    }
    return 'Stay alert, driver. Keep your eyes on the road. I am monitoring you.';
  }

  // ── Listening loop ────────────────────────────────────────────
  void _startListeningLoop() {
    if (!mounted || !_conversationActive || _isSpeaking || _isProcessing)
      return;
    if (_isListening || _isRecording) return;
    _listen();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || !_conversationActive || _isSpeaking || _isProcessing)
        return;
      debugPrint('[Watchdog] STT restart');
      _isListening = false;
      _startListeningLoop();
    });
  }

  void _listen() async {
    if (!mounted || !_conversationActive || _isSpeaking || _isProcessing)
      return;
    if (_isListening) return;

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            _watchdogTimer?.cancel();
            if (_conversationActive && !_isSpeaking && !_isProcessing)
              _listen();
          } else if (status == 'listening') {
            setState(() => _isListening = true);
            _startWatchdog();
          }
        },
        onError: (error) {
          debugPrint('[STT] Error: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
          _watchdogTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted &&
                _conversationActive &&
                !_isSpeaking &&
                !_isProcessing) _listen();
          });
        },
      );

      if (!available || !mounted || !_conversationActive) return;
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (val) {
          if (!mounted) return;
          final words = val.recognizedWords.trim();
          if (words.isNotEmpty) setState(() => _text = words);
          if (val.finalResult) {
            _watchdogTimer?.cancel();
            setState(() => _isListening = false);
            _speech.stop();
            if (words.isNotEmpty) {
              _processUserText(words);
            } else if (_conversationActive && !_isSpeaking && !_isProcessing) {
              _listen();
            }
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 6),
        cancelOnError: false,
        localeId: 'hi-IN',
      );
    } catch (e) {
      debugPrint('[STT] Exception: $e');
      if (mounted) setState(() => _isListening = false);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _conversationActive && !_isSpeaking && !_isProcessing)
          _listen();
      });
    }
  }

  void _stopConversation() {
    _conversationActive = false;
    _watchdogTimer?.cancel();
    _speech.stop();
    _flutterTts.stop();
    _audioPlayer.stop();
    _wsSub?.cancel();
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDialogClosed(true);
    }
  }

  void _handleQuickResponse(String response) async {
    setState(() {
      _text = response;
      _hasResponded = true;
    });
    await _processUserText(response);
    Future.delayed(const Duration(seconds: 3), _stopConversation);
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isXtts = _voiceMode == VoiceMode.xtts;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.93),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.red.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          // Voice mode + connection badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                icon: isXtts ? Icons.record_voice_over : Icons.volume_up,
                label: isXtts ? 'Priya XTTS' : 'Fast TTS',
                color: isXtts ? Colors.purple : Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildBadge(
                icon: _wsConnected ? Icons.cloud_done : Icons.cloud_off,
                label: _wsConnected ? 'Online' : 'Offline',
                color: _wsConnected ? Colors.green : Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Animated orb
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _isListening
                            ? Colors.green.shade300
                            : (_isSpeaking
                                ? Colors.purple.shade300
                                : Colors.red.shade400),
                        _isListening
                            ? Colors.green.shade700
                            : (_isSpeaking
                                ? Colors.purple.shade700
                                : Colors.red.shade800),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? Colors.green
                                : (_isSpeaking ? Colors.purple : Colors.red))
                            .withOpacity(0.5),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(60, 60),
                      painter: WaveformPainter(
                        isListening: _isListening,
                        animationValue: _animationController.value,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          Text(
            _isSpeaking
                ? '🔊 Bol rahi hoon...'
                : (_isListening
                    ? '🎤 Sun rahi hoon...'
                    : (_isProcessing
                        ? '⏳ Soch rahi hoon...'
                        : 'Tap mic ya button dabao')),
            style: TextStyle(
              color: _isListening
                  ? Colors.green
                  : (_isSpeaking ? Colors.purple.shade300 : Colors.white60),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _text.isNotEmpty && !_hasResponded
                  ? '"$_text"'
                  : _assistantResponse,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasMicPermission)
                GestureDetector(
                  onTap: _isSpeaking
                      ? null
                      : () {
                          _speech.stop();
                          setState(() => _isListening = false);
                          Future.delayed(
                              const Duration(milliseconds: 200), _listen);
                        },
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.green.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      border: Border.all(
                          color: _isListening ? Colors.green : Colors.white30),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.green : Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              if (!_hasResponded) ...[
                _buildResponseButton('Theek hoon ✓', Colors.green,
                    () => _handleQuickResponse("Main theek hoon")),
                const SizedBox(width: 10),
                _buildResponseButton('Help chahiye', Colors.red,
                    () => _handleQuickResponse("Mujhe help chahiye")),
              ],
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopConversation,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text("Main jaag raha hoon — Close"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildResponseButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

// ── Waveform Painter ──────────────────────────────────────────────────────
class WaveformPainter extends CustomPainter {
  final bool isListening;
  final double animationValue;

  WaveformPainter({required this.isListening, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    isListening
        ? _drawDynamic(canvas, center, radius, paint)
        : _drawStatic(canvas, center, radius, paint);
  }

  void _drawDynamic(Canvas canvas, Offset center, double radius, Paint p) {
    final path = Path();
    final rng = math.Random((animationValue * 10000).toInt());
    const segs = 20;
    for (int i = 0; i <= segs; i++) {
      final angle = i * 2 * math.pi / segs;
      final variance = rng.nextDouble() * 10 + 5;
      final r = radius * (0.6 + variance / 100);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawStatic(Canvas canvas, Offset center, double radius, Paint p) {
    canvas.drawCircle(center, radius * 0.7, p);
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.isListening != isListening || old.animationValue != animationValue;
}
