import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/weekly_planning_data.dart';
import '../repositories/weekly_planning_repository.dart';

class LoadWeeklySchedule implements UseCase<WeeklyPlanningData, LoadWeeklyScheduleParams> {
  final WeeklyPlanningRepository repository;
  final _logger = Logger('LoadWeeklySchedule');

  LoadWeeklySchedule(this.repository);

  @override
  Future<Either<Failure, WeeklyPlanningData>> call(LoadWeeklyScheduleParams params) async {
    _logger.info('Loading weekly schedule for week starting: ${params.weekStart}');
    
    try {
      final result = await repository.getWeeklySchedule(params.weekStart);
      
      result.fold(
        (failure) => _logger.severe('Failed to load weekly schedule: $failure'),
        (data) => _logger.info('Loaded ${data.tasks.length} tasks for the week'),
      );
      
      return result;
    } catch (e, stack) {
      _logger.severe('Unexpected error loading weekly schedule', e, stack);
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}

class LoadWeeklyScheduleParams extends Equatable {
  final DateTime weekStart;

  const LoadWeeklyScheduleParams({required this.weekStart});

  @override
  List<Object> get props => [weekStart];
}