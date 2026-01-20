import 'package:flutter/material.dart';

class BurningAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const BurningAnimation({super.key, required this.onComplete});

  @override
  State<BurningAnimation> createState() => _BurningAnimationState();
}

class _BurningAnimationState extends State<BurningAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart),
    );

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
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            // Background Darkening
            Container(color: Colors.black.withOpacity(_animation.value * 0.8)),
            Center(
              child: Opacity(
                opacity: 1.0 - _animation.value,
                child: Transform.scale(
                  scale: 1.0 + (_animation.value * 0.5),
                  child: Transform.rotate(
                    angle: _animation.value * 0.1,
                    child: Container(
                      width: 300,
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(_animation.value),
                            blurRadius: 50,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          10,
                          (index) => Container(
                            height: 10,
                            width: (300 - (index * 20)).toDouble(),
                            margin: const EdgeInsets.only(bottom: 10),
                            color: Colors.grey[300],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Fire Particles (Simple Simulation)
            if (_animation.value > 0.2)
              ...List.generate(20, (index) {
                final double progress = (_animation.value - 0.2) / 0.8;
                return Positioned(
                  bottom: progress * 800,
                  left: 100 +
                      (index * 15) +
                      (progress * 50 * (index % 2 == 0 ? 1 : -1)),
                  child: Opacity(
                    opacity: (1.0 - progress).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.local_fire_department,
                      color: index % 2 == 0 ? Colors.orange : Colors.red,
                      size: 20 + (progress * 40),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
