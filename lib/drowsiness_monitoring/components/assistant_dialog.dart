import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:math' as math;

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
  bool _hasMicPermission = false; // ✅ Track mic permission
  String _text = "";
  String _assistantResponse = "Driver, are you alright? Please respond.";
  final FlutterTts _flutterTts = FlutterTts();

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  bool _hasResponded = false;
  bool _conversationActive = true;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    _flutterTts.setCompletionHandler(() {
      if (mounted && _conversationActive) {
        _listen(); // Auto-listen after TTS
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    // ✅ Check mic permission then start listening
    // The TTS "Driver are you alright?" was already spoken BEFORE dialog opened
    // So dialog should immediately start listening
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _checkMicAndListen();
    });
  }

  @override
  void dispose() {
    _conversationActive = false;
    _animationController.dispose();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  // ✅ Check mic permission first, then listen
  Future<void> _checkMicAndListen() async {
    // Check current permission status
    var micStatus = await Permission.microphone.status;

    if (micStatus.isGranted) {
      _hasMicPermission = true;
      _listen();
    } else if (micStatus.isDenied) {
      // Request it
      micStatus = await Permission.microphone.request();
      if (mounted) setState(() => _hasMicPermission = micStatus.isGranted);
      if (micStatus.isGranted) {
        _listen();
      } else {
        // Show message — user must tap buttons instead
        if (mounted) {
          setState(() {
            _assistantResponse =
                "Microphone not available. Please use the buttons below.";
          });
        }
      }
    } else if (micStatus.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _hasMicPermission = false;
          _assistantResponse =
              "Mic permission denied. Use buttons below or enable in Settings.";
        });
      }
    }
  }

  Future<String> _sendToModel(String query) async {
    try {
      final url = Uri.parse("http://20.204.177.196:5000/api/assistant/chat");
      final body = {
        "message": query,
        "userId": "1",
        "modelProvider": "together",
        "modelName": "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
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
      return "Error: $e";
    }
  }

  void _listen() async {
    if (!_isListening && _conversationActive && mounted && _hasMicPermission) {
      try {
        bool available = await _speech.initialize(
          onError: (error) {
            debugPrint('[STT] Error: ${error.errorMsg}');
            if (mounted) setState(() => _isListening = false);
          },
        );

        if (available && mounted && _conversationActive) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) {
              if (mounted) {
                setState(() => _text = val.recognizedWords);
              }
              if (val.finalResult) {
                if (mounted) setState(() => _isListening = false);
                _speech.stop();
                if (_text.isNotEmpty) _processResponse(_text);
              }
            },
            listenFor: const Duration(seconds: 15),
            pauseFor: const Duration(seconds: 3),
          );
        }
      } catch (e) {
        debugPrint('[STT] listen error: $e');
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  Future<void> _processResponse(String text) async {
    if (!mounted) return;
    setState(() => _hasResponded = true);

    String response = await _sendToModel(text);
    if (mounted) setState(() => _assistantResponse = response);
    await _speak(response);
    // TTS completion handler auto-calls _listen() again
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.65);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.speak(text);
  }

  void _stopConversation() {
    _conversationActive = false;
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
                            : Colors.red.shade400,
                        _isListening
                            ? Colors.green.shade700
                            : Colors.red.shade800,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.green : Colors.red)
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
            _isListening
                ? "🎤 Listening..."
                : (_hasMicPermission
                    ? "Tap mic or use buttons"
                    : "Use buttons below"),
            style: TextStyle(
              color: _isListening ? Colors.green : Colors.white60,
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

          // ✅ Mic button (if permission available) + quick response buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mic button
              if (_hasMicPermission)
                GestureDetector(
                  onTap: _isListening ? null : _listen,
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

              // Quick response buttons
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

          // Stop button
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
