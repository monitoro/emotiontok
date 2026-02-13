import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../viewmodels/venting_viewmodel.dart';

class InstagramShareCard extends StatelessWidget {
  final PublicPost post;
  final GlobalKey globalKey;
  final PublicComment? focusComment; // Optional focused comment
  final double rotationAngle; // Rotation for the comment (radians)

  const InstagramShareCard({
    super.key,
    required this.post,
    required this.globalKey,
    this.focusComment,
    this.rotationAngle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine background gradient based on anger level
    final anger = post.angerLevel;
    List<Color> gradientColors;

    if (anger > 80) {
      gradientColors = [const Color(0xFF2B0000), const Color(0xFF800000)];
    } else if (anger > 50) {
      gradientColors = [const Color(0xFF2B1B00), const Color(0xFF804000)];
    } else {
      gradientColors = [const Color(0xFF00102B), const Color(0xFF003080)];
    }

    // Define the base card content
    final baseCard = Container(
      width: 1080 / 3, // Scaled down for preview, but acts as ratio base
      height: 1920 / 3, // 9:16 Ratio
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('사르르',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy.MM.dd').format(post.timestamp),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
              Icon(Icons.local_fire_department,
                  color: Colors.white.withOpacity(0.3)),
            ],
          ),
          const Spacer(flex: 1),

          // Content - Auto-sizing Text
          Expanded(
            flex: 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double fontSize = 24.0;
                const double minFontSize = 8.0;

                // Binary search or iterative reduction for font size
                while (fontSize > minFontSize) {
                  final textPainter = TextPainter(
                    text: TextSpan(
                      text: post.content,
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(focusComment != null ? 0.3 : 1.0),
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    maxLines: null, // No limit on lines
                    textDirection: ui.TextDirection.ltr,
                  );

                  textPainter.layout(maxWidth: constraints.maxWidth);

                  if (textPainter.height <= constraints.maxHeight) {
                    break; // Fits!
                  }
                  fontSize -= 0.5;
                }

                return Center(
                  child: Text(
                    post.content,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(focusComment != null ? 0.3 : 1.0),
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.start,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Text(
            "by. ${post.authorNickname}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),

          const Spacer(flex: 1),

          // Footer / Branding
          Center(
            child: Column(
              children: [
                Text(
                  "익명 감정 배출구",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "사르르",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );

    // If there's a focused comment, wrap the card content in a Stack and overlay the comment
    if (focusComment != null) {
      return RepaintBoundary(
        key: globalKey,
        child: Stack(
          alignment: Alignment.center,
          children: [
            baseCard,
            Transform.rotate(
              angle: rotationAngle,
              child: Container(
                width: 280,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.black
                      .withOpacity(0.4), // 60% transparency (0.4 opacity)
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.format_quote,
                        color: Colors.white.withOpacity(0.8), size: 24),
                    const SizedBox(height: 8),
                    Text(
                      focusComment!.content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.8), // 20% transparency
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "- ${focusComment!.nickname} -",
                      style: TextStyle(
                        color: Colors.orangeAccent.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default return without overlay
    return RepaintBoundary(
      key: globalKey,
      child: baseCard,
    );
  }
}
