import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/time_block.dart';
import '../../domain/entities/task.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final timelineProvider = StateNotifierProvider<TimelineNotifier, AsyncValue<List<TimeBlock>>>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  if (user == null) {
    return TimelineNotifier(ref)..loadTasksForDate(DateTime.now());
  }
  
  return TimelineNotifier(ref)..loadTasksForDate(DateTime.now());
});

class TimelineNotifier extends StateNotifier<AsyncValue<List<TimeBlock>>> {
  final Ref _ref;
  DateTime _currentDate = DateTime.now();

  TimelineNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> loadTasksForDate(DateTime date) async {
    state = const AsyncValue.loading();
    _currentDate = date;
    
    try {
      // Fetch tasks from repository
      final tasks = await _fetchTasksForDate(date);
      
      // Generate time blocks with energy predictions
      final timeBlocks = _generateTimeBlocks(tasks, date);
      
      state = AsyncValue.data(timeBlocks);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<List<Task>> _fetchTasksForDate(DateTime date) async {
    // TODO: Implement actual repository call
    // For now, return mock data
    return [
      Task(
        id: '1',
        title: 'Morning Standup',
        description: 'Daily team sync',
        scheduledAt: DateTime(date.year, date.month, date.day, 9, 0),
        duration: const Duration(minutes: 30),
        taskType: TaskType.meeting,
        priority: TaskPriority.high,
        energyRequired: 3,
        isCompleted: false,
        isFlexible: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Task(
        id: '2',
        title: 'Deep Work: Feature Development',
        description: 'Implement timeline screen',
        scheduledAt: DateTime(date.year, date.month, date.day, 10, 0),
        duration: const Duration(hours: 2),
        taskType: TaskType.focus,
        priority: TaskPriority.high,
        energyRequired: 5,
        isCompleted: false,
        isFlexible: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Task(
        id: '3',
        title: 'Lunch Break',
        scheduledAt: DateTime(date.year, date.month, date.day, 12, 30),
        duration: const Duration(hours: 1),
        taskType: TaskType.breakTask,
        priority: TaskPriority.medium,
        energyRequired: 1,
        isCompleted: false,
        isFlexible: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  List<TimeBlock> _generateTimeBlocks(List<Task> tasks, DateTime date) {
    final blocks = <TimeBlock>[];
    final now = DateTime.now();
    
    // Sort tasks by scheduled time
    tasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    
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
          predictedEnergyLevel: _predictEnergyLevel(blockStart),
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
            predictedEnergyLevel: _predictEnergyLevel(start),
            isCurrentBlock: _isCurrentBlock(start, end, now),
          ));
        }
      }
    }
    
    return blocks;
  }

  int _predictEnergyLevel(DateTime time) {
    // TODO: Implement actual energy prediction
    // For now, use a simple curve
    final hour = time.hour;
    if (hour >= 9 && hour <= 11) return 85;
    if (hour >= 14 && hour <= 16) return 60;
    if (hour >= 19 && hour <= 21) return 70;
    return 50;
  }

  bool _isCurrentBlock(DateTime start, DateTime end, DateTime now) {
    return now.isAfter(start) && now.isBefore(end);
  }

  Future<void> toggleTaskComplete(String taskId) async {
    // TODO: Implement task completion
  }

  Future<void> rescheduleTask(String taskId, DateTime newTime) async {
    // TODO: Implement task rescheduling
  }
}