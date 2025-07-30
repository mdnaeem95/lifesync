import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/weekly_planning_data_model.dart';
import '../models/weekly_stats_model.dart';
import '../models/optimization_request_model.dart';
import '../models/batch_reschedule_request_model.dart';
import '../../../timeline/data/models/task_model.dart';

abstract class WeeklyPlanningRemoteDataSource {
  Future<WeeklyPlanningDataModel> getWeeklySchedule(DateTime weekStart);
  Future<TaskModel> rescheduleTask(String taskId, DateTime newScheduledTime);
  Future<List<TaskModel>> batchReschedule(BatchRescheduleRequestModel request);
  Future<WeeklyPlanningDataModel> optimizeWeeklySchedule(OptimizationRequestModel request);
  Future<WeeklyStatsModel> getWeeklyStats(DateTime weekStart);
  Future<Map<int, Map<int, int>>> getWeeklyEnergyPredictions(DateTime weekStart);
  Future<bool> validateTaskPlacement(String taskId, DateTime proposedTime);
}

class WeeklyPlanningRemoteDataSourceImpl implements WeeklyPlanningRemoteDataSource {
  final ApiClient _apiClient;
  final _logger = Logger('WeeklyPlanningRemoteDataSource');

  WeeklyPlanningRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<WeeklyPlanningDataModel> getWeeklySchedule(DateTime weekStart) async {
    _logger.info('Fetching weekly schedule from API for week starting: $weekStart');
    
    try {
      final response = await _apiClient.get(
        '${ApiConstants.weeklyPlanningEndpoint}/schedule',
        queryParameters: {
          'week_start': weekStart.toIso8601String(),
        },
      );
      
      _logger.fine('Received weekly schedule response');
      
      if (response.statusCode == 200) {
        final data = WeeklyPlanningDataModel.fromJson(response.data);
        _logger.info('Successfully parsed weekly schedule with ${data.tasks.length} tasks');
        return data;
      } else {
        _logger.severe('Failed to fetch weekly schedule: ${response.statusCode}');
        throw ServerException('Failed to fetch weekly schedule');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while fetching weekly schedule', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error fetching weekly schedule', e, stack);
      throw ServerException('Failed to fetch weekly schedule: $e');
    }
  }

  @override
  Future<TaskModel> rescheduleTask(String taskId, DateTime newScheduledTime) async {
    _logger.info('Rescheduling task $taskId to $newScheduledTime');
    
    try {
      final response = await _apiClient.patch(
        '${ApiConstants.tasksEndpoint}/$taskId/reschedule',
        data: {
          'scheduled_at': newScheduledTime.toIso8601String(),
        },
      );
      
      if (response.statusCode == 200) {
        final task = TaskModel.fromJson(response.data);
        _logger.info('Task rescheduled successfully');
        return task;
      } else {
        _logger.severe('Failed to reschedule task: ${response.statusCode}');
        throw ServerException('Failed to reschedule task');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while rescheduling task', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error rescheduling task', e, stack);
      throw ServerException('Failed to reschedule task: $e');
    }
  }

  @override
  Future<List<TaskModel>> batchReschedule(BatchRescheduleRequestModel request) async {
    _logger.info('Batch rescheduling ${request.taskSchedules.length} tasks');
    
    try {
      final response = await _apiClient.post(
        '${ApiConstants.weeklyPlanningEndpoint}/batch-reschedule',
        data: request.toJson(),
      );
      
      if (response.statusCode == 200) {
        final tasksJson = response.data['tasks'] as List<dynamic>;
        final tasks = tasksJson.map((json) => 
          TaskModel.fromJson(json as Map<String, dynamic>)
        ).toList();
        
        _logger.info('Batch reschedule completed successfully');
        return tasks;
      } else {
        _logger.severe('Failed to batch reschedule: ${response.statusCode}');
        throw ServerException('Failed to batch reschedule tasks');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while batch rescheduling', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error batch rescheduling', e, stack);
      throw ServerException('Failed to batch reschedule: $e');
    }
  }

  @override
  Future<WeeklyPlanningDataModel> optimizeWeeklySchedule(
    OptimizationRequestModel request,
  ) async {
    _logger.info('Requesting weekly schedule optimization');
    _logger.fine('Optimization preferences: ${request.toJson()}');
    
    try {
      final response = await _apiClient.post(
        '${ApiConstants.weeklyPlanningEndpoint}/optimize',
        data: request.toJson(),
      );
      
      if (response.statusCode == 200) {
        final data = WeeklyPlanningDataModel.fromJson(response.data);
        _logger.info('Schedule optimization completed');
        _logger.fine('Optimized schedule contains ${data.tasks.length} tasks');
        return data;
      } else {
        _logger.severe('Failed to optimize schedule: ${response.statusCode}');
        throw ServerException('Failed to optimize schedule');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while optimizing schedule', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error optimizing schedule', e, stack);
      throw ServerException('Failed to optimize schedule: $e');
    }
  }

  @override
  Future<WeeklyStatsModel> getWeeklyStats(DateTime weekStart) async {
    _logger.info('Fetching weekly stats for week starting: $weekStart');
    
    try {
      final response = await _apiClient.get(
        '${ApiConstants.weeklyPlanningEndpoint}/stats',
        queryParameters: {
          'week_start': weekStart.toIso8601String(),
        },
      );
      
      if (response.statusCode == 200) {
        final stats = WeeklyStatsModel.fromJson(response.data);
        _logger.info('Weekly stats retrieved successfully');
        _logger.fine('Stats: ${stats.totalTasks} tasks, ${stats.completionRate}% completion');
        return stats;
      } else {
        _logger.severe('Failed to fetch weekly stats: ${response.statusCode}');
        throw ServerException('Failed to fetch weekly stats');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while fetching weekly stats', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error fetching weekly stats', e, stack);
      throw ServerException('Failed to fetch weekly stats: $e');
    }
  }

  @override
  Future<Map<int, Map<int, int>>> getWeeklyEnergyPredictions(DateTime weekStart) async {
    _logger.info('Fetching energy predictions for week starting: $weekStart');
    
    try {
      final response = await _apiClient.get(
        '${ApiConstants.energyEndpoint}/predictions/weekly',
        queryParameters: {
          'week_start': weekStart.toIso8601String(),
        },
      );
      
      if (response.statusCode == 200) {
        final predictions = <int, Map<int, int>>{};
        final data = response.data['predictions'] as Map<String, dynamic>;
        
        data.forEach((dayStr, hoursData) {
          final day = int.parse(dayStr);
          final hours = <int, int>{};
          
          (hoursData as Map<String, dynamic>).forEach((hourStr, energy) {
            hours[int.parse(hourStr)] = energy as int;
          });
          
          predictions[day] = hours;
        });
        
        _logger.info('Energy predictions retrieved for ${predictions.length} days');
        return predictions;
      } else {
        _logger.severe('Failed to fetch energy predictions: ${response.statusCode}');
        throw ServerException('Failed to fetch energy predictions');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while fetching energy predictions', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error fetching energy predictions', e, stack);
      throw ServerException('Failed to fetch energy predictions: $e');
    }
  }

  @override
  Future<bool> validateTaskPlacement(String taskId, DateTime proposedTime) async {
    _logger.info('Validating task placement for $taskId at $proposedTime');
    
    try {
      final response = await _apiClient.post(
        '${ApiConstants.weeklyPlanningEndpoint}/validate-placement',
        data: {
          'task_id': taskId,
          'proposed_time': proposedTime.toIso8601String(),
        },
      );
      
      if (response.statusCode == 200) {
        final isValid = response.data['is_valid'] as bool;
        final conflicts = response.data['conflicts'] as List<dynamic>?;
        
        if (!isValid && conflicts != null && conflicts.isNotEmpty) {
          _logger.warning('Task placement invalid - conflicts with ${conflicts.length} tasks');
        } else {
          _logger.info('Task placement is valid');
        }
        
        return isValid;
      } else {
        _logger.severe('Failed to validate task placement: ${response.statusCode}');
        throw ServerException('Failed to validate task placement');
      }
    } on DioException catch (e) {
      _logger.severe('DioException while validating task placement', e);
      _handleDioError(e);
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error validating task placement', e, stack);
      throw ServerException('Failed to validate task placement: $e');
    }
  }

  void _handleDioError(DioException error) {
    _logger.severe('DioError Type: ${error.type}');
    _logger.severe('DioError Message: ${error.message}');
    
    if (error.response != null) {
      _logger.severe('Response Status: ${error.response?.statusCode}');
      _logger.severe('Response Data: ${error.response?.data}');
    }
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw ServerException('Request timeout');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          throw UnauthorizedException();
        } else if (statusCode == 404) {
          throw NotFoundException();
        } else if (statusCode == 409) {
          throw ConflictException(error.response?.data['message'] ?? 'Conflict occurred');
        }
        throw ServerException('Server error: $statusCode');
      case DioExceptionType.cancel:
        throw ServerException('Request cancelled');
      default:
        throw ServerException('Network error occurred');
    }
  }
}