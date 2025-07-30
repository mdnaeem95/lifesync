import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/analytics_data.dart';

class AIInsightsCard extends StatelessWidget {
  final List<AIInsight> insights;
  final _logger = Logger('AIInsightsCard');

  AIInsightsCard({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    _logger.fine('Building AIInsightsCard with ${insights.length} insights');
    
    return Column(
      children: insights.map((insight) => _buildInsightCard(insight)).toList(),
    );
  }

  Widget _buildInsightCard(AIInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getInsightColor(insight.type).withOpacity(0.1),
            _getInsightColor(insight.type).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getInsightColor(insight.type).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getInsightIcon(insight.type),
                color: _getInsightColor(insight.type),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(insight.confidenceScore * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.actionableAdvice,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getInsightColor(InsightType type) {
    switch (type) {
      case InsightType.energyPattern:
        return AppColors.primary;
      case InsightType.productivity:
        return AppColors.success;
      case InsightType.scheduling:
        return AppColors.warning;
      case InsightType.habits:
        return AppColors.secondary;
      case InsightType.recommendation:
        return AppColors.info;
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.energyPattern:
        return Icons.battery_charging_full;
      case InsightType.productivity:
        return Icons.trending_up;
      case InsightType.scheduling:
        return Icons.calendar_today;
      case InsightType.habits:
        return Icons.refresh;
      case InsightType.recommendation:
        return Icons.assistant;
    }
  }
}