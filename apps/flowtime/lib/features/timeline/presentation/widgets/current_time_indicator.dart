import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class CurrentTimeIndicator extends StatefulWidget {
  final ScrollController scrollController;

  const CurrentTimeIndicator({
    super.key,
    required this.scrollController,
  });

  @override
  State<CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<CurrentTimeIndicator> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  double get _topOffset {
    final hoursSinceMidnight = _currentTime.hour + (_currentTime.minute / 60);
    return 40 + (hoursSinceMidnight * 120); // 40px top padding + 120px per hour
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _topOffset,
      left: 0,
      right: 0,
      child: Row(
        children: [
          // Time label
          Container(
            width: 60,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          
          // Line
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          
          // Dot at the end
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}