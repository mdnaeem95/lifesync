import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../screens/weekly_planning_screen.dart';
import '../../../timeline/domain/entities/task.dart';

final weeklyPlanningProvider = StateNotifierProvider<WeeklyPlanningNotifier, AsyncValue<WeeklyPlanningData>>((ref) {
  return WeeklyPlanningNotifier(ref);
});

class WeeklyPlanningNotifier extends StateNotifier<AsyncValue<WeeklyPlanningData>> {
  final Ref _ref;
  final _logger = Logger('WeeklyPlanningNotifier');
  DateTime _currentWeek = DateTime.now();

  WeeklyPlanningNotifier(this._ref) : super(const AsyncValue.loading()) {
    _logger.info('WeeklyPlanningNotifier initialized');
    loadWeek(DateTime.now());
  }

  Future<void> loadWeek(DateTime weekStart) async {
    _logger.info('Loading week starting: $weekStart');
    state = const AsyncValue.loading();
    
    try {
      // Get the start and end of the week
      final startOfWeek = _getStartOfWeek(weekStart);
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      _logger.fine('Week range: $startOfWeek to $endOfWeek');
      
      // In a real app, this would fetch from the backend
      // For now, we'll generate mock data
      final tasks = await _fetchWeeklyTasks(startOfWeek, endOfWeek);
      final energyPredictions = await _fetchWeeklyEnergyPredictions(startOfWeek);
      
      _logger.info('Loaded ${tasks.length} tasks for the week');
      
      state = AsyncValue.data(WeeklyPlanningData(
        tasks: tasks,
        energyPredictions: energyPredictions,
      ));
      
      _currentWeek = startOfWeek;
    } catch (error, stack) {
      _logger.severe('Error loading weekly data', error, stack);
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> rescheduleTask(Task task, int dayIndex, int hour) async {
    _logger.info('Rescheduling task "${task.title}" to day $dayIndex, hour $hour');
    
    final currentData = state.value;
    if (currentData == null) {
      _logger.warning('Cannot reschedule - no data loaded');
      return;
    }
    
    try {
      // Calculate new scheduled time
      final newScheduledAt = _currentWeek.add(Duration(
        days: dayIndex,
        hours: hour - _currentWeek.hour,
        minutes: -_currentWeek.minute,
      ));
      
      _logger.fine('New scheduled time: $newScheduledAt');
      
      // Update the task
      final updatedTask = task.copyWith(scheduledAt: newScheduledAt);
      
      // Update local state
      final updatedTasks = currentData.tasks.map((t) {
        return t.id == task.id ? updatedTask : t;
      }).toList();
      
      state = AsyncValue.data(WeeklyPlanningData(
        tasks: updatedTasks,
        energyPredictions: currentData.energyPredictions,
      ));
      
      // In a real app, this would sync with the backend
      await _syncTaskUpdate(updatedTask);
      
      _logger.info('Task rescheduled successfully');
    } catch (error, stack) {
      _logger.severe('Error rescheduling task', error, stack);
      // Reload to restore consistent state
      loadWeek(_currentWeek);
    }
  }

  Future<void> batchReschedule(List<Task> tasks, Map<String, DateTime> newSchedules) async {
    _logger.info('Batch rescheduling ${tasks.length} tasks');
    
    final currentData = state.value;
    if (currentData == null) {
      _logger.warning('Cannot batch reschedule - no data loaded');
      return;
    }
    
    try {
      // Update all tasks
      final updatedTasks = currentData.tasks.map((task) {
        final newSchedule = newSchedules[task.id];
        if (newSchedule != null) {
          _logger.fine('Rescheduling "${task.title}" to $newSchedule');
          return task.copyWith(scheduledAt: newSchedule);
        }
        return task;
      }).toList();
      
      state = AsyncValue.data(WeeklyPlanningData(
        tasks: updatedTasks,
        energyPredictions: currentData.energyPredictions,
      ));
      
      // Sync with backend
      await _syncBatchUpdate(updatedTasks);
      
      _logger.info('Batch reschedule completed');
    } catch (error, stack) {
      _logger.severe('Error in batch reschedule', error, stack);
      loadWeek(_currentWeek);
    }
  }

  Future<void> optimizeWeeklySchedule() async {
    _logger.info('Optimizing weekly schedule');
    
    final currentData = state.value;
    if (currentData == null) {
      _logger.warning('Cannot optimize - no data loaded');
      return;
    }
    
    try {
      // This would use AI to optimize task placement based on energy levels
      final optimizedSchedule = await _runOptimizationAlgorithm(
        currentData.tasks,
        currentData.energyPredictions,
      );
      
      _logger.info('Optimization complete - ${optimizedSchedule.length} tasks rescheduled');
      
      // Apply optimized schedule
      await batchReschedule(currentData.tasks, optimizedSchedule);
    } catch (error, stack) {
      _logger.severe('Error optimizing schedule', error, stack);
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  Future<List<Task>> _fetchWeeklyTasks(DateTime start, DateTime end) async {
    _logger.fine('Fetching tasks from $start to $end');
    
    // In a real app, this would be an API call
    // For now, generate mock data
    await Future.delayed(const Duration(milliseconds: 500));
    
    final tasks = <Task>[];
    final random = DateTime.now().millisecondsSinceEpoch;
    
    // Generate some tasks for each day
    for (int day = 0; day < 7; day++) {
      final dayStart = start.add(Duration(days: day));
      
      // Morning focus block
      if (day < 5) { // Weekdays only
        tasks.add(Task(
          id: 'week-$random-$day-1',
          userId: 'user123',
          title: 'Deep Work Session',
          description: 'Focus on important project work',
          scheduledAt: dayStart.add(const Duration(hours: 9)),
          duration: const Duration(minutes: 90),
          taskType: TaskType.focus,
          priority: TaskPriority.high,
          energyRequired: 4,
          isCompleted: false,
          isFlexible: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      
      // Meetings
      if (day == 1 || day == 3) { // Tuesday and Thursday
        tasks.add(Task(
          id: 'week-$random-$day-2',
          userId: 'user123',
          title: 'Team Standup',
          description: 'Daily sync with the team',
          scheduledAt: dayStart.add(const Duration(hours: 10, minutes: 30)),
          duration: const Duration(minutes: 30),
          taskType: TaskType.meeting,
          priority: TaskPriority.medium,
          energyRequired: 2,
          isCompleted: false,
          isFlexible: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      
      // Admin tasks
      tasks.add(Task(
        id: 'week-$random-$day-3',
        userId: 'user123',
        title: 'Email & Admin',
        description: 'Process emails and administrative tasks',
        scheduledAt: dayStart.add(const Duration(hours: 14)),
        duration: const Duration(minutes: 45),
        taskType: TaskType.admin,
        priority: TaskPriority.low,
        energyRequired: 2,
        isCompleted: false,
        isFlexible: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      
      // Break
      if (day < 5) {
        tasks.add(Task(
          id: 'week-$random-$day-4',
          userId: 'user123',
          title: 'Lunch Break',
          description: 'Rest and recharge',
          scheduledAt: dayStart.add(const Duration(hours: 12)),
          duration: const Duration(minutes: 60),
          taskType: TaskType.breakTask,
          priority: TaskPriority.medium,
          energyRequired: 1,
          isCompleted: false,
          isFlexible: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    
    _logger.fine('Generated ${tasks.length} mock tasks');
    return tasks;
  }

  Future<Map<int, Map<int, int>>> _fetchWeeklyEnergyPredictions(DateTime weekStart) async {
    _logger.fine('Fetching energy predictions for week starting $weekStart');
    
    // In a real app, this would use AI predictions
    await Future.delayed(const Duration(milliseconds: 300));
    
    final predictions = <int, Map<int, int>>{};
    
    for (int day = 0; day < 7; day++) {
      predictions[day] = {};
      
      for (int hour = 0; hour < 24; hour++) {
        // Simulate energy patterns
        double energy = 50.0;
        
        // Morning peak (9-11 AM)
        if (hour >= 9 && hour <= 11) {
          energy = 75 + (10 * (1 - ((hour - 10).abs() / 2)));
        }
        // Post-lunch dip (1-3 PM)
        else if (hour >= 13 && hour <= 15) {
          energy = 40 + (5 * (hour - 14).abs());
        }
        // Evening peak (4-6 PM)
        else if (hour >= 16 && hour <= 18) {
          energy = 65 + (10 * (1 - ((hour - 17).abs() / 2)));
        }
        // Night time
        else if (hour < 6 || hour > 22) {
          energy = 30;
        }
        // Other times
        else {
          energy = 50 + (10 * (DateTime.now().millisecondsSinceEpoch % 3));
        }
        
        // Weekend adjustment
        if (day >= 5) {
          energy *= 0.9;
        }
        
        predictions[day]![hour] = energy.round().clamp(0, 100);
      }
    }
    
    _logger.fine('Generated energy predictions for 7 days');
    return predictions;
  }

  Future<void> _syncTaskUpdate(Task task) async {
    _logger.fine('Syncing task update to backend: ${task.id}');
    // In a real app, this would be an API call
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _syncBatchUpdate(List<Task> tasks) async {
    _logger.fine('Syncing batch update to backend: ${tasks.length} tasks');
    // In a real app, this would be an API call
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<Map<String, DateTime>> _runOptimizationAlgorithm(
    List<Task> tasks,
    Map<int, Map<int, int>> energyPredictions,
  ) async {
    _logger.info('Running schedule optimization algorithm');
    
    // This is a simplified optimization
    // Real implementation would use AI/ML
    await Future.delayed(const Duration(seconds: 1));
    
    final optimizedSchedule = <String, DateTime>{};
    
    for (final task in tasks.where((t) => t.isFlexible)) {
      // Find optimal time based on energy requirements
      DateTime? bestTime;
      int bestScore = -1;
      
      for (int day = 0; day < 7; day++) {
        for (int hour = 8; hour < 20; hour++) {
          final energy = energyPredictions[day]?[hour] ?? 50;
          final score = _calculatePlacementScore(task, energy, hour);
          
          if (score > bestScore) {
            bestScore = score;
            bestTime = _currentWeek.add(Duration(days: day, hours: hour));
          }
        }
      }
      
      if (bestTime != null) {
        optimizedSchedule[task.id] = bestTime;
        _logger.fine('Optimal time for "${task.title}": $bestTime (score: $bestScore)');
      }
    }
    
    return optimizedSchedule;
  }

  int _calculatePlacementScore(Task task, int energyLevel, int hour) {
    // Higher score = better placement
    int score = 0;
    
    // Match energy requirements
    final energyMatch = 100 - ((task.energyRequired * 20 - energyLevel).abs());
    score += energyMatch;
    
    // Prefer morning for high-priority tasks
    if (task.priority == TaskPriority.high && hour < 12) {
      score += 20;
    }
    
    // Avoid late afternoon for high-energy tasks
    if (task.energyRequired >= 4 && hour >= 15 && hour <= 17) {
      score -= 30;
    }
    
    return score;
  }
}

// Weekly stats provider
final weeklyStatsProvider = FutureProvider<WeeklyStats>((ref) async {
  final logger = Logger('weeklyStatsProvider');
  logger.fine('Calculating weekly stats');
  
  final planningData = ref.watch(weeklyPlanningProvider).value;
  if (planningData == null) {
    throw Exception('No weekly data available');
  }
  
  final totalTasks = planningData.tasks.length;
  final completedTasks = planningData.tasks.where((t) => t.isCompleted).length;
  final totalFocusMinutes = planningData.tasks
      .where((t) => t.taskType == TaskType.focus)
      .fold(0, (sum, task) => sum + task.duration.inMinutes);
  
  // Calculate average energy
  int totalEnergy = 0;
  int energyCount = 0;
  planningData.energyPredictions.forEach((day, hours) {
    hours.forEach((hour, energy) {
      if (hour >= 8 && hour <= 20) { // Working hours only
        totalEnergy += energy;
        energyCount++;
      }
    });
  });
  
  final avgEnergy = energyCount > 0 ? (totalEnergy / energyCount).round() : 0;
  
  logger.fine('Stats calculated: $totalTasks tasks, $completedTasks completed');
  
  return WeeklyStats(
    totalTasks: totalTasks,
    completedTasks: completedTasks,
    totalFocusMinutes: totalFocusMinutes,
    averageEnergyLevel: avgEnergy,
    optimalTaskPlacement: (completedTasks / totalTasks * 100).round(),
  );
});

class WeeklyStats {
  final int totalTasks;
  final int completedTasks;
  final int totalFocusMinutes;
  final int averageEnergyLevel;
  final int optimalTaskPlacement;

  WeeklyStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalFocusMinutes,
    required this.averageEnergyLevel,
    required this.optimalTaskPlacement,
  });
}