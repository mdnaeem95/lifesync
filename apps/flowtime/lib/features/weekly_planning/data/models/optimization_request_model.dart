import 'package:logging/logging.dart';
import '../../domain/usecases/optimize_weekly_schedule.dart';

class OptimizationRequestModel {
  final DateTime weekStart;
  final OptimizationPreferences preferences;
  final List<String> lockedTaskIds;
  final Map<String, dynamic> constraints;
  final _logger = Logger('OptimizationRequestModel');

  OptimizationRequestModel({
    required this.weekStart,
    required this.preferences,
    this.lockedTaskIds = const [],
    this.constraints = const {},
  });

  Map<String, dynamic> toJson() {
    _logger.fine('Creating optimization request JSON');
    
    return {
      'week_start': weekStart.toIso8601String(),
      'preferences': {
        'prioritize_energy_alignment': preferences.prioritizeEnergyAlignment,
        'minimize_switching': preferences.minimizeSwitching,
        'protect_breaks': preferences.protectBreaks,
        'batch_similar_tasks': preferences.batchSimilarTasks,
        'max_daily_focus_hours': preferences.maxDailyFocusHours,
        'min_break_duration': preferences.minBreakDuration,
      },
      'locked_task_ids': lockedTaskIds,
      'constraints': constraints,
    };
  }
}