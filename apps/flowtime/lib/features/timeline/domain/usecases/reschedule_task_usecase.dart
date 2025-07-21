import '../repositories/task_repository.dart';

/// Moves the task with [taskId] to a new [newTime].
class RescheduleTaskUseCase {
  final TaskRepository _repo;
  RescheduleTaskUseCase(this._repo);

  Future<void> call(String taskId, DateTime newTime) {
    return _repo.rescheduleTask(taskId, newTime);
  }
}