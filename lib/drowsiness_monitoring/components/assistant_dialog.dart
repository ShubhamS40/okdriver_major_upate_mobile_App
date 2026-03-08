import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';

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
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _hasMicPermission = false;
  bool _isSpeaking = false;
  String _text = "";
  String _assistantResponse = "Driver, are you alright? Please respond.";

  // ✅ FIX 3: Use a DIALOG-LOCAL FlutterTts instance
  //    VoiceAlertService uses its own shared instance which overwrites
  //    completion handlers — using a separate instance isolates us completely
  final FlutterTts _flutterTts = FlutterTts();

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  bool _hasResponded = false;
  bool _conversationActive = true;
  bool _isProcessing = false;

  Timer? _watchdogTimer;

  // ✅ FIX 5: Track whether initial greeting TTS has finished
  bool _greetingDone = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // ✅ FIX 3: Initialize our local TTS with completion/error handlers
    //    These will never be overwritten by VoiceAlertService
    _flutterTts.setLanguage("en-IN");
    _flutterTts.setSpeechRate(0.65);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      debugPrint('[DialogTTS] ✅ Completed — resuming mic');
      if (mounted && _conversationActive) {
        setState(() => _isSpeaking = false);
        // Small delay so audio session fully releases before mic grabs it
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _conversationActive) {
            _startListeningLoop();
          }
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[DialogTTS] Error: $msg');
      if (mounted) setState(() => _isSpeaking = false);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _conversationActive) {
          _startListeningLoop();
        }
      });
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    // ✅ FIX 5: Wait longer before starting mic to let VoiceAlertService TTS
    //    (the "Driver are you alright" from alarm sequence) finish first.
    //    VoiceAlertService plays 2s alarm + 300ms pause + TTS (~3s) = ~5.5s total.
    //    We wait 800ms then start our own greeting TTS, which will play after alarm TTS.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _conversationActive) {
        _checkMicAndStartGreeting();
      }
    });
  }

  @override
  void dispose() {
    _conversationActive = false;
    _watchdogTimer?.cancel();
    _animationController.dispose();
    _flutterTts.stop(); // ✅ Stop our local TTS instance
    _speech.stop();
    super.dispose();
  }

  // ✅ FIX 5: First check mic permission, then speak greeting, then start listening
  Future<void> _checkMicAndStartGreeting() async {
    var micStatus = await Permission.microphone.status;

    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    if (mounted) setState(() => _hasMicPermission = micStatus.isGranted);

    if (!micStatus.isGranted) {
      if (mounted) {
        setState(() {
          _assistantResponse =
              "Mic permission denied. Use buttons below or enable in Settings.";
        });
      }
      return;
    }

    // ✅ Speak the greeting first using our local TTS
    //    After greeting completes, completion handler will call _startListeningLoop
    await _speakGreeting();
  }

  // ✅ FIX 5: Speak greeting via our isolated TTS — mic starts only after this finishes
  Future<void> _speakGreeting() async {
    if (!mounted || !_conversationActive) return;
    setState(() => _isSpeaking = true);
    debugPrint('[DialogTTS] Speaking greeting...');
    await _flutterTts.speak(_assistantResponse);
    // Completion handler will flip _isSpeaking=false and call _startListeningLoop
  }

  // ✅ Watchdog: if mic should be listening but STT silently died, restart it
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_conversationActive || _isSpeaking || _isProcessing)
        return;
      debugPrint('[Watchdog] STT may have died — restarting');
      _isListening = false;
      _startListeningLoop();
    });
  }

  // ✅ Called when user manually taps mic button — force resets everything
  Future<void> _forceRestartListening() async {
    if (!mounted || _isSpeaking) return;

    _watchdogTimer?.cancel();

    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _speech.cancel();
    } catch (_) {}

    if (mounted) setState(() => _isListening = false);

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    if (!mounted) return;
    setState(() => _hasMicPermission = micStatus.isGranted);

    if (micStatus.isGranted) {
      _speech = stt.SpeechToText();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _conversationActive) _listen();
    } else {
      setState(() {
        _assistantResponse = "Mic permission denied. Enable in Settings.";
      });
    }
  }

  // ✅ Central loop: always keeps listening until user speaks or dialog closes
  void _startListeningLoop() {
    if (!mounted || !_conversationActive || _isSpeaking || _isProcessing)
      return;
    if (_isListening) return;
    _listen();
  }

  Future<String> _sendToModel(String query) async {
    try {
      final url = Uri.parse("http://20.204.177.196:5000/api/assistant/chat");
      final body = {
        "message": query,
        "userId": "1",
        "modelProvider": "together",
        "modelName": "meta-llama/Llama-3.2-3B-Instruct-Turbo",
        "speakerId": "1",
        "enablePremium": true
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["response"] ?? "No response from assistant";
      } else {
        return "Server error: ${response.statusCode}";
      }
    } catch (e) {
      return "I'm here to help. Please stay focused on the road.";
    }
  }

  void _listen() async {
    if (!mounted || !_conversationActive || _isSpeaking || _isProcessing)
      return;
    if (_isListening) return;

    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[STT] Status: $status');
          if (!mounted) return;

          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            _watchdogTimer?.cancel();
            if (_conversationActive && !_isSpeaking && !_isProcessing) {
              _listen();
            }
          } else if (status == 'listening') {
            if (mounted) setState(() => _isListening = true);
            _startWatchdog();
          }
        },
        onError: (error) {
          debugPrint('[STT] Error: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
          _watchdogTimer?.cancel();
          if (_conversationActive && !_isSpeaking && !_isProcessing) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted &&
                  _conversationActive &&
                  !_isSpeaking &&
                  !_isProcessing) {
                _listen();
              }
            });
          }
        },
      );

      if (!available || !mounted || !_conversationActive) return;

      setState(() => _isListening = true);

      _speech.listen(
        onResult: (val) {
          if (!mounted) return;

          final words = val.recognizedWords.trim();
          if (words.isNotEmpty) {
            setState(() => _text = words);
          }

          if (val.finalResult) {
            _watchdogTimer?.cancel();
            setState(() => _isListening = false);
            _speech.stop();

            if (words.isNotEmpty) {
              _processResponse(words);
            } else {
              if (_conversationActive && !_isSpeaking && !_isProcessing) {
                _listen();
              }
            }
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[STT] listen error: $e');
      if (mounted) setState(() => _isListening = false);
      if (_conversationActive && !_isSpeaking && !_isProcessing) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted &&
              _conversationActive &&
              !_isSpeaking &&
              !_isProcessing) {
            _listen();
          }
        });
      }
    }
  }

  Future<void> _processResponse(String text) async {
    if (!mounted || _isProcessing) return;

    setState(() {
      _hasResponded = true;
      _isProcessing = true;
    });

    String response = await _sendToModel(text);

    if (mounted) {
      setState(() {
        _assistantResponse = response;
        _isProcessing = false;
        _isSpeaking = true;
      });
    }

    // ✅ Use our local TTS — completion handler will restart mic
    await _flutterTts.speak(response);
    // Completion handler handles mic restart
  }

  Future<void> _speak(String text) async {
    // ✅ Always use our local isolated TTS instance
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _stopConversation() {
    _conversationActive = false;
    _watchdogTimer?.cancel();
    _speech.stop();
    _flutterTts.stop();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDialogClosed(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.92),
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
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Animated orb
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _isListening
                            ? Colors.green.shade300
                            : (_isSpeaking
                                ? Colors.blue.shade300
                                : Colors.red.shade400),
                        _isListening
                            ? Colors.green.shade700
                            : (_isSpeaking
                                ? Colors.blue.shade700
                                : Colors.red.shade800),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? Colors.green
                                : (_isSpeaking ? Colors.blue : Colors.red))
                            .withOpacity(0.5),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(70, 70),
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

          const SizedBox(height: 20),

          // Status text
          Text(
            _isSpeaking
                ? "🔊 Speaking..."
                : (_isListening
                    ? "🎤 Listening..."
                    : (_isProcessing
                        ? "⏳ Thinking..."
                        : (_hasMicPermission
                            ? "Tap mic or use buttons"
                            : "Use buttons below"))),
            style: TextStyle(
              color: _isListening
                  ? Colors.green
                  : (_isSpeaking ? Colors.blue.shade300 : Colors.white60),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          // Assistant response / recognized text
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

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasMicPermission)
                GestureDetector(
                  onTap: _isSpeaking ? null : _forceRestartListening,
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
                        color: _isListening ? Colors.green : Colors.white30,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.green : Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              if (!_hasResponded) ...[
                _buildResponseButton("I'm fine", Colors.green,
                    () => _handleQuickResponse("I'm fine")),
                const SizedBox(width: 10),
                _buildResponseButton("Need help", Colors.red,
                    () => _handleQuickResponse("I need help")),
              ],
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopConversation,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text("I'm Awake — Close"),
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

  void _handleQuickResponse(String response) async {
    setState(() {
      _text = response;
      _hasResponded = true;
    });
    await _processResponse(response);
    _stopConversation();
  }
}

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

    if (isListening) {
      _drawDynamic(canvas, center, radius, paint);
    } else {
      _drawStatic(canvas, center, radius, paint);
    }
  }

  void _drawDynamic(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final random = math.Random((animationValue * 10000).toInt());
    const segments = 20;
    for (int i = 0; i <= segments; i++) {
      final angle = i * 2 * math.pi / segments;
      final variance = random.nextDouble() * 10 + 5;
      final r = radius * (0.6 + variance / 100);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStatic(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius * 0.7, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.isListening != isListening || old.animationValue != animationValue;
}
