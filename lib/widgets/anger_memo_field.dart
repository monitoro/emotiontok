import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';
import '../utils/app_fonts.dart';

class AngerMemoField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  const AngerMemoField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  State<AngerMemoField> createState() => _AngerMemoFieldState();
}

class _AngerMemoFieldState extends State<AngerMemoField> {
  // ... existing state variables ...
  double _angerIntensity = 0.0;
  Timer? _decayTimer;
  DateTime? _lastTypingTime;

  // Memo colors
  final Color _baseColor = const Color(0xFFFFF59D); // Soft Yellow Paper
  final Color _angryColor = const Color(0xFFFF5252); // Angry Red

  // Paper lines color
  final Color _lineColor = Colors.blue.withOpacity(0.1);
  final Color _angryLineColor = Colors.black.withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    // Decay anger periodically to simulate cooling down
    _decayTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_angerIntensity > 0) {
        setState(() {
          _angerIntensity = (_angerIntensity - 0.02).clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    // ... existing _onTextChanged logic ...
    final now = DateTime.now();
    if (_lastTypingTime != null) {
      final difference = now.difference(_lastTypingTime!).inMilliseconds;
      if (difference < 100) {
        _angerIntensity += 0.15; // Very fast
      } else if (difference < 250) {
        _angerIntensity += 0.08; // Normal-Fast
      } else if (difference < 500) {
        _angerIntensity += 0.02; // Slow
      }

      _angerIntensity = _angerIntensity.clamp(0.0, 1.0);
    }
    _lastTypingTime = now;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);

    // Interpolate colors based on anger intensity
    final currentColor = Color.lerp(_baseColor, _angryColor, _angerIntensity)!;
    final currentLineColor =
        Color.lerp(_lineColor, _angryLineColor, _angerIntensity)!;
    final textColor = Color.lerp(Colors.black87, Colors.white,
        _angerIntensity * 0.8)!; // Text gets lighter on dark red

    return Transform.rotate(
      angle:
          -0.01 + (_angerIntensity * 0.02), // Shake/rotate slightly when angry?
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(20), // Peeling effect
            bottomRight: Radius.circular(2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Paper Grid/Lines Background
            Positioned.fill(
              child: CustomPaint(
                painter: _PaperLinePainter(lineColor: currentLineColor),
              ),
            ),
            // Tape visuals (Optional, adding for realism)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 100,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
            // Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: TextField(
                controller: widget.controller,
                onChanged: _onTextChanged,
                maxLines: null,
                style: AppFonts.getFont(
                  userVM.selectedFont,
                  textStyle: TextStyle(
                    color: textColor,
                    fontSize: 20, // Slightly larger for handwriting
                    height: 1.5,
                  ),
                ),
                cursorColor:
                    _angerIntensity > 0.5 ? Colors.white : Colors.black,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: textColor.withOpacity(0.5),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperLinePainter extends CustomPainter {
  final Color lineColor;
  _PaperLinePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    double lineHeight = 27.0; // Approximation of text height * 1.5
    double offsetY = 40.0; // Initial padding

    while (offsetY < size.height) {
      canvas.drawLine(Offset(0, offsetY), Offset(size.width, offsetY), paint);
      offsetY += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
