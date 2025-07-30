import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';

class WeekHeader extends StatelessWidget {
  final DateTime selectedWeek;
  final ValueChanged<DateTime> onWeekChanged;
  final _logger = Logger('WeekHeader');

  WeekHeader({
    super.key,
    required this.selectedWeek,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = _getStartOfWeek(selectedWeek);
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    _logger.finest('Building week header for ${_formatDate(weekStart)} - ${_formatDate(weekEnd)}');
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous week button
        IconButton(
          onPressed: () {
            final previousWeek = selectedWeek.subtract(const Duration(days: 7));
            _logger.fine('Navigating to previous week: ${_formatDate(previousWeek)}');
            onWeekChanged(previousWeek);
          },
          icon: const Icon(Icons.chevron_left),
          color: AppColors.textSecondary,
        ),
        
        // Week display
        Expanded(
          child: GestureDetector(
            onTap: _showWeekPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        
        // Next week button
        IconButton(
          onPressed: () {
            final nextWeek = selectedWeek.add(const Duration(days: 7));
            _logger.fine('Navigating to next week: ${_formatDate(nextWeek)}');
            onWeekChanged(nextWeek);
          },
          icon: const Icon(Icons.chevron_right),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _showWeekPicker() {
    _logger.info('Opening week picker');
    // TODO: Implement week picker dialog
  }
}