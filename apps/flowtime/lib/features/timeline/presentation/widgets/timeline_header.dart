import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class TimelineHeader extends StatefulWidget {
  final Function(DateTime) onDateChanged;
  final VoidCallback onTodayPressed;

  const TimelineHeader({
    super.key,
    required this.onDateChanged,
    required this.onTodayPressed,
  });

  @override
  State<TimelineHeader> createState() => _TimelineHeaderState();
}

class _TimelineHeaderState extends State<TimelineHeader> {
  DateTime _selectedDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d');

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    widget.onDateChanged(_selectedDate);
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    widget.onDateChanged(_selectedDate);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      widget.onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Date navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousDay,
                tooltip: 'Previous day',
              ),
              
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isToday ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: _isToday ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isToday ? 'Today' : _dateFormat.format(_selectedDate),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isToday ? AppColors.primary : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextDay,
                tooltip: 'Next day',
              ),
            ],
          ),
          
          // Today button
          if (!_isToday)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
                widget.onTodayPressed();
              },
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Today'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ).animate().fadeIn().scale(),
        ],
      ),
    );
  }
}