import '../entities/task.dart';

abstract class TimelineRepository {
  Future<List<Task>> getTasksForDate(DateTime date);
  Future<Task> createTask(Task task);
  Future<Task> updateTask(String taskId, Task task);
  Future<void> deleteTask(String taskId);
  Future<void> completeTask(String taskId);
  Future<void> toggleTaskComplete(String taskId);
  Future<Task> rescheduleTask(String taskId, DateTime newTime);
  Future<List<DateTime>> getSuggestedTimeSlots(
    Duration duration,
    int energyRequired,
    DateTime preferredDate,
  );
}