import 'package:logging/logging.dart';
import '../../domain/entities/weekly_planning_data.dart';
import '../../../timeline/data/models/task_model.dart';
import '../../../timeline/data/mappers/task_mapper.dart';

class WeeklyPlanningDataModel extends WeeklyPlanningData {
  static final _logger = Logger('WeeklyPlanningDataModel');

  const WeeklyPlanningDataModel({
    required super.weekStartDate,
    required super.weekEndDate,
    required super.tasks,
    required super.energyPredictions,
    super.taskConflicts,
    super.isOptimized,
    required super.lastUpdated,
  });

  factory WeeklyPlanningDataModel.fromJson(Map<String, dynamic> json) {
    final logger = Logger('WeeklyPlanningDataModel.fromJson');
    logger.fine('Parsing weekly planning data from JSON');
    
    try {
      // Parse tasks
      final tasksJson = json['tasks'] as List<dynamic>? ?? [];
      final tasks = tasksJson.map((taskJson) {
        final model = TaskModel.fromJson(taskJson as Map<String, dynamic>);
        return TaskMapper.toEntity(model); // Convert each TaskModel to Task
      }).toList();
      logger.fine('Parsed ${tasks.length} tasks');
      
      // Parse energy predictions
      final energyJson = json['energy_predictions'] as Map<String, dynamic>? ?? {};
      final energyPredictions = <int, Map<int, int>>{};
      
      energyJson.forEach((dayStr, hoursData) {
        final day = int.parse(dayStr);
        final hours = <int, int>{};
        
        (hoursData as Map<String, dynamic>).forEach((hourStr, energy) {
          hours[int.parse(hourStr)] = energy as int;
        });
        
        energyPredictions[day] = hours;
      });
      logger.fine('Parsed energy predictions for ${energyPredictions.length} days');
      
      // Parse task conflicts
      final conflictsJson = json['task_conflicts'] as Map<String, dynamic>? ?? {};
      final taskConflicts = <String, List<String>>{};
      
      conflictsJson.forEach((taskId, conflicts) {
        taskConflicts[taskId] = List<String>.from(conflicts as List);
      });
      
      if (taskConflicts.isNotEmpty) {
        logger.warning('Found ${taskConflicts.length} tasks with conflicts');
      }
      
      return WeeklyPlanningDataModel(
        weekStartDate: DateTime.parse(json['week_start_date'] as String),
        weekEndDate: DateTime.parse(json['week_end_date'] as String),
        tasks: tasks,
        energyPredictions: energyPredictions,
        taskConflicts: taskConflicts,
        isOptimized: json['is_optimized'] as bool? ?? false,
        lastUpdated: DateTime.parse(json['last_updated'] as String),
      );
    } catch (e, stack) {
      logger.severe('Error parsing weekly planning data', e, stack);
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    _logger.fine('Converting weekly planning data to JSON');
    
    try {
      // Convert energy predictions to JSON-friendly format
      final energyJson = <String, dynamic>{};
      energyPredictions.forEach((day, hours) {
        final hoursJson = <String, dynamic>{};
        hours.forEach((hour, energy) {
          hoursJson[hour.toString()] = energy;
        });
        energyJson[day.toString()] = hoursJson;
      });
      
      // Convert task conflicts to JSON
      final conflictsJson = <String, dynamic>{};
      taskConflicts.forEach((taskId, conflicts) {
        conflictsJson[taskId] = conflicts;
      });
      
      final json = {
        'week_start_date': weekStartDate.toIso8601String(),
        'week_end_date': weekEndDate.toIso8601String(),
        'tasks': tasks.map((task) => TaskMapper.fromEntity(task).toJson()).toList(),
        'energy_predictions': energyJson,
        'task_conflicts': conflictsJson,
        'is_optimized': isOptimized,
        'last_updated': lastUpdated.toIso8601String(),
      };
      
      _logger.fine('Successfully converted to JSON');
      return json;
    } catch (e, stack) {
      _logger.severe('Error converting to JSON', e, stack);
      rethrow;
    }
  }

  WeeklyPlanningData toEntity() => this;
}