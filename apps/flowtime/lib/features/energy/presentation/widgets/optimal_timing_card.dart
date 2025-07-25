import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class OptimalTimingCard extends StatelessWidget {
  final int peakHour;
  final int lowHour;

  const OptimalTimingCard({
    super.key,
    required this.peakHour,
    required this.lowHour,
  });

  @override
  Widget build(BuildContext context) {
    final timingSlots = [
      TimingSlot(
        taskType: 'Deep Focus Work',
        timeWindow: '${_formatHour(peakHour)} - ${_formatHour(peakHour + 2)}',
        energyLevel: 'High Energy',
        color: AppColors.success,
      ),
      TimingSlot(
        taskType: 'Creative Tasks',
        timeWindow: '${_formatHour(peakHour + 5)} - ${_formatHour(peakHour + 7)}',
        energyLevel: 'Medium Energy',
        color: AppColors.primary,
      ),
      TimingSlot(
        taskType: 'Administrative',
        timeWindow: '${_formatHour(lowHour)} - ${_formatHour(lowHour + 1)}',
        energyLevel: 'Low Energy',
        color: AppColors.warning,
      ),
    ];

    return Column(
      children: timingSlots.map((slot) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.taskType,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot.timeWindow,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: slot.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  slot.energyLevel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: slot.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ).animate().slideX(
          begin: 0.1,
          duration: 400.ms,
          delay: Duration(milliseconds: timingSlots.indexOf(slot) * 100),
          curve: Curves.easeOutCubic,
        );
      }).toList(),
    );
  }

  String _formatHour(int hour) {
    final h = hour % 24;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:00 $period';
  }
}

class TimingSlot {
  final String taskType;
  final String timeWindow;
  final String energyLevel;
  final Color color;

  TimingSlot({
    required this.taskType,
    required this.timeWindow,
    required this.energyLevel,
    required this.color,
  });
}