import 'package:dartz/dartz.dart' as dartz;
import '../../../../core/errors/failures.dart';
import '../entities/weekly_planning_data.dart';
import '../entities/weekly_stats.dart';
import '../../../timeline/domain/entities/task.dart';

abstract class WeeklyPlanningRepository {
  Future<dartz.Either<Failure, WeeklyPlanningData>> getWeeklySchedule(
    DateTime weekStart,
  );
  
  Future<dartz.Either<Failure, Task>> rescheduleTask(
    String taskId,
    DateTime newScheduledTime,
  );
  
  Future<dartz.Either<Failure, List<Task>>> batchReschedule(
    Map<String, DateTime> taskSchedules,
  );
  
  Future<dartz.Either<Failure, WeeklyPlanningData>> optimizeWeeklySchedule(
    DateTime weekStart,
  );
  
  Future<dartz.Either<Failure, WeeklyStats>> getWeeklyStats(
    DateTime weekStart,
  );
  
  Future<dartz.Either<Failure, Map<int, Map<int, int>>>> getWeeklyEnergyPredictions(
    DateTime weekStart,
  );
  
  Future<dartz.Either<Failure, bool>> validateTaskPlacement(
    String taskId,
    DateTime proposedTime,
  );
}
