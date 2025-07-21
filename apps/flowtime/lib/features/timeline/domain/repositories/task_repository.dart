// lib/domain/repositories/task_repository.dart

import '../entities/task.dart';

/// A pure interface for getting/updating tasks.
abstract class TaskRepository {
  /// Return all tasks scheduled on [date].
  Future<List<Task>> getTasksForDate(DateTime date);

  /// Update an existing task.
  Future<void> updateTask(Task task);

  /// Move [task] to a new scheduled time.
  Future<void> rescheduleTask(String taskId, DateTime newTime);
}
