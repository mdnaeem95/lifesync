import 'package:equatable/equatable.dart';

enum TaskType {
  focus,
  meeting,
  breakTask,
  admin,
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

class Task extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final Duration duration;
  final TaskType taskType;
  final TaskPriority priority;
  final int energyRequired;
  final bool isFlexible;
  final bool isCompleted;
  final List<String> tags;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
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
    required this.isFlexible,
    required this.isCompleted,
    required this.tags,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  DateTime get endTime => scheduledAt.add(duration);

  bool get isOverdue => !isCompleted && endTime.isBefore(DateTime.now());

  bool get isUpcoming {
    final now = DateTime.now();
    return scheduledAt.isAfter(now) && 
           scheduledAt.difference(now).inMinutes <= 15;
  }

  String get durationString {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledAt,
    Duration? duration,
    TaskType? taskType,
    TaskPriority? priority,
    int? energyRequired,
    bool? isFlexible,
    bool? isCompleted,
    List<String>? tags,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      isFlexible: isFlexible ?? this.isFlexible,
      isCompleted: isCompleted ?? this.isCompleted,
      tags: tags ?? this.tags,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

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
        isFlexible,
        isCompleted,
        tags,
        completedAt,
        createdAt,
        updatedAt,
        metadata,
      ];
}

// Extension for TaskType
extension TaskTypeExtension on TaskType {
  String get displayName {
    switch (this) {
      case TaskType.focus:
        return 'Focus';
      case TaskType.meeting:
        return 'Meeting';
      case TaskType.breakTask:
        return 'Break';
      case TaskType.admin:
        return 'Admin';
    }
  }

  String get icon {
    switch (this) {
      case TaskType.focus:
        return '🎯';
      case TaskType.meeting:
        return '👥';
      case TaskType.breakTask:
        return '☕';
      case TaskType.admin:
        return '📋';
    }
  }
}

// Extension for TaskPriority
extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  int get value {
    switch (this) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.urgent:
        return 4;
    }
  }
}