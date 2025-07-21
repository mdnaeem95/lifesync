import '../repositories/task_repository.dart';
import '../entities/task.dart';

class GetDailyTasksUseCase {
  final TaskRepository _repo;
  GetDailyTasksUseCase(this._repo);

  Future<List<Task>> call(DateTime date) {
    return _repo.getTasksForDate(date);
  }
}
