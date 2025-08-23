import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
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
  String _text = "";
  String _assistantResponse = "";
  FlutterTts _flutterTts = FlutterTts();

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // State variables
  bool _hasResponded = false;
  bool _initialPromptSpoken = false;
  bool _conversationActive = true; // ✅ conversation loop control

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // ✅ TTS complete hone ke baad auto listen
    _flutterTts.setCompletionHandler(() {
      if (mounted && _conversationActive) {
        _listen();
      }
    });

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.repeat(reverse: true);

    // Speak initial prompt after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _speakInitialPrompt();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _speakInitialPrompt() async {
    const initialPrompt = "Driver, are you alright? Please respond.";
    await _speak(initialPrompt);
    setState(() {
      _assistantResponse = initialPrompt;
      _initialPromptSpoken = true;
    });
  }

  /// API call to your backend
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
    if (!_isListening && _conversationActive) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _text = val.recognizedWords;
            });

            // ✅ Jab user bolna khatam kare
            if (val.finalResult) {
              setState(() => _isListening = false);
              _speech.stop();

              if (_text.isNotEmpty) {
                _processResponse(_text);
              }
            }
          },
        );
      }
    }
  }

  Future<void> _processResponse(String text) async {
    setState(() {
      _hasResponded = true;
    });

    String response = await _sendToModel(text);
    setState(() {
      _assistantResponse = response;
    });
    await _speak(response);

    // ⚡ Ab TTS complete hone ke baad auto _listen() trigger hoga
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop(); // पहले का बोलना बंद करो

    await _flutterTts.setLanguage("en-IN"); // Hinglish accent
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.65);
    await _flutterTts.setVolume(1.0);

    await _flutterTts.speak(text);
  }

  void _stopConversation() {
    setState(() {
      _conversationActive = false;
    });
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
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated circle
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.blue.shade700,
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildAnimatedWaveform(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          // Text display (minimal, no chat history)
          Text(
            _isListening
                ? "Listening..."
                : (_text.isNotEmpty
                    ? "Processing..."
                    : (_initialPromptSpoken ? "Tap to respond" : "")),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          // Response buttons
          if (_initialPromptSpoken && !_hasResponded)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildResponseButton(
                  "I'm fine",
                  Colors.green,
                  () => _handleQuickResponse("I'm fine"),
                ),
                const SizedBox(width: 16),
                _buildResponseButton(
                  "Need help",
                  Colors.red,
                  () => _handleQuickResponse("I need help"),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // ✅ Stop Conversation button
          ElevatedButton(
            onPressed: _stopConversation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text("Stop Conversation"),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWaveform() {
    return CustomPaint(
      size: const Size(80, 80),
      painter: WaveformPainter(
        isListening: _isListening,
        animationValue: _animationController.value,
      ),
    );
  }

  Widget _buildResponseButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _handleQuickResponse(String response) async {
    setState(() {
      _text = response;
      _hasResponded = true;
    });

    // Process the response
    await _processResponse(response);
    _stopConversation(); // ✅ quick reply ke baad dialog close
  }
}

class WaveformPainter extends CustomPainter {
  final bool isListening;
  final double animationValue;

  WaveformPainter({
    required this.isListening,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (isListening) {
      _drawDynamicWaveform(canvas, center, radius, paint);
    } else {
      _drawStaticWaveform(canvas, center, radius, paint);
    }
  }

  void _drawDynamicWaveform(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final random = math.Random(animationValue.toInt() * 10000);

    const segments = 20;
    const angleStep = 2 * math.pi / segments;

    for (int i = 0; i <= segments; i++) {
      final angle = i * angleStep;
      final variance = random.nextDouble() * 10 + 5;
      final dynamicRadius = radius * (0.6 + (variance / 100));

      final x = center.dx + dynamicRadius * math.cos(angle);
      final y = center.dy + dynamicRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStaticWaveform(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();

    const segments = 20;
    const angleStep = 2 * math.pi / segments;

    for (int i = 0; i <= segments; i++) {
      final angle = i * angleStep;
      final staticRadius = radius * 0.7;

      final x = center.dx + staticRadius * math.cos(angle);
      final y = center.dy + staticRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.isListening != isListening ||
        oldDelegate.animationValue != animationValue;
  }
}
