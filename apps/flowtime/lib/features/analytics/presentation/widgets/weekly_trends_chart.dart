import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/productivity_metrics.dart';

class WeeklyTrendsChart extends StatelessWidget {
  final List<WeeklyTrend> trendData;
  final _logger = Logger('WeeklyTrendsChart');

  WeeklyTrendsChart({
    super.key,
    required this.trendData,
  });

  @override
  Widget build(BuildContext context) {
    _logger.fine('Building WeeklyTrendsChart with ${trendData.length} data points');
    
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
            'Weekly Productivity Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: TrendChartPainter(trendData: trendData),
            ),
          ),
        ],
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<WeeklyTrend> trendData;

  TrendChartPainter({required this.trendData});

  @override
  void paint(Canvas canvas, Size size) {
    if (trendData.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final maxScore = trendData.map((e) => e.productivityScore).reduce((a, b) => a > b ? a : b);
    final minScore = trendData.map((e) => e.productivityScore).reduce((a, b) => a < b ? a : b);
    final scoreRange = maxScore - minScore;

    final path = Path();
    final xStep = size.width / (trendData.length - 1);

    for (int i = 0; i < trendData.length; i++) {
      final x = i * xStep;
      final normalizedScore = (trendData[i].productivityScore - minScore) / scoreRange;
      final y = size.height - (normalizedScore * size.height * 0.8) - size.height * 0.1;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw dot
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    canvas.drawPath(path, paint);

    // Draw day labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 0; i < trendData.length && i < days.length; i++) {
      final x = i * xStep;
      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}