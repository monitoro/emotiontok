import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';

class AttendanceDialog extends StatefulWidget {
  final int currentStreak;
  final int rewardPoints;

  const AttendanceDialog({
    super.key,
    required this.currentStreak,
    required this.rewardPoints,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _stampController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final AudioPlayer _sfxPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _scaleAnimation = Tween<double>(begin: 2.0, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _stampController, curve: const Interval(0.0, 0.5)),
    );

    _playEnterAnimation();
  }

  void _playEnterAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Play sound
    try {
      // Use explosion sound for "Bang" effect
      await _sfxPlayer.play(AssetSource('sounds/explosion.mp3'), volume: 0.5);
    } catch (e) {
      debugPrint('Attendance SFX failed: $e');
    }

    _stampController.forward();
  }

  @override
  void dispose() {
    _stampController.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Card
          Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D00).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '출석 체크',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '매일매일 감정을 돌보러 와주셨네요!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Days Grid
                SizedBox(
                  height: 160,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: 7, // 7 Days
                    itemBuilder: (context, index) {
                      final dayNum = index + 1;
                      final isToday = dayNum == widget.currentStreak;
                      final isPast = dayNum < widget.currentStreak;
                      final isFuture = dayNum > widget.currentStreak;
                      final isBonusDay = dayNum == 7;

                      if (isToday) {
                        // Current Day (Animated)
                        return AnimatedBuilder(
                          animation: _stampController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _opacityAnimation.value,
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: _buildDayItem(
                                    dayNum, true, false, isBonusDay),
                              ),
                            );
                          },
                        );
                      } else {
                        // Other Days
                        return _buildDayItem(
                            dayNum, isPast, isFuture, isBonusDay);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Reward Text
                AnimatedBuilder(
                    animation: _stampController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.translate(
                          offset:
                              Offset(0, (1.0 - _opacityAnimation.value) * 20),
                          child: Column(
                            children: [
                              Text(
                                '+${widget.rewardPoints} EP',
                                style: const TextStyle(
                                  color: Color(0xFFFF4D00),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                '포인트 획득!',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                const SizedBox(height: 32),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final userVM =
                          Provider.of<UserViewModel>(context, listen: false);
                      userVM.dismissAttendanceDialog();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('확인',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(int day, bool isReached, bool isFuture, bool isBonus) {
    Color bgColor = const Color(0xFF2A2A2A);
    Color borderColor = Colors.white12;
    Color textColor = Colors.grey;
    IconData? icon;

    if (isReached) {
      bgColor = const Color(0xFFFF4D00).withOpacity(0.2);
      borderColor = const Color(0xFFFF4D00);
      textColor = const Color(0xFFFF4D00);
      icon = Icons.local_fire_department;
    } else if (isFuture) {
      if (isBonus) {
        bgColor = Colors.yellow.withOpacity(0.1);
        borderColor = Colors.yellow.withOpacity(0.3);
        textColor = Colors.yellow;
        icon = Icons.star_border; // Placeholder for bonus
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, color: textColor, size: 20)
          else if (isBonus && isFuture)
            const Icon(Icons.card_giftcard, color: Colors.yellow, size: 20)
          else
            Text('$day일', style: TextStyle(color: textColor, fontSize: 12)),
          if (isReached || (isFuture && isBonus))
            Text(isBonus ? '+40' : '+10',
                style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
