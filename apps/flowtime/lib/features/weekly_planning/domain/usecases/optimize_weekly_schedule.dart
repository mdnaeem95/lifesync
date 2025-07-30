import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/weekly_planning_data.dart';
import '../repositories/weekly_planning_repository.dart';

class OptimizeWeeklySchedule implements UseCase<WeeklyPlanningData, OptimizeWeeklyScheduleParams> {
  final WeeklyPlanningRepository repository;
  final _logger = Logger('OptimizeWeeklySchedule');

  OptimizeWeeklySchedule(this.repository);

  @override
  Future<Either<Failure, WeeklyPlanningData>> call(OptimizeWeeklyScheduleParams params) async {
    _logger.info('Optimizing weekly schedule for week starting: ${params.weekStart}');
    _logger.fine('Optimization preferences: ${params.preferences}');
    
    try {
      final result = await repository.optimizeWeeklySchedule(params.weekStart);
      
      result.fold(
        (failure) => _logger.severe('Failed to optimize weekly schedule: $failure'),
        (data) {
          _logger.info('Schedule optimized successfully');
          _logger.fine('Optimization moved ${_countRescheduledTasks(data)} tasks');
        },
      );
      
      return result;
    } catch (e, stack) {
      _logger.severe('Unexpected error optimizing schedule', e, stack);
      return Left(UnexpectedFailure(e.toString()));
    }
  }
  
  int _countRescheduledTasks(WeeklyPlanningData data) {
    // In a real implementation, this would compare before/after states
    return data.tasks.where((task) => task.isFlexible).length;
  }
}

class OptimizeWeeklyScheduleParams extends Equatable {
  final DateTime weekStart;
  final OptimizationPreferences preferences;

  const OptimizeWeeklyScheduleParams({
    required this.weekStart,
    this.preferences = const OptimizationPreferences(),
  });

  @override
  List<Object> get props => [weekStart, preferences];
}

class OptimizationPreferences extends Equatable {
  final bool prioritizeEnergyAlignment;
  final bool minimizeSwitching;
  final bool protectBreaks;
  final bool batchSimilarTasks;
  final int maxDailyFocusHours;
  final int minBreakDuration;

  const OptimizationPreferences({
    this.prioritizeEnergyAlignment = true,
    this.minimizeSwitching = true,
    this.protectBreaks = true,
    this.batchSimilarTasks = false,
    this.maxDailyFocusHours = 6,
    this.minBreakDuration = 15,
  });

  @override
  List<Object> get props => [
        prioritizeEnergyAlignment,
        minimizeSwitching,
        protectBreaks,
        batchSimilarTasks,
        maxDailyFocusHours,
        minBreakDuration,
      ];
}