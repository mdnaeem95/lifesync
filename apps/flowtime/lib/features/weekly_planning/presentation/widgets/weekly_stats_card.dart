import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/weekly_planning_provider.dart';

class WeeklyStatsCard extends StatelessWidget {
  final WeeklyStats stats;
  final _logger = Logger('WeeklyStatsCard');

  WeeklyStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    _logger.finest('Building weekly stats card');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.task_alt,
            value: '${stats.completedTasks}/${stats.totalTasks}',
            label: 'Tasks',
            color: AppColors.success,
          ),
          _buildStatItem(
            icon: Icons.timer,
            value: '${(stats.totalFocusMinutes / 60).toStringAsFixed(1)}h',
            label: 'Focus',
            color: AppColors.focus,
          ),
          _buildStatItem(
            icon: Icons.bolt,
            value: '${stats.averageEnergyLevel}%',
            label: 'Avg Energy',
            color: AppColors.warning,
          ),
          _buildStatItem(
            icon: Icons.auto_fix_high,
            value: '${stats.optimalTaskPlacement}%',
            label: 'Optimal',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}