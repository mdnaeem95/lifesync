import 'package:logging/logging.dart';

class BatchRescheduleRequestModel {
  final Map<String, DateTime> taskSchedules;
  final bool validateConflicts;
  final bool preserveOrder;
  final _logger = Logger('BatchRescheduleRequestModel');

  BatchRescheduleRequestModel({
    required this.taskSchedules,
    this.validateConflicts = true,
    this.preserveOrder = false,
  });

  Map<String, dynamic> toJson() {
    _logger.fine('Creating batch reschedule request JSON for ${taskSchedules.length} tasks');
    
    final schedulesJson = <String, String>{};
    taskSchedules.forEach((taskId, dateTime) {
      schedulesJson[taskId] = dateTime.toIso8601String();
    });
    
    return {
      'task_schedules': schedulesJson,
      'validate_conflicts': validateConflicts,
      'preserve_order': preserveOrder,
    };
  }
}