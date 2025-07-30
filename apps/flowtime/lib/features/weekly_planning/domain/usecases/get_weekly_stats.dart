import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/weekly_stats.dart';
import '../repositories/weekly_planning_repository.dart';

class GetWeeklyStats implements UseCase<WeeklyStats, GetWeeklyStatsParams> {
  final WeeklyPlanningRepository repository;
  final _logger = Logger('GetWeeklyStats');

  GetWeeklyStats(this.repository);

  @override
  Future<Either<Failure, WeeklyStats>> call(GetWeeklyStatsParams params) async {
    _logger.info('Getting weekly stats for week starting: ${params.weekStart}');
    
    try {
      final result = await repository.getWeeklyStats(params.weekStart);
      
      result.fold(
        (failure) => _logger.severe('Failed to get weekly stats: $failure'),
        (stats) {
          _logger.info('Weekly stats retrieved successfully');
          _logger.fine('Total tasks: ${stats.totalTasks}, Completed: ${stats.completedTasks}');
          _logger.fine('Completion rate: ${stats.completionRate}%');
        },
      );
      
      return result;
    } catch (e, stack) {
      _logger.severe('Unexpected error getting weekly stats', e, stack);
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}

class GetWeeklyStatsParams extends Equatable {
  final DateTime weekStart;
  final bool includeInsights;

  const GetWeeklyStatsParams({
    required this.weekStart,
    this.includeInsights = true,
  });

  @override
  List<Object> get props => [weekStart, includeInsights];
}