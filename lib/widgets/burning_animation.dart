import 'dart:math';
import 'package:flutter/material.dart';

class BurningAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final String text;

  const BurningAnimation({
    super.key,
    required this.onComplete,
    required this.text,
  });

  @override
  State<BurningAnimation> createState() => _BurningAnimationState();
}

class _BurningAnimationState extends State<BurningAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<_FireParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInQuad),
    );

    _controller.addListener(() {
      if (_controller.value > 0.1 && _controller.value < 0.9) {
        // Generate new particles aggressively during burning phase
        for (int i = 0; i < 5; i++) {
          _particles.add(_FireParticle());
        }
      }

      // Update particles
      for (var particle in _particles) {
        particle.update();
      }
      _particles.removeWhere((p) => p.isDead);

      setState(() {});
    });

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark overlay background
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              color: Colors.black
                  .withOpacity((_animation.value * 0.9).clamp(0.0, 0.9)),
            );
          },
        ),

        // Burning Paper Content
        Center(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  // Create a gradient that moves up to simulate burning
                  return LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [
                      _animation.value - 0.2, // Ash/Burnt part
                      _animation.value, // Burning edge
                      _animation.value + 0.1, // Intact paper
                    ],
                    colors: const [
                      Colors.transparent, // Already burnt (transparent)
                      Color(0xFF8B0000), // Burning edge (Dark Red)
                      Colors.white, // Intact paper
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.modulate,
                child: Container(
                  width: 300,
                  constraints: const BoxConstraints(minHeight: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(2), // Paper-like sharp corners
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.text.isEmpty ? "..." : widget.text,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          height: 1.6,
                          fontFamily: 'Courier', // Typewriter feel
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Fire & Ash Particles
        Positioned.fill(
          child: CustomPaint(
            painter: _FireParticlePainter(_particles),
          ),
        ),

        // Overlay intense fire effect at the burning line
        Center(
          child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final burnProgress = _animation.value;
                if (burnProgress <= 0.05 || burnProgress >= 0.95)
                  return const SizedBox.shrink();

                // Calculate approximate Y position of the burning line relative to center
                // This is a rough estimation; for precise positioning, we'd need RenderBox
                // 200 is roughly half the paper height
                final double yOffset = 200 - (400 * burnProgress);

                return Transform.translate(
                  offset: Offset(0, yOffset),
                  child: Container(
                    width: 320,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.orange.withOpacity(0.8),
                          Colors.red.withOpacity(0.5),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.5, 1.0],
                        radius: 2.0,
                      ),
                    ),
                    child: const SizedBox(),
                  ),
                );
              }),
        )
      ],
    );
  }
}

class _FireParticle {
  late double x;
  late double y;
  late double size;
  late double speedY;
  late double speedX;
  late double life; // 1.0 to 0.0
  late Color color;
  final Random _random = Random();

  _FireParticle() {
    // Spawn particles from bottom area mostly
    x = _random.nextDouble() * 400 -
        200; // Spread horizontally relative to center
    y = _random.nextDouble() * 100 +
        150; // Start near bottom relative to center
    size = _random.nextDouble() * 30 + 10;
    speedY = _random.nextDouble() * 5 + 2; // Rise up
    speedX = (_random.nextDouble() - 0.5) * 2; // Slight drift
    life = 1.0;

    // Randomize colors: Orange, Red, Yellow, Dark Grey (Ash)
    int colorType = _random.nextInt(10);
    if (colorType < 2) {
      color = Colors.grey.withOpacity(0.6); // Ash
    } else if (colorType < 5) {
      color = Colors.redAccent;
    } else if (colorType < 8) {
      color = Colors.orange;
    } else {
      color = Colors.yellowAccent;
    }
  }

  void update() {
    y -= speedY;
    x += speedX + (sin(y * 0.05) * 0.5); // Add wave motion
    life -= 0.02;
    size *= 0.96; // Shrink over time
  }

  bool get isDead => life <= 0;
}

class _FireParticlePainter extends CustomPainter {
  final List<_FireParticle> particles;

  _FireParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3); // Soft glow

      canvas.drawCircle(
        Offset(center.dx + particle.x, center.dy + particle.y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireParticlePainter oldDelegate) => true;
}
