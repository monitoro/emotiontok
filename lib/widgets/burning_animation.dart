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
  final List<_ExplosionParticle> _particles = [];
  final Random _random = Random();
  late Animation<double> _shakeAnimation;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 짧고 강렬하게
    );

    // 0~0.2초 동안 강한 흔들림 (폭발 충격)
    _shakeAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );

    // 초반 섬광 효과
    _flashAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _controller.addListener(() {
      // 폭발 초기(0.1초 시점)에 대량의 파티클 생성
      if (_controller.value > 0.05 &&
          _controller.value < 0.15 &&
          _particles.length < 100) {
        for (int i = 0; i < 20; i++) {
          _particles.add(_ExplosionParticle());
        }
      }
      // 지속적인 불길 추가
      if (_controller.value > 0.1 && _controller.value < 0.8) {
        _particles.add(_ExplosionParticle(isContinuous: true));
      }

      for (var particle in _particles) {
        particle.update();
      }

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 화면 흔들림 계산
        final double shakeX = _random.nextDouble() * _shakeAnimation.value -
            (_shakeAnimation.value / 2);
        final double shakeY = _random.nextDouble() * _shakeAnimation.value -
            (_shakeAnimation.value / 2);

        return Transform.translate(
          offset: Offset(shakeX, shakeY),
          child: Stack(
            children: [
              // 1. 배경 (폭발 시 깜빡임)
              Container(
                color: Colors.black.withOpacity(
                  (0.8 + (_flashAnimation.value * 0.2)).clamp(0.0, 0.95),
                ),
              ),

              // 2. 종이 및 텍스트 (폭발과 함께 찢어지고 사라짐)
              if (_controller.value < 0.8)
                Center(
                  child: Transform.scale(
                    scale: 1.0 + (_controller.value * 0.5), // 타면서 약간 커짐
                    child: Opacity(
                      opacity:
                          (1.0 - (_controller.value * 1.5)).clamp(0.0, 1.0),
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 20 + (_controller.value * 50),
                              spreadRadius: _controller.value * 20,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.text.isEmpty ? "..." : widget.text,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. 폭발 및 불꽃 파티클
              Positioned.fill(
                child: CustomPaint(
                  painter: _ExplosionPainter(_particles),
                ),
              ),

              // 4. 화이트 플래시 (폭발 순간)
              if (_flashAnimation.value > 0)
                Container(
                  color: Colors.white.withOpacity(_flashAnimation.value * 0.8),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ExplosionParticle {
  late double x;
  late double y;
  late double size;
  late double velocityX;
  late double velocityY;
  late double life;
  late Color color;
  final Random _random = Random();

  _ExplosionParticle({bool isContinuous = false}) {
    // 중앙에서 폭발
    x = 0;
    y = 0;

    if (isContinuous) {
      // 지속적으로 타오르는 불길 (아래에서 위로)
      x = (_random.nextDouble() - 0.5) * 300; // 넓게 퍼짐
      y = 100 + _random.nextDouble() * 100;
      size = _random.nextDouble() * 40 + 20; // 큰 불꽃
      velocityX = (_random.nextDouble() - 0.5) * 4;
      velocityY = -(_random.nextDouble() * 15 + 5); // 빠르게 솟구침
      life = 0.8;
      color = Colors.orangeAccent;
    } else {
      // 초기 폭발 (사방으로 튐)
      double angle = _random.nextDouble() * 2 * pi;
      double speed = _random.nextDouble() * 20 + 10;
      x = cos(angle) * 20; // 약간의 초기 분산
      y = sin(angle) * 20;
      size = _random.nextDouble() * 30 + 10;
      velocityX = cos(angle) * speed;
      velocityY = sin(angle) * speed;
      life = 1.0;
      color = _random.nextBool() ? Colors.white : Colors.yellow; // 섬광 색상
    }

    // 색상 랜덤 변형 (노랑 -> 빨강 -> 검정)
    if (_random.nextDouble() > 0.7) color = Colors.redAccent;
    if (_random.nextDouble() > 0.9) color = Colors.grey; // 연기
  }

  void update() {
    x += velocityX;
    y += velocityY;

    // 중력 영향 (약하게)을 받지만 불꽃은 위로 솟구치려는 성질
    velocityY += 0.5; // 약간의 중력이나 저항
    // 불꽃은 위로 가속
    if (color == Colors.orangeAccent || color == Colors.redAccent) {
      velocityY -= 0.8;
    }

    life -= 0.03;
    size *= 0.95; // 점점 사라짐
  }
}

class _ExplosionPainter extends CustomPainter {
  final List<_ExplosionParticle> particles;

  _ExplosionPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    for (var p in particles) {
      if (p.life <= 0) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(p.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10); // 강한 발광 효과

      canvas.drawCircle(
        Offset(center.dx + p.x, center.dy + p.y),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter oldDelegate) => true;
}
