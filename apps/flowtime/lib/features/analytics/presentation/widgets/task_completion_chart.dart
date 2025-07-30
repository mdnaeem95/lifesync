import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/productivity_metrics.dart';

class TaskCompletionChart extends StatelessWidget {
  final Map<String, TaskTypeMetrics> completionData;
  final _logger = Logger('TaskCompletionChart');

  TaskCompletionChart({
    super.key,
    required this.completionData,
  });

  @override
  Widget build(BuildContext context) {
    _logger.fine('Building TaskCompletionChart');
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completion by Task Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: completionData.entries.map((entry) {
                return _buildBar(entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(TaskTypeMetrics metrics) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${metrics.completionRate.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Container(
            width: 60,
            decoration: BoxDecoration(
              color: metrics.typeColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: metrics.typeColor, width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: metrics.completionRate / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: metrics.typeColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          metrics.taskType,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
