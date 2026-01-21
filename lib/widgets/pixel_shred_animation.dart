import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:audioplayers/audioplayers.dart';

class PixelShredAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;
  final Duration delay;

  const PixelShredAnimation({
    super.key,
    required this.child,
    required this.onComplete,
    this.delay = const Duration(seconds: 1),
  });

  @override
  State<PixelShredAnimation> createState() => _PixelShredAnimationState();
}

class _PixelShredAnimationState extends State<PixelShredAnimation>
    with SingleTickerProviderStateMixin {
  final GlobalKey _globalKey = GlobalKey();
  late AnimationController _controller;
  List<_Particle> _particles = [];
  bool _showParticles = false;
  ui.Image? _capturedImage;
  late AudioPlayer _sfxPlayer;

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addListener(() {
      setState(() {
        for (var p in _particles) {
          p.update();
        }
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    // Start capture after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureAndStart();
    });
  }

  Future<void> _captureAndStart() async {
    try {
      // Small delay to ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return;

      // Capture image
      final image = await boundary.toImage(pixelRatio: 1.0);
      _capturedImage = image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) return;

      _generateParticles(byteData, image.width, image.height);

      setState(() {
        // _showParticles is still false here, so we continue showing the sharp child
      });

      // 사용자 설정 지연 (선명한상태 유지)
      await Future.delayed(widget.delay);

      setState(() {
        _showParticles = true; // Switch to pixelated particles
      });

      // Play Shred SFX
      try {
        await _sfxPlayer.play(AssetSource('sounds/pixel_shred.mp3'));
      } catch (e) {
        // debugPrint('Shred SFX failed: $e');
      }

      _controller.forward();
    } catch (e) {
      debugPrint('Capture failed: $e');
      widget.onComplete();
    }
  }

  void _generateParticles(ByteData bytes, int width, int height) {
    const int step = 8; // Larger particles (8x8)
    final Random random = Random();

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        final int offset = (y * width + x) * 4;

        if (offset + 3 >= bytes.lengthInBytes) continue;

        final int r = bytes.getUint8(offset);
        final int g = bytes.getUint8(offset + 1);
        final int b = bytes.getUint8(offset + 2);
        final int a = bytes.getUint8(offset + 3);

        if (a == 0) continue;

        _particles.add(_Particle(
          x: x.toDouble(),
          y: y.toDouble(),
          color: Color.fromARGB(a, r, g, b),
          random: random,
        ));
      }
    }
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show original child while capturing OR while waiting (delay)
    if (!_showParticles) {
      return RepaintBoundary(
        key: _globalKey,
        child: widget.child,
      );
    }

    // After delay, show particles (explosion)
    return CustomPaint(
      size: Size(
        _capturedImage!.width.toDouble(),
        _capturedImage!.height.toDouble(),
      ),
      painter: _PixelShredPainter(_particles),
    );
  }
}

class _Particle {
  double x;
  double y;
  final Color color;
  double vx;
  double vy;
  double life = 1.0;

  _Particle({
    required this.x,
    required this.y,
    required this.color,
    required Random random,
  })  : vx = (random.nextDouble() - 0.5) * 40, // Much wider spread
        vy = (random.nextDouble() * -20) - 5; // Stronger upward explosion

  void update() {
    x += vx;
    y += vy;

    vy += 0.5; // Stronger gravity
    vx *= 0.95; // Air resistance

    // More random turbulence
    if (Random().nextDouble() > 0.5) {
      vx += (Random().nextDouble() - 0.5) * 4;
    }

    life -=
        0.005 + (Random().nextDouble() * 0.01); // Slower fade for longer effect
  }
}

class _PixelShredPainter extends CustomPainter {
  final List<_Particle> particles;

  _PixelShredPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;

    for (var p in particles) {
      if (p.life <= 0) continue;

      paint.color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      // Draw larger rects (8x8)
      canvas.drawRect(
        Rect.fromLTWH(p.x, p.y, 8, 8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelShredPainter oldDelegate) => true;
}
