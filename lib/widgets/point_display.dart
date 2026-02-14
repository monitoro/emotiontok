import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/venting_viewmodel.dart';

class PointDisplay extends StatelessWidget {
  const PointDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer를 사용하여 VentingViewModel의 상태 변화를 감지합니다.
    return Consumer<VentingViewModel>(
      builder: (context, ventingVM, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPointItem(
                Icons.fireplace, ventingVM.firewoodCount, Colors.orange),
            const SizedBox(width: 12),
            _buildPointItem(
                Icons.water_drop, ventingVM.waterCount, Colors.blue),
          ],
        );
      },
    );
  }

  Widget _buildPointItem(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
