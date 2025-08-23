import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class WaveAnimation extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double size;
  final double strokeWidth;
  final int numberOfWaves;
  final Duration waveDuration;

  const WaveAnimation({
    Key? key,
    required this.isActive,
    required this.color,
    this.size = 150.0,
    this.strokeWidth = 3.0,
    this.numberOfWaves = 5,
    this.waveDuration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.numberOfWaves,
      (index) => AnimationController(
        vsync: this,
        duration: widget.waveDuration,
      ),
    );

    _animations = List.generate(
      widget.numberOfWaves,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controllers[index],
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Stagger the animations
    for (int i = 0; i < widget.numberOfWaves; i++) {
      Future.delayed(Duration(milliseconds: (i * 100)), () {
        if (mounted) {
          _controllers[i].repeat();
        }
      });
    }
  }

  @override
  void didUpdateWidget(WaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        for (var controller in _controllers) {
          controller.repeat();
        }
      } else {
        for (var controller in _controllers) {
          controller.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle
          Container(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),

          // Animated waves
          if (widget.isActive)
            ...List.generate(
              widget.numberOfWaves,
              (index) => AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: WavePainter(
                      progress: _animations[index].value,
                      color: widget.color.withOpacity(
                        (1.0 - _animations[index].value) * 0.7,
                      ),
                      strokeWidth: widget.strokeWidth,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  WavePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * progress;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// Voice Waveform Animation
class VoiceWaveform extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double height;
  final int barCount;

  const VoiceWaveform({
    Key? key,
    required this.isActive,
    required this.color,
    this.height = 50.0,
    this.barCount = 7,
  }) : super(key: key);

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + _random.nextInt(400)),
      ),
    );

    _animations = List.generate(
      widget.barCount,
      (index) => Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(
          parent: _controllers[index],
          curve: Curves.easeInOut,
        ),
      ),
    );

    if (widget.isActive) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    for (int i = 0; i < widget.barCount; i++) {
      _controllers[i].repeat(reverse: true);
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
    }
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.barCount,
          (index) => AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: widget.height * _animations[index].value,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Glass Container for a glossy finish
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color color;
  final double blur;
  final double opacity;

  const GlassContainer({
    Key? key,
    required this.child,
    this.borderRadius = 20.0,
    this.color = Colors.white,
    this.blur = 10.0,
    this.opacity = 0.2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
