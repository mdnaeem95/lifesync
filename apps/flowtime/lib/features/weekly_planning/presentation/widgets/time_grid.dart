import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';

class TimeGrid extends StatelessWidget {
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double dayWidth;
  final double timeColumnWidth;
  final AnimationController animationController;
  final _logger = Logger('TimeGrid');

  TimeGrid({
    super.key,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.dayWidth,
    required this.timeColumnWidth,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    _logger.finest('Building time grid from $startHour:00 to $endHour:00');
    
    final totalHours = endHour - startHour + 1;
    final totalHeight = totalHours * hourHeight;
    final totalWidth = timeColumnWidth + (7 * dayWidth);
    
    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        children: [
          // Vertical lines (days)
          ...List.generate(8, (index) {
            final left = index == 0 ? timeColumnWidth : timeColumnWidth + ((index - 1) * dayWidth);
            return Positioned(
              left: left,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: AppColors.borderSubtle.withValues(alpha: 0.5),
              ),
            );
          }),
          
          // Horizontal lines and time labels
          ...List.generate(totalHours, (index) {
            final hour = startHour + index;
            final top = index * hourHeight;
            
            return Positioned(
              left: 0,
              top: top,
              right: 0,
              child: Row(
                children: [
                  // Time label
                  Container(
                    width: timeColumnWidth,
                    height: hourHeight,
                    alignment: Alignment.center,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Horizontal line
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.borderSubtle.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            );
          }),
          
          // Day headers
          Positioned(
            top: 0,
            left: timeColumnWidth,
            right: 0,
            child: Row(
              children: List.generate(7, (index) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return Container(
                  width: dayWidth,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      days[index],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}