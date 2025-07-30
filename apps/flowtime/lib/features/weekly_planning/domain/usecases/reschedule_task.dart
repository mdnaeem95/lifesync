import 'package:dartz/dartz.dart' as dartz;
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../timeline/domain/entities/task.dart';
import '../repositories/weekly_planning_repository.dart';
class RescheduleTask implements UseCase<Task, RescheduleTaskParams> {
  final WeeklyPlanningRepository repository;
  final _logger = Logger('RescheduleTask');

  RescheduleTask(this.repository);

  @override
  Future<dartz.Either<Failure, Task>> call(RescheduleTaskParams params) async {
    _logger.info('Rescheduling task ${params.taskId} to ${params.newScheduledTime}');
    
    try {
      // First validate the placement
      final validationResult = await repository.validateTaskPlacement(
        params.taskId,
        params.newScheduledTime,
      );
      
      return validationResult.fold(
        (failure) {
          _logger.warning('Task placement validation failed: $failure');
          return dartz.Left(failure);
        },
        (isValid) async {
          if (!isValid) {
            _logger.warning('Task placement is invalid (conflicts detected)');
            return dartz.Left(ValidationFailure('Task conflicts with existing schedule'));
          }
          
          final result = await repository.rescheduleTask(
            params.taskId,
            params.newScheduledTime,
          );
          
          result.fold(
            (failure) => _logger.severe('Failed to reschedule task: $failure'),
            (task) => _logger.info('Task rescheduled successfully'),
          );
          
          return result;
        },
      );
    } catch (e, stack) {
      _logger.severe('Unexpected error rescheduling task', e, stack);
      return dartz.Left(UnexpectedFailure(e.toString()));
    }
  }
}

class RescheduleTaskParams extends Equatable {
  final String taskId;
  final DateTime newScheduledTime;

  const RescheduleTaskParams({
    required this.taskId,
    required this.newScheduledTime,
  });

  @override
  List<Object> get props => [taskId, newScheduledTime];
}