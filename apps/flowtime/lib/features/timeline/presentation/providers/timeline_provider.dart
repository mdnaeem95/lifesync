import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/timeline_repository_impl.dart';
import '../../domain/repositories/timeline_repository.dart';
import '../../domain/entities/time_block.dart';
import '../../domain/entities/task.dart';
import 'energy_provider.dart';

// Selected date provider
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Timeline provider
final timelineProvider = StateNotifierProvider<TimelineNotifier, AsyncValue<List<TimeBlock>>>((ref) {
  final repository = ref.watch(timelineRepositoryProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  
  return TimelineNotifier(
    repository: repository,
    ref: ref,
  )..loadTasksForDate(selectedDate);
});

class TimelineNotifier extends StateNotifier<AsyncValue<List<TimeBlock>>> {
  final TimelineRepository _repository;
  final Ref _ref;
  
  TimelineNotifier({
    required TimelineRepository repository,
    required Ref ref,
  })  : _repository = repository,
        _ref = ref,
        super(const AsyncValue.loading());

  Future<void> loadTasksForDate(DateTime date) async {
    state = const AsyncValue.loading();
    
    try {
      // Fetch tasks from repository
      final tasks = await _repository.getTasksForDate(date);
      
      // Get predicted energy levels for the day
      final energyLevels = _ref.read(predictedEnergyLevelsProvider).value ?? [];
      
      // Generate time blocks with energy predictions
      final timeBlocks = _generateTimeBlocks(tasks, date, energyLevels);
      
      state = AsyncValue.data(timeBlocks);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  List<TimeBlock> _generateTimeBlocks(
    List<Task> tasks,
    DateTime date,
    List<int> energyLevels,
  ) {
    final blocks = <TimeBlock>[];
    final now = DateTime.now();
    
    // Sort tasks by scheduled time
    tasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    
    // Track occupied time slots
    final occupiedSlots = <DateTime, Task>{};
    for (final task in tasks) {
      occupiedSlots[task.scheduledAt] = task;
    }
    
    // Generate blocks for each hour
    for (var hour = 0; hour < 24; hour++) {
      final blockStart = DateTime(date.year, date.month, date.day, hour);
      final blockEnd = blockStart.add(const Duration(hours: 1));
      
      // Find tasks in this hour
      final hourTasks = tasks.where((task) {
        return task.scheduledAt.isBefore(blockEnd) &&
            task.endTime.isAfter(blockStart);
      }).toList();
      
      if (hourTasks.isEmpty) {
        // Create empty block
        blocks.add(TimeBlock(
          startTime: blockStart,
          endTime: blockEnd,
          task: null,
          predictedEnergyLevel: _getEnergyForHour(hour, energyLevels),
          isCurrentBlock: _isCurrentBlock(blockStart, blockEnd, now),
        ));
      } else {
        // Create blocks for tasks
        for (final task in hourTasks) {
          final start = task.scheduledAt.isBefore(blockStart)
              ? blockStart
              : task.scheduledAt;
          final end = task.endTime.isAfter(blockEnd)
              ? blockEnd
              : task.endTime;
          
          blocks.add(TimeBlock(
            startTime: start,
            endTime: end,
            task: task,
            predictedEnergyLevel: _getEnergyForHour(start.hour, energyLevels),
            isCurrentBlock: _isCurrentBlock(start, end, now),
          ));
        }
      }
    }
    
    return blocks;
  }

  int _getEnergyForHour(int hour, List<int> energyLevels) {
    if (energyLevels.isEmpty || hour >= energyLevels.length) {
      // Default energy pattern if no predictions available
      if (hour >= 9 && hour <= 11) return 85;
      if (hour >= 14 && hour <= 16) return 60;
      if (hour >= 19 && hour <= 21) return 70;
      return 50;
    }
    return energyLevels[hour];
  }

  bool _isCurrentBlock(DateTime start, DateTime end, DateTime now) {
    return now.isAfter(start) && now.isBefore(end);
  }

  Future<void> toggleTaskComplete(String taskId) async {
    try {
      await _repository.completeTask(taskId);
      
      // Reload tasks
      final date = _ref.read(selectedDateProvider);
      await loadTasksForDate(date);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<void> rescheduleTask(String taskId, DateTime newTime) async {
    try {
      await _repository.rescheduleTask(taskId, newTime);
      
      // Reload tasks
      final date = _ref.read(selectedDateProvider);
      await loadTasksForDate(date);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _repository.deleteTask(taskId);
      
      // Reload tasks
      final date = _ref.read(selectedDateProvider);
      await loadTasksForDate(date);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<Task> createTask(Task task) async {
    try {
      final newTask = await _repository.createTask(task);
      
      // Reload tasks
      final date = _ref.read(selectedDateProvider);
      await loadTasksForDate(date);
      
      return newTask;
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
      rethrow;
    }
  }

  Future<List<DateTime>> getSuggestedTimeSlots(
    Duration duration,
    int energyRequired,
  ) async {
    try {
      final date = _ref.read(selectedDateProvider);
      return await _repository.getSuggestedTimeSlots(
        duration,
        energyRequired,
        date,
      );
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
      return [];
    }
  }
}

// Quick add task provider
final quickAddTaskProvider = StateNotifierProvider<QuickAddTaskNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(timelineRepositoryProvider);
  return QuickAddTaskNotifier(repository, ref);
});

class QuickAddTaskNotifier extends StateNotifier<AsyncValue<void>> {
  final TimelineRepository _repository;
  final Ref _ref;

  QuickAddTaskNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> createTask({
    required String title,
    String? description,
    required DateTime scheduledAt,
    required Duration duration,
    required TaskType taskType,
    required int energyRequired,
    bool isFlexible = true,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final task = Task(
        id: '', // Will be generated by backend
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        duration: duration,
        taskType: taskType,
        priority: TaskPriority.medium,
        energyRequired: energyRequired,
        isCompleted: false,
        isFlexible: isFlexible,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _repository.createTask(task);
      
      // Refresh timeline
      await _ref.read(timelineProvider.notifier).loadTasksForDate(scheduledAt);
      
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}