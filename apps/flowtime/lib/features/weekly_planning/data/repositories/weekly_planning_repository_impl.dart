import 'package:dartz/dartz.dart' as dartz;
import 'package:logging/logging.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/weekly_planning_data.dart';
import '../../domain/entities/weekly_stats.dart';
import '../../domain/repositories/weekly_planning_repository.dart';
import '../../domain/usecases/optimize_weekly_schedule.dart';
import '../../../timeline/domain/entities/task.dart';
import '../datasources/weekly_planning_local_datasource.dart';
import '../datasources/weekly_planning_remote_datasource.dart';
import '../models/optimization_request_model.dart';
import '../models/batch_reschedule_request_model.dart';
import '../../../timeline/data/mappers/task_mapper.dart';

class WeeklyPlanningRepositoryImpl implements WeeklyPlanningRepository {
  final WeeklyPlanningRemoteDataSource _remoteDataSource;
  final WeeklyPlanningLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final _logger = Logger('WeeklyPlanningRepositoryImpl');

  WeeklyPlanningRepositoryImpl({
    required WeeklyPlanningRemoteDataSource remoteDataSource,
    required WeeklyPlanningLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  @override
  Future<dartz.Either<Failure, WeeklyPlanningData>> getWeeklySchedule(
    DateTime weekStart,
  ) async {
    _logger.info('Getting weekly schedule for week starting: $weekStart');

    try {
      // Check network connectivity
      if (await _networkInfo.isConnected) {
        _logger.fine('Network available, fetching from remote');
        
        try {
          // Fetch from remote
          final remoteData = await _remoteDataSource.getWeeklySchedule(weekStart);
          
          // Cache the data
          await _localDataSource.cacheWeeklySchedule(remoteData);
          _logger.fine('Remote data cached successfully');
          
          return dartz.Right(remoteData.toEntity());
        } on ServerException catch (e) {
          _logger.warning('Server exception, attempting to use cache: $e');
          
          // Try to get cached data on server error
          final cachedData = await _localDataSource.getCachedWeeklySchedule(weekStart);
          if (cachedData != null) {
            _logger.info('Using cached data due to server error');
            return dartz.Right(cachedData.toEntity());
          }
          
          return dartz.Left(ServerFailure(e.message));
        } on UnauthorizedException {
          _logger.severe('Unauthorized access');
          return const dartz.Left(UnauthorizedFailure());
        }
      } else {
        _logger.info('No network connection, using cache');
        
        // No network, try cache
        final cachedData = await _localDataSource.getCachedWeeklySchedule(weekStart);
        if (cachedData != null) {
          _logger.info('Returning cached data');
          return dartz.Right(cachedData.toEntity());
        } else {
          _logger.warning('No cached data available offline');
          return const dartz.Left(NetworkFailure('No internet connection and no cached data'));
        }
      }
    } catch (e, stack) {
      _logger.severe('Unexpected error getting weekly schedule', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<dartz.Either<Failure, Task>> rescheduleTask(
    String taskId,
    DateTime newScheduledTime,
  ) async {
    _logger.info('Rescheduling task $taskId to $newScheduledTime');

    if (!await _networkInfo.isConnected) {
      _logger.warning('Cannot reschedule task offline');
      return const dartz.Left(NetworkFailure('Internet connection required to reschedule tasks'));
    }

    try {
      final taskModel = await _remoteDataSource.rescheduleTask(taskId, newScheduledTime);
      
      // Clear cache for the affected week to force refresh
      final weekStart = _getStartOfWeek(newScheduledTime);
      await _localDataSource.clearWeeklyCache(weekStart);
      
      _logger.info('Task rescheduled successfully');
      return dartz.Right(TaskMapper.toEntity(taskModel));
    } on ServerException catch (e) {
      _logger.severe('Server error rescheduling task: $e');
      return dartz.Left(ServerFailure(e.message));
    } on ConflictException catch (e) {
      _logger.warning('Scheduling conflict detected: $e');
      return dartz.Left(ConflictFailure(e.message));
    } on UnauthorizedException {
      _logger.severe('Unauthorized access');
      return const dartz.Left(UnauthorizedFailure());
    } catch (e, stack) {
      _logger.severe('Unexpected error rescheduling task', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<dartz.Either<Failure, List<Task>>> batchReschedule(
    Map<String, DateTime> taskSchedules,
  ) async {
    _logger.info('Batch rescheduling ${taskSchedules.length} tasks');

    if (!await _networkInfo.isConnected) {
      _logger.warning('Cannot batch reschedule offline');
      return const dartz.Left(NetworkFailure('Internet connection required for batch operations'));
    }

    try {
      final request = BatchRescheduleRequestModel(
        taskSchedules: taskSchedules,
        validateConflicts: true,
      );
      
      final taskModels = await _remoteDataSource.batchReschedule(request);
      
      // Clear cache for all affected weeks
      final affectedWeeks = taskSchedules.values
          .map((date) => _getStartOfWeek(date))
          .toSet();
      
      for (final weekStart in affectedWeeks) {
        await _localDataSource.clearWeeklyCache(weekStart);
      }
      
      _logger.info('Batch reschedule completed successfully');
      return dartz.Right(taskModels.map((model) => model as Task).toList());
    } on ServerException catch (e) {
      _logger.severe('Server error in batch reschedule: $e');
      return dartz.Left(ServerFailure(e.message));
    } on ConflictException catch (e) {
      _logger.warning('Conflicts detected in batch reschedule: $e');
      return dartz.Left(ConflictFailure(e.message));
    } catch (e, stack) {
      _logger.severe('Unexpected error in batch reschedule', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<dartz.Either<Failure, WeeklyPlanningData>> optimizeWeeklySchedule(
    DateTime weekStart,
  ) async {
    _logger.info('Optimizing weekly schedule for week starting: $weekStart');

    if (!await _networkInfo.isConnected) {
      _logger.warning('Cannot optimize schedule offline');
      return const dartz.Left(NetworkFailure('Internet connection required for optimization'));
    }

    try {
      final request = OptimizationRequestModel(
        weekStart: weekStart,
        preferences: const OptimizationPreferences(),
      );
      
      final optimizedData = await _remoteDataSource.optimizeWeeklySchedule(request);
      
      // Cache the optimized schedule
      await _localDataSource.cacheWeeklySchedule(optimizedData);
      
      _logger.info('Schedule optimization completed');
      return dartz.Right(optimizedData.toEntity());
    } on ServerException catch (e) {
      _logger.severe('Server error optimizing schedule: $e');
      return dartz.Left(ServerFailure(e.message));
    } on UnauthorizedException {
      _logger.severe('Unauthorized access');
      return const dartz.Left(UnauthorizedFailure());
    } catch (e, stack) {
      _logger.severe('Unexpected error optimizing schedule', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<dartz.Either<Failure, WeeklyStats>> getWeeklyStats(DateTime weekStart) async {
    _logger.info('Getting weekly stats for week starting: $weekStart');

    try {
      if (await _networkInfo.isConnected) {
        _logger.fine('Fetching stats from remote');
        
        try {
          final stats = await _remoteDataSource.getWeeklyStats(weekStart);
          
          // Cache the stats
          await _localDataSource.cacheWeeklyStats(weekStart, stats);
          
          return dartz.Right(stats.toEntity());
        } on ServerException catch (e) {
          _logger.warning('Server error, trying cache: $e');
          
          // Try cache on error
          final cachedStats = await _localDataSource.getCachedWeeklyStats(weekStart);
          if (cachedStats != null) {
            return dartz.Right(cachedStats.toEntity());
          }
          
          return dartz.Left(ServerFailure(e.message));
        }
      } else {
        _logger.info('Offline, using cached stats');
        
        // Use cache when offline
        final cachedStats = await _localDataSource.getCachedWeeklyStats(weekStart);
        if (cachedStats != null) {
          return dartz.Right(cachedStats.toEntity());
        } else {
          return const dartz.Left(NetworkFailure('No internet connection and no cached stats'));
        }
      }
    } catch (e, stack) {
      _logger.severe('Unexpected error getting weekly stats', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<dartz.Either<Failure, Map<int, Map<int, int>>>> getWeeklyEnergyPredictions(
    DateTime weekStart,
  ) async {
    _logger.info('Getting energy predictions for week starting: $weekStart');

    try {
      if (await _networkInfo.isConnected) {
        _logger.fine('Fetching energy predictions from remote');
        
        try {
          final predictions = await _remoteDataSource.getWeeklyEnergyPredictions(weekStart);
          
          // Cache the predictions
          await _localDataSource.cacheEnergyPredictions(weekStart, predictions);
          
          return dartz.Right(predictions);
        } on ServerException catch (e) {
          _logger.warning('Server error, trying cache: $e');
          
          // Try cache on error
          final cachedPredictions = await _localDataSource.getCachedEnergyPredictions(weekStart);
          if (cachedPredictions != null) {
            return dartz.Right(cachedPredictions);
          }
          
          return dartz.Left(ServerFailure(e.message));
        }
      } else {
        _logger.info('Offline, using cached predictions');
        
        // Use cache when offline
        final cachedPredictions = await _localDataSource.getCachedEnergyPredictions(weekStart);
        if (cachedPredictions != null) {
          return dartz.Right(cachedPredictions);
        } else {
          // Return default predictions when offline with no cache
          _logger.info('No cached predictions, generating defaults');
          return dartz.Right(_generateDefaultPredictions());
        }
      }
    } catch (e, stack) {
      _logger.severe('Unexpected error getting energy predictions', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<dartz.Either<Failure, bool>> validateTaskPlacement(
    String taskId,
    DateTime proposedTime,
  ) async {
    _logger.info('Validating task placement for $taskId at $proposedTime');

    if (!await _networkInfo.isConnected) {
      _logger.warning('Cannot validate placement offline, assuming valid');
      // When offline, optimistically assume placement is valid
      return const dartz.Right(true);
    }

    try {
      final isValid = await _remoteDataSource.validateTaskPlacement(taskId, proposedTime);
      
      _logger.fine('Placement validation result: $isValid');
      return dartz.Right(isValid);
    } on ServerException catch (e) {
      _logger.severe('Server error validating placement: $e');
      // On server error, optimistically assume valid to not block user
      return const dartz.Right(true);
    } catch (e, stack) {
      _logger.severe('Unexpected error validating placement', e, stack);
      // On unexpected error, optimistically assume valid
      return const dartz.Right(true);
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  Map<int, Map<int, int>> _generateDefaultPredictions() {
    _logger.fine('Generating default energy predictions');
    
    final predictions = <int, Map<int, int>>{};
    
    for (int day = 0; day < 7; day++) {
      predictions[day] = {};
      
      for (int hour = 0; hour < 24; hour++) {
        // Simple default pattern
        int energy = 50;
        
        if (hour >= 9 && hour <= 11) {
          energy = 75; // Morning peak
        } else if (hour >= 14 && hour <= 16) {
          energy = 45; // Afternoon dip
        } else if (hour >= 17 && hour <= 19) {
          energy = 65; // Evening recovery
        } else if (hour < 6 || hour > 22) {
          energy = 30; // Night time
        }
        
        predictions[day]![hour] = energy;
      }
    }
    
    return predictions;
  }
}