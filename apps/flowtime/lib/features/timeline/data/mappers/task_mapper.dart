import '../models/task_model.dart';
import '../../domain/entities/task.dart';

class TaskMapper {
  static Task toEntity(TaskModel model) {
    return Task(
      id: model.id,
      title: model.title,
      description: model.description,
      scheduledAt: model.scheduledAt,
      duration: Duration(minutes: model.duration),
      taskType: TaskType.values.firstWhere((e) => e.name == model.taskType),
      priority: TaskPriority.values.firstWhere((e) => e.name == model.priority),
      energyRequired: model.energyRequired,
      isCompleted: model.isCompleted,
      isFlexible: model.isFlexible,
      completedAt: model.completedAt,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      metadata: model.metadata,
    );
  }

  static TaskModel fromEntity(Task entity) {
    return TaskModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      scheduledAt: entity.scheduledAt,
      duration: entity.duration.inMinutes,
      taskType: entity.taskType.name,
      priority: entity.priority.name,
      energyRequired: entity.energyRequired,
      isCompleted: entity.isCompleted,
      isFlexible: entity.isFlexible,
      completedAt: entity.completedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      metadata: entity.metadata,
    );
  }
}