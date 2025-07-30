import 'dart:ui';
import 'package:equatable/equatable.dart';

class ProductivityMetrics extends Equatable {
  final double completionRate;
  final double focusScore;
  final int totalFocusMinutes;
  final int averageTaskDuration;
  final Map<String, TaskTypeMetrics> taskCompletionByType;
  final List<WeeklyTrend> weeklyTrends;
  final double productivityScore;

  const ProductivityMetrics({
    required this.completionRate,
    required this.focusScore,
    required this.totalFocusMinutes,
    required this.averageTaskDuration,
    required this.taskCompletionByType,
    required this.weeklyTrends,
    required this.productivityScore,
  });

  @override
  List<Object?> get props => [
        completionRate,
        focusScore,
        totalFocusMinutes,
        averageTaskDuration,
        taskCompletionByType,
        weeklyTrends,
        productivityScore,
      ];
}

class TaskTypeMetrics extends Equatable {
  final String taskType;
  final int totalTasks;
  final int completedTasks;
  final double completionRate;
  final int averageDuration;
  final Color typeColor;

  const TaskTypeMetrics({
    required this.taskType,
    required this.totalTasks,
    required this.completedTasks,
    required this.completionRate,
    required this.averageDuration,
    required this.typeColor,
  });

  @override
  List<Object?> get props => [
        taskType,
        totalTasks,
        completedTasks,
        completionRate,
        averageDuration,
        typeColor,
      ];
}

class WeeklyTrend extends Equatable {
  final DateTime date;
  final int completedTasks;
  final int totalTasks;
  final int focusMinutes;
  final double averageEnergy;
  final double productivityScore;

  const WeeklyTrend({
    required this.date,
    required this.completedTasks,
    required this.totalTasks,
    required this.focusMinutes,
    required this.averageEnergy,
    required this.productivityScore,
  });

  @override
  List<Object?> get props => [
        date,
        completedTasks,
        totalTasks,
        focusMinutes,
        averageEnergy,
        productivityScore,
      ];
}