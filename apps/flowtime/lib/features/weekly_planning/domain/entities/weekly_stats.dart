import 'package:equatable/equatable.dart';

class WeeklyStats extends Equatable {
  final int totalTasks;
  final int completedTasks;
  final int totalFocusMinutes;
  final int totalMeetingMinutes;
  final int totalBreakMinutes;
  final double averageEnergyLevel;
  final double completionRate;
  final double optimalTaskPlacement; // percentage of tasks in optimal energy slots
  final Map<String, int> tasksByType; // taskType -> count
  final Map<int, int> tasksByDay; // dayOfWeek -> count
  final List<ProductivityInsight> insights;

  const WeeklyStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalFocusMinutes,
    required this.totalMeetingMinutes,
    required this.totalBreakMinutes,
    required this.averageEnergyLevel,
    required this.completionRate,
    required this.optimalTaskPlacement,
    required this.tasksByType,
    required this.tasksByDay,
    required this.insights,
  });

  int get totalProductiveMinutes => totalFocusMinutes + totalMeetingMinutes;
  
  double get focusToMeetingRatio => 
      totalMeetingMinutes > 0 ? totalFocusMinutes / totalMeetingMinutes : 0.0;

  @override
  List<Object?> get props => [
        totalTasks,
        completedTasks,
        totalFocusMinutes,
        totalMeetingMinutes,
        totalBreakMinutes,
        averageEnergyLevel,
        completionRate,
        optimalTaskPlacement,
        tasksByType,
        tasksByDay,
        insights,
      ];
}

class ProductivityInsight extends Equatable {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final InsightPriority priority;
  final String? actionableAdvice;

  const ProductivityInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    this.actionableAdvice,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        priority,
        actionableAdvice,
      ];
}

enum InsightType {
  overbooked,
  underutilized,
  poorEnergyAlignment,
  tooManyMeetings,
  insufficientBreaks,
  excellentBalance,
}

enum InsightPriority {
  low,
  medium,
  high,
  critical,
}