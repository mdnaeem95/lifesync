import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class CurrentTimeIndicator extends StatelessWidget {
  final ScrollController scrollController;

  const CurrentTimeIndicator({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hoursSinceMidnight = now.hour + (now.minute / 60);
    final topPosition = hoursSinceMidnight * 80.0 + 40; // 80px per hour + top padding

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: Row(
        children: [
          // Time label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _formatTime(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Line
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.primary,
            ),
          ),
          // Dot at the end (no animation on web)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}