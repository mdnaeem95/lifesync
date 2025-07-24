import 'package:equatable/equatable.dart';

enum TaskType { focus, meeting, breakTask, admin }

enum TaskPriority { low, medium, high, urgent }

class Task extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final Duration duration;
  final TaskType taskType;
  final TaskPriority priority;
  final int energyRequired; // 1-5 scale
  final bool isCompleted;
  final bool isFlexible; // Can be rescheduled
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledAt,
    required this.duration,
    required this.taskType,
    required this.priority,
    required this.energyRequired,
    required this.isCompleted,
    required this.isFlexible,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.metadata,
  });

  DateTime get endTime => scheduledAt.add(duration);

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        scheduledAt,
        duration,
        taskType,
        priority,
        energyRequired,
        isCompleted,
        isFlexible,
        createdAt,
        updatedAt,
        metadata,
      ];

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledAt,
    Duration? duration,
    TaskType? taskType,
    TaskPriority? priority,
    int? energyRequired,
    bool? isCompleted,
    bool? isFlexible,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      duration: duration ?? this.duration,
      taskType: taskType ?? this.taskType,
      priority: priority ?? this.priority,
      energyRequired: energyRequired ?? this.energyRequired,
      isCompleted: isCompleted ?? this.isCompleted,
      isFlexible: isFlexible ?? this.isFlexible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}