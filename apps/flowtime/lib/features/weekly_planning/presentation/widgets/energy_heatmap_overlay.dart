import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';

class EnergyHeatmapOverlay extends StatelessWidget {
  final Map<int, Map<int, int>> energyData;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double dayWidth;
  final double timeColumnWidth;
  final AnimationController animationController;
  final _logger = Logger('EnergyHeatmapOverlay');

  EnergyHeatmapOverlay({
    super.key,
    required this.energyData,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.dayWidth,
    required this.timeColumnWidth,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    _logger.finest('Building energy heatmap overlay');
    
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: HeatmapPainter(
            energyData: energyData,
            startHour: startHour,
            endHour: endHour,
            hourHeight: hourHeight,
            dayWidth: dayWidth,
            timeColumnWidth: timeColumnWidth,
            opacity: animationController.value,
          ),
        );
      },
    );
  }
}

class HeatmapPainter extends CustomPainter {
  final Map<int, Map<int, int>> energyData;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double dayWidth;
  final double timeColumnWidth;
  final double opacity;
  final _logger = Logger('HeatmapPainter');

  HeatmapPainter({
    required this.energyData,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.dayWidth,
    required this.timeColumnWidth,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _logger.finest('Painting heatmap with opacity: $opacity');
    
    for (int day = 0; day < 7; day++) {
      final dayEnergy = energyData[day] ?? {};
      
      for (int hour = startHour; hour <= endHour; hour++) {
        final energy = dayEnergy[hour] ?? 50;
        final color = _getEnergyColor(energy).withOpacity(0.2 * opacity);
        
        final left = timeColumnWidth + (day * dayWidth);
        final top = (hour - startHour) * hourHeight;
        
        final rect = Rect.fromLTWH(left, top, dayWidth, hourHeight);
        final paint = Paint()..color = color;
        
        canvas.drawRect(rect, paint);
      }
    }
  }

  Color _getEnergyColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.primary;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  bool shouldRepaint(HeatmapPainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
           oldDelegate.energyData != energyData;
  }
}