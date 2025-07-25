import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'date_provider.dart';
import '../../data/repositories/timeline_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/time_block.dart';
import '../../domain/repositories/timeline_repository.dart';
import 'energy_provider.dart';

// Timeline state provider
final timelineProvider = StateNotifierProvider<TimelineNotifier, AsyncValue<List<TimeBlock>>>((ref) {
  final repository = ref.watch(timelineRepositoryProvider);
  return TimelineNotifier(ref, repository);
});

class TimelineNotifier extends StateNotifier<AsyncValue<List<TimeBlock>>> {
  final Ref _ref;
  final TimelineRepository _repository;
  final _logger = Logger('TimelineNotifier');

  TimelineNotifier(this._ref, this._repository) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    final date = _ref.read(selectedDateProvider);
    await loadTasksForDate(date);
  }

  Future<void> loadTasksForDate(DateTime date) async {
    try {
      state = const AsyncValue.loading();
      
      final tasks = await _repository.getTasksForDate(date);
      
      // Get predicted energy levels
      final energyLevels = _ref.read(predictedEnergyLevelsProvider).value ?? [];
      
      // Generate time blocks ONLY for tasks (no empty blocks)
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
    
    // Check for overlaps and adjust if necessary
    final adjustedTasks = _preventOverlaps(tasks);
    
    // Create blocks only for actual tasks
    for (final task in adjustedTasks) {
      blocks.add(TimeBlock(
        startTime: task.scheduledAt,
        endTime: task.endTime,
        task: task,
        predictedEnergyLevel: _getEnergyForHour(task.scheduledAt.hour, energyLevels),
        isCurrentBlock: _isCurrentBlock(task.scheduledAt, task.endTime, now),
      ));
    }
    
    return blocks;
  }

  List<Task> _preventOverlaps(List<Task> tasks) {
    if (tasks.isEmpty) return tasks;
    
    final adjustedTasks = <Task>[];
    
    for (int i = 0; i < tasks.length; i++) {
      var currentTask = tasks[i];
      
      // Check if this task overlaps with any previously added task
      bool hasOverlap = false;
      for (final existingTask in adjustedTasks) {
        if (_tasksOverlap(currentTask, existingTask)) {
          hasOverlap = true;
          
          // Adjust the current task to start after the existing task ends
          final newStartTime = existingTask.endTime;
          final duration = currentTask.endTime.difference(currentTask.scheduledAt);
          
          currentTask = currentTask.copyWith(
            scheduledAt: newStartTime,
            duration: duration,
          );
          break;
        }
      }
      
      // If task was adjusted, check again for new overlaps
      if (hasOverlap) {
        // Recursive check to ensure no new overlaps were created
        final tempList = [...adjustedTasks, currentTask];
        tempList.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        adjustedTasks.clear();
        adjustedTasks.addAll(_preventOverlaps(tempList));
      } else {
        adjustedTasks.add(currentTask);
      }
    }
    
    return adjustedTasks;
  }

  bool _tasksOverlap(Task task1, Task task2) {
    // Tasks overlap if one starts before the other ends
    return (task1.scheduledAt.isBefore(task2.endTime) && 
            task1.endTime.isAfter(task2.scheduledAt));
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
      await loadTasks();
    } catch (error, stackTrace) {
      _logger.severe('Error completing task: $taskId', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await _repository.updateTask(task.id, task);
      
      // Reload tasks to reflect changes and check for overlaps
      await loadTasks();
    } catch (error, stackTrace) {
      _logger.severe('Error updating task: ${task.id}', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _repository.deleteTask(taskId);
      
      // Reload tasks
      await loadTasks();
    } catch (error, stackTrace) {
      _logger.severe('Error deleting task: $taskId', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addTask(Task task) async {
    try {
      // Check for overlaps before adding
      final currentTasks = state.value ?? [];
      final allTasks = [...currentTasks.map((b) => b.task).whereType<Task>(), task];
      
      // Sort and prevent overlaps
      allTasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final adjustedTasks = _preventOverlaps(allTasks);
      
      // Find the adjusted version of our new task
      final adjustedTask = adjustedTasks.firstWhere(
        (t) => t.title == task.title && t.scheduledAt.day == task.scheduledAt.day,
        orElse: () => task,
      );
      
      await _repository.createTask(adjustedTask);
      
      // Reload tasks
      await loadTasks();
    } catch (error, stackTrace) {
      _logger.severe('Error adding task: ${task.title}', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> rescheduleTask(String taskId, DateTime newTime) async {
    try {
      final currentBlocks = state.value ?? [];
      final taskBlock = currentBlocks.firstWhere(
        (block) => block.task?.id == taskId,
      );
      
      if (taskBlock.task != null) {
        final updatedTask = taskBlock.task!.copyWith(
          scheduledAt: newTime,
        );
        
        await updateTask(updatedTask);
      }
    } catch (error, stackTrace) {
      _logger.severe('Error rescheduling task: $taskId', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
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
    } catch (error, stackTrace) {
      _logger.severe('Error getting suggested time slots', error, stackTrace);
      return [];
    }
  }
}

// Helper providers
final currentTaskProvider = Provider<Task?>((ref) {
  final timeBlocks = ref.watch(timelineProvider).value ?? [];
    
  try {
    final currentBlock = timeBlocks.firstWhere(
      (block) => block.isCurrentBlock,
    );
    return currentBlock.task;
  } catch (_) {
    return null;
  }
});

final nextTaskProvider = Provider<Task?>((ref) {
  final timeBlocks = ref.watch(timelineProvider).value ?? [];
  final now = DateTime.now();
  
  final futureBlocks = timeBlocks.where(
    (block) => block.startTime.isAfter(now),
  ).toList();
  
  if (futureBlocks.isEmpty) return null;
  
  futureBlocks.sort((a, b) => a.startTime.compareTo(b.startTime));
  return futureBlocks.first.task;
});

final taskCountProvider = Provider<int>((ref) {
  final timeBlocks = ref.watch(timelineProvider).value ?? [];
  return timeBlocks.where((block) => block.task != null).length;
});

final completedTaskCountProvider = Provider<int>((ref) {
  final timeBlocks = ref.watch(timelineProvider).value ?? [];
  return timeBlocks.where(
    (block) => block.task?.isCompleted ?? false,
  ).length;
});

// Quick add task provider
final quickAddTaskProvider = StateNotifierProvider<QuickAddTaskNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(timelineRepositoryProvider);
  return QuickAddTaskNotifier(repository, ref);
});

class QuickAddTaskNotifier extends StateNotifier<AsyncValue<void>> {
  final TimelineRepository _repository;
  final Ref _ref;
  final _logger = Logger('QuickAddTaskNotifier');

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
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _repository.createTask(task);
      
      // Refresh timeline
      await _ref.read(timelineProvider.notifier).loadTasksForDate(scheduledAt);
      
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      _logger.severe('Error creating task: $title', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }
}