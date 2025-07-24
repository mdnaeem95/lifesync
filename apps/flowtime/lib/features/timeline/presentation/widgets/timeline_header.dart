import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class TimelineHeader extends StatelessWidget {
  final Function(DateTime) onDateChanged;
  final VoidCallback onTodayPressed;

  const TimelineHeader({
    super.key,
    required this.onDateChanged,
    required this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => onDateChanged(
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  TextButton(
                    onPressed: onTodayPressed,
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onDateChanged(
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}