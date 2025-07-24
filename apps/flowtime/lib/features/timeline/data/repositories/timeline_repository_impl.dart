import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/timeline_repository.dart';
import '../models/task_model.dart';
import '../mappers/task_mapper.dart';

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

      // Handle empty response
      if (response.data == null) {
        return [];
      }

      // Handle response data safely
      final responseData = response.data;
      if (responseData is List) {
        return responseData
            .map((json) => TaskModel.fromJson(json))
            .map((model) => TaskMapper.toEntity(model))
            .toList();
      } else if (responseData is Map && responseData.containsKey('tasks')) {
        // Handle wrapped response
        final tasksList = responseData['tasks'] as List;
        return tasksList
            .map((json) => TaskModel.fromJson(json))
            .map((model) => TaskMapper.toEntity(model))
            .toList();
      } else {
        // Return empty list if response format is unexpected
        return [];
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Task> createTask(Task task) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.tasks,
        data: TaskMapper.fromEntity(task).toJson(),
      );

      return TaskMapper.toEntity(TaskModel.fromJson(response.data));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Task> updateTask(String taskId, Task task) async {
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.tasks}/$taskId',
        data: TaskMapper.fromEntity(task).toJson(),
      );

      return TaskMapper.toEntity(TaskModel.fromJson(response.data));
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
  Future<void> toggleTaskComplete(String taskId) async {
    try {
      await _apiClient.patch(
        '${ApiEndpoints.tasks}/$taskId/toggle-complete',
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

      return TaskMapper.toEntity(TaskModel.fromJson(response.data));
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
    // Handle connection errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please try again.');
    }

    if (error.type == DioExceptionType.connectionError) {
      return Exception('Unable to connect to server. Please check your internet connection.');
    }

    // Handle response errors
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      
      // Safely extract error message
      String message = 'An error occurred';
      final responseData = error.response!.data;
      
      if (responseData != null) {
        if (responseData is Map) {
          // Try different possible message fields
          message = responseData['message']?.toString() ?? 
                   responseData['error']?.toString() ?? 
                   responseData['detail']?.toString() ?? 
                   'Server error';
        } else if (responseData is String) {
          message = responseData;
        }
      }

      switch (statusCode) {
        case 401:
          return Exception('Session expired. Please sign in again.');
        case 403:
          return Exception('You don\'t have permission to perform this action.');
        case 404:
          return Exception('Resource not found.');
        case 422:
          return Exception('Invalid data provided. Please check your input.');
        case 500:
          return Exception('Server error. Please try again later.');
        default:
          return Exception(message);
      }
    }

    // Default error
    return Exception('Network error. Please check your connection.');
  }
}