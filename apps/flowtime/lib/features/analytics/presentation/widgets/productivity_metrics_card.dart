import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/productivity_metrics.dart';

class ProductivityMetricsCard extends StatelessWidget {
  final ProductivityMetrics metrics;
  final _logger = Logger('ProductivityMetricsCard');

  ProductivityMetricsCard({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    _logger.fine('Building ProductivityMetricsCard');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Productivity Score',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metrics.productivityScore.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              _buildCircularProgress(metrics.productivityScore / 100),
            ],
          ),
          const SizedBox(height: 24),
          _buildMetricRow('Completion Rate', '${metrics.completionRate.toStringAsFixed(1)}%', AppColors.success),
          const SizedBox(height: 12),
          _buildMetricRow('Focus Score', metrics.focusScore.toStringAsFixed(1), AppColors.primary),
          const SizedBox(height: 12),
          _buildMetricRow('Avg Task Duration', '${metrics.averageTaskDuration} min', AppColors.warning),
          const SizedBox(height: 12),
          _buildMetricRow('Total Focus Time', '${metrics.totalFocusMinutes ~/ 60}h ${metrics.totalFocusMinutes % 60}m', AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double value) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 8,
              backgroundColor: AppColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          Center(
            child: Icon(
              Icons.trending_up,
              color: AppColors.primary,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
