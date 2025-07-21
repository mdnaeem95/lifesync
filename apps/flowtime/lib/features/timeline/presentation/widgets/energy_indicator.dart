import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/energy_provider.dart';

class EnergyIndicator extends StatelessWidget {
  final int currentLevel;
  final List<EnergyPrediction> predictedLevels;

  const EnergyIndicator({
    super.key,
    required this.currentLevel,
    required this.predictedLevels,
  });

  Color _getEnergyColor(int level) {
    if (level >= 70) return AppColors.energyHigh;
    if (level >= 40) return AppColors.energyMedium;
    return AppColors.energyLow;
  }

  String _getEnergyLabel(int level) {
    if (level >= 70) return 'High Energy';
    if (level >= 40) return 'Medium Energy';
    return 'Low Energy';
  }

  @override
  Widget build(BuildContext context) {
    final energyColor = _getEnergyColor(currentLevel);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            energyColor.withValues(alpha: 0.1),
            energyColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: energyColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current energy level
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Energy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.bolt,
                        color: energyColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentLevel%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: energyColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getEnergyLabel(currentLevel),
                        style: TextStyle(
                          fontSize: 14,
                          color: energyColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Energy trend indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: energyColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getEnergyTrendIcon(),
                  color: energyColor,
                  size: 20,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Energy prediction graph
          SizedBox(
            height: 60,
            child: CustomPaint(
              painter: EnergyGraphPainter(
                predictions: predictedLevels,
                currentHour: DateTime.now().hour,
              ),
              child: Container(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Recommendation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.amber[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getEnergyRecommendation(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  IconData _getEnergyTrendIcon() {
    // TODO: Calculate based on recent history
    return Icons.trending_up;
  }

  String _getEnergyRecommendation() {
    if (currentLevel >= 70) {
      return 'Perfect time for deep focus work! Your energy is at its peak.';
    } else if (currentLevel >= 40) {
      return 'Good for collaborative work or routine tasks.';
    } else {
      return 'Consider a short break or light administrative tasks.';
    }
  }
}

// Custom painter for energy graph
class EnergyGraphPainter extends CustomPainter {
  final List<EnergyPrediction> predictions;
  final int currentHour;

  EnergyGraphPainter({
    required this.predictions,
    required this.currentHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (predictions.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < predictions.length; i++) {
      final x = (i / (predictions.length - 1)) * size.width;
      final y = size.height - (predictions[i].level / 100 * size.height);
      points.add(Offset(x, y));
    }

    // Draw fill area
    fillPath.moveTo(0, size.height);
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      } else {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw gradient fill
    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.primary.withValues(alpha: 0.3),
        AppColors.primary.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    paint.color = AppColors.primary;
    canvas.drawPath(path, paint);

    // Draw current time indicator
    if (currentHour >= 0 && currentHour < 24) {
      final currentX = (currentHour / 23) * size.width;
      final indicatorPaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2;

      canvas.drawLine(
        Offset(currentX, 0),
        Offset(currentX, size.height),
        indicatorPaint,
      );

      // Draw circle at current position
      final currentIndex = predictions.indexWhere((p) => p.time.hour == currentHour);
      if (currentIndex != -1) {
        canvas.drawCircle(
          points[currentIndex],
          4,
          Paint()..color = AppColors.primary,
        );
        canvas.drawCircle(
          points[currentIndex],
          6,
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}