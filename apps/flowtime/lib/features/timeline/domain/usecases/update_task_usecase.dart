import '../repositories/task_repository.dart';
import '../entities/task.dart';

/// Updates an existing [Task] in the repository.
class UpdateTaskUseCase {
  final TaskRepository _repo;
  UpdateTaskUseCase(this._repo);

  /// Saves the changes to [task].
  Future<void> call(Task task) {
    return _repo.updateTask(task);
  }
}