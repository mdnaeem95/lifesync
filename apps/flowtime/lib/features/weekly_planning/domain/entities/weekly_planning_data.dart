import 'package:equatable/equatable.dart';
import '../../../timeline/domain/entities/task.dart';

class WeeklyPlanningData extends Equatable {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final List<Task> tasks;
  final Map<int, Map<int, int>> energyPredictions; // day -> hour -> energy level
  final Map<String, List<String>> taskConflicts; // taskId -> conflicting taskIds
  final bool isOptimized;
  final DateTime lastUpdated;

  const WeeklyPlanningData({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.tasks,
    required this.energyPredictions,
    this.taskConflicts = const {},
    this.isOptimized = false,
    required this.lastUpdated,
  });

  WeeklyPlanningData copyWith({
    DateTime? weekStartDate,
    DateTime? weekEndDate,
    List<Task>? tasks,
    Map<int, Map<int, int>>? energyPredictions,
    Map<String, List<String>>? taskConflicts,
    bool? isOptimized,
    DateTime? lastUpdated,
  }) {
    return WeeklyPlanningData(
      weekStartDate: weekStartDate ?? this.weekStartDate,
      weekEndDate: weekEndDate ?? this.weekEndDate,
      tasks: tasks ?? this.tasks,
      energyPredictions: energyPredictions ?? this.energyPredictions,
      taskConflicts: taskConflicts ?? this.taskConflicts,
      isOptimized: isOptimized ?? this.isOptimized,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        weekStartDate,
        weekEndDate,
        tasks,
        energyPredictions,
        taskConflicts,
        isOptimized,
        lastUpdated,
      ];
}