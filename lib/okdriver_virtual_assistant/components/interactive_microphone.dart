import 'package:flutter/material.dart';
import 'wave_animation.dart';
import 'glass_conatiner.dart' as glass;

class InteractiveMicrophone extends StatelessWidget {
  final bool isListening;
  final bool isWakeListening;
  final VoidCallback onTap;

  const InteractiveMicrophone({
    Key? key,
    required this.isListening,
    required this.isWakeListening,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated wave when listening with glass effect
        if (isListening || isWakeListening)
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isWakeListening
                      ? Colors.orange.withOpacity(0.2)
                      : const Color(0xFF9C27B0).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: glass.GlassContainer(
                color: Colors.black,
                opacity: 0.1,
                blur: 8.0,
                child: Center(
                  child: WaveAnimation(
                    isActive: true,
                    color: isWakeListening
                        ? Colors.orange.withOpacity(0.7)
                        : const Color(0xFF9C27B0).withOpacity(0.7),
                    size: 120,
                    strokeWidth: 2.0,
                    numberOfWaves: 3,
                  ),
                ),
              ),
            ),
          ),

        // Microphone button with glass effect
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isListening
                    ? [
                        const Color(0xFF9C27B0),
                        const Color(0xFF7B1FA2),
                      ]
                    : (isWakeListening
                        ? [
                            Colors.orange,
                            Colors.deepOrange,
                          ]
                        : [
                            const Color(0xFF9C27B0).withOpacity(0.8),
                            const Color(0xFF7B1FA2),
                          ]),
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isListening
                      ? const Color(0xFF9C27B0).withOpacity(0.5)
                      : (isWakeListening
                          ? Colors.orange.withOpacity(0.5)
                          : const Color(0xFF9C27B0).withOpacity(0.3)),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isListening || isWakeListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final bool isListening;
  final bool isProcessing;
  final bool isSpeaking;
  final bool isDarkMode;

  const StatusIndicator({
    Key? key,
    required this.isListening,
    required this.isProcessing,
    required this.isSpeaking,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String statusText = 'Tap mic to start';
    Color statusColor = const Color(0xFF9C27B0);
    bool showWaveform = false;

    if (isListening) {
      statusText = 'Listening...';
      statusColor = Colors.blue;
      showWaveform = true;
    } else if (isProcessing) {
      statusText = 'Processing...';
      statusColor = Colors.orange;
      showWaveform = false;
    } else if (isSpeaking) {
      statusText = 'Speaking...';
      statusColor = Colors.green;
      showWaveform = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          statusText,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (showWaveform)
          VoiceWaveform(
            isActive: true,
            color: statusColor,
            height: 30,
            barCount: 9,
          ),
      ],
    );
  }
}
