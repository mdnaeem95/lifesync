import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/analytics_data.dart';

class FlowStateAchievements extends StatelessWidget {
  final List<FlowAchievement> achievements;
  final _logger = Logger('FlowStateAchievements');

  FlowStateAchievements({
    super.key,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {
    _logger.fine('Building FlowStateAchievements with ${achievements.length} achievements');
    
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return _buildAchievementCard(achievement);
        },
      ),
    );
  }

  Widget _buildAchievementCard(FlowAchievement achievement) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achievement.isUnlocked 
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achievement.isUnlocked 
            ? AppColors.primary 
            : AppColors.borderSubtle,
          width: achievement.isUnlocked ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForAchievement(achievement.iconName),
            size: 32,
            color: achievement.isUnlocked 
              ? AppColors.primary 
              : AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: achievement.isUnlocked 
                ? AppColors.textPrimary 
                : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!achievement.isUnlocked) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: achievement.progress,
              backgroundColor: AppColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 2,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForAchievement(String iconName) {
    switch (iconName) {
      case 'sunrise':
        return Icons.wb_sunny;
      case 'focus':
        return Icons.center_focus_strong;
      case 'calendar':
        return Icons.calendar_today;
      default:
        return Icons.star;
    }
  }
}