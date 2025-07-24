import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/timeline_repository.dart';
import '../models/task_model.dart';
import '../mappers/task_mapper.dart'; // Add this import

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TimelineRepositoryImpl(apiClient);
});

class TimelineRepositoryImpl implements TimelineRepository {
  final ApiClient _apiClient;

  TimelineRepositoryImpl(this._apiClient);

  @override
  Future<List<Task>> getTasksForDate(DateTime date) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.tasks,
        queryParameters: {
          'date': date.toIso8601String().split('T')[0],
        },
      );

      final tasks = (response.data as List)
          .map((json) => TaskModel.fromJson(json))
          .map((model) => TaskMapper.toEntity(model)) // Use mapper here
          .toList();

      return tasks;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Task> createTask(Task task) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.tasks,
        data: TaskMapper.fromEntity(task).toJson(), // Use mapper here
      );

      return TaskMapper.toEntity(TaskModel.fromJson(response.data)); // Use mapper here
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Task> updateTask(String taskId, Task task) async {
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.tasks}/$taskId',
        data: TaskMapper.fromEntity(task).toJson(), // Use mapper here
      );

      return TaskMapper.toEntity(TaskModel.fromJson(response.data)); // Use mapper here
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      await _apiClient.delete('${ApiEndpoints.tasks}/$taskId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> completeTask(String taskId) async {
    try {
      await _apiClient.patch(
        '${ApiEndpoints.tasks}/$taskId/complete',
        data: {'completed_at': DateTime.now().toIso8601String()},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Task> rescheduleTask(String taskId, DateTime newTime) async {
    try {
      final response = await _apiClient.patch(
        '${ApiEndpoints.tasks}/$taskId/reschedule',
        data: {'scheduled_at': newTime.toIso8601String()},
      );

      return TaskMapper.toEntity(TaskModel.fromJson(response.data)); // Use mapper here
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<DateTime>> getSuggestedTimeSlots(
    Duration duration,
    int energyRequired,
    DateTime preferredDate,
  ) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.suggestedTimeSlots,
        data: {
          'duration': duration.inMinutes,
          'energy_required': energyRequired,
          'preferred_date': preferredDate.toIso8601String(),
        },
      );

      return (response.data['time_slots'] as List)
          .map((slot) => DateTime.parse(slot))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please try again.');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final message = error.response!.data['message'] ?? 'An error occurred';

      switch (statusCode) {
        case 401:
          return Exception('Unauthorized. Please sign in again.');
        case 404:
          return Exception('Task not found.');
        case 422:
          return Exception('Invalid data provided.');
        default:
          return Exception(message);
      }
    }

    return Exception('Network error. Please check your connection.');
  }
}