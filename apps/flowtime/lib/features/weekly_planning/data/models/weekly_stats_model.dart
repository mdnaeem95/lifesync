import 'package:logging/logging.dart';
import '../../domain/entities/weekly_stats.dart';

class WeeklyStatsModel extends WeeklyStats {
  static final _logger = Logger('WeeklyStatsModel');

  const WeeklyStatsModel({
    required super.totalTasks,
    required super.completedTasks,
    required super.totalFocusMinutes,
    required super.totalMeetingMinutes,
    required super.totalBreakMinutes,
    required super.averageEnergyLevel,
    required super.completionRate,
    required super.optimalTaskPlacement,
    required super.tasksByType,
    required super.tasksByDay,
    required super.insights,
  });

  factory WeeklyStatsModel.fromJson(Map<String, dynamic> json) {
    final logger = Logger('WeeklyStatsModel.fromJson');
    logger.fine('Parsing weekly stats from JSON');
    
    try {
      // Parse insights
      final insightsJson = json['insights'] as List<dynamic>? ?? [];
      final insights = insightsJson.map((insightJson) {
        return ProductivityInsightModel.fromJson(insightJson as Map<String, dynamic>);
      }).toList();
      logger.fine('Parsed ${insights.length} productivity insights');
      
      // Parse tasks by type
      final tasksByTypeJson = json['tasks_by_type'] as Map<String, dynamic>? ?? {};
      final tasksByType = <String, int>{};
      tasksByTypeJson.forEach((type, count) {
        tasksByType[type] = count as int;
      });
      
      // Parse tasks by day
      final tasksByDayJson = json['tasks_by_day'] as Map<String, dynamic>? ?? {};
      final tasksByDay = <int, int>{};
      tasksByDayJson.forEach((dayStr, count) {
        tasksByDay[int.parse(dayStr)] = count as int;
      });
      
      return WeeklyStatsModel(
        totalTasks: json['total_tasks'] as int,
        completedTasks: json['completed_tasks'] as int,
        totalFocusMinutes: json['total_focus_minutes'] as int,
        totalMeetingMinutes: json['total_meeting_minutes'] as int,
        totalBreakMinutes: json['total_break_minutes'] as int,
        averageEnergyLevel: (json['average_energy_level'] as num).toDouble(),
        completionRate: (json['completion_rate'] as num).toDouble(),
        optimalTaskPlacement: (json['optimal_task_placement'] as num).toDouble(),
        tasksByType: tasksByType,
        tasksByDay: tasksByDay,
        insights: insights,
      );
    } catch (e, stack) {
      logger.severe('Error parsing weekly stats', e, stack);
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    _logger.fine('Converting weekly stats to JSON');
    
    try {
      // Convert tasks by day to JSON-friendly format
      final tasksByDayJson = <String, dynamic>{};
      tasksByDay.forEach((day, count) {
        tasksByDayJson[day.toString()] = count;
      });
      
      final json = {
        'total_tasks': totalTasks,
        'completed_tasks': completedTasks,
        'total_focus_minutes': totalFocusMinutes,
        'total_meeting_minutes': totalMeetingMinutes,
        'total_break_minutes': totalBreakMinutes,
        'average_energy_level': averageEnergyLevel,
        'completion_rate': completionRate,
        'optimal_task_placement': optimalTaskPlacement,
        'tasks_by_type': tasksByType,
        'tasks_by_day': tasksByDayJson,
        'insights': insights.map((insight) => 
          ProductivityInsightModel.fromEntity(insight).toJson()
        ).toList(),
      };
      
      _logger.fine('Successfully converted to JSON');
      return json;
    } catch (e, stack) {
      _logger.severe('Error converting to JSON', e, stack);
      rethrow;
    }
  }

  WeeklyStats toEntity() => this;
}

class ProductivityInsightModel extends ProductivityInsight {
  const ProductivityInsightModel({
    required super.id,
    required super.title,
    required super.description,
    required super.type,
    required super.priority,
    super.actionableAdvice,
  });

  factory ProductivityInsightModel.fromJson(Map<String, dynamic> json) {
    return ProductivityInsightModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: InsightType.values.firstWhere(
        (type) => type.name == json['type'],
      ),
      priority: InsightPriority.values.firstWhere(
        (priority) => priority.name == json['priority'],
      ),
      actionableAdvice: json['actionable_advice'] as String?,
    );
  }

  factory ProductivityInsightModel.fromEntity(ProductivityInsight entity) {
    return ProductivityInsightModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      type: entity.type,
      priority: entity.priority,
      actionableAdvice: entity.actionableAdvice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'priority': priority.name,
      'actionable_advice': actionableAdvice,
    };
  }
}