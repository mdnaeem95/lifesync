// lib/features/timeline/presentation/screens/timeline_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/timeline_provider.dart';
import '../providers/energy_provider.dart';
import '../widgets/timeline_header.dart';
import '../widgets/energy_indicator.dart';
import '../widgets/timeline_view.dart';
import '../widgets/floating_add_button.dart';
import '../widgets/quick_add_task_sheet.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/time_block.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Scroll to current time on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final hoursSinceMidnight = now.hour + (now.minute / 60);
    final scrollPosition = hoursSinceMidnight * 80.0; // 80px per hour
    
    _scrollController.animateTo(
      scrollPosition - 200, // Offset to show some context
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  void _showTaskDetails(Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailsSheet(task: task),
    );
  }

  void _showRescheduleDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => _RescheduleDialog(
        task: task,
        onReschedule: (newTime) {
          ref.read(timelineProvider.notifier).rescheduleTask(task.id, newTime);
        },
      ),
    );
  }

  void _showQuickAddTask(TimeBlock? timeBlock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddTaskSheet(
        suggestedTime: timeBlock?.startTime,
      ),
    );
  }

  void _showAddTaskBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickAddTaskSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineState = ref.watch(timelineProvider);
    final currentEnergy = ref.watch(currentEnergyProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header with date and energy
            TimelineHeader(
              onDateChanged: (date) {
                ref.read(selectedDateProvider.notifier).state = date;
                ref.read(timelineProvider.notifier).loadTasksForDate(date);
              },
              onTodayPressed: () {
                ref.read(selectedDateProvider.notifier).state = DateTime.now();
                ref.read(timelineProvider.notifier).loadTasksForDate(DateTime.now());
                _scrollToCurrentTime();
              },
            ).animate().fadeIn().slideY(begin: -0.2),
            
            // Energy indicator bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: EnergyIndicator(
                currentLevel: currentEnergy.value ?? 75,
                predictedLevels: ref.watch(predictedEnergyLevelsProvider).value ?? [],
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
            
            // Main timeline view
            Expanded(
              child: timelineState.when(
                data: (timeBlocks) => TimelineView(
                  scrollController: _scrollController,
                  timeBlocks: timeBlocks,
                  onTaskTap: (task) => _showTaskDetails(task),
                  onTaskComplete: (task) {
                    ref.read(timelineProvider.notifier).toggleTaskComplete(task.id);
                  },
                  onTaskReschedule: (task) => _showRescheduleDialog(task),
                  onEmptyBlockTap: (timeBlock) => _showQuickAddTask(timeBlock),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading timeline',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(timelineProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingAddButton(
        animationController: _fabAnimationController,
        onPressed: _showAddTaskBottomSheet,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
            switch (index) {
              case 0:
                break; // Already on timeline
              case 1:
                context.go('/energy');
                break;
              case 2:
                context.go('/focus');
                break;
              case 3:
                context.go('/insights');
                break;
            }
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Energy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Focus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}

// Task Details Sheet
class _TaskDetailsSheet extends ConsumerWidget {
  final Task task;

  const _TaskDetailsSheet({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Task info
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (task.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Completed', style: TextStyle(color: AppColors.success)),
                    ],
                  ),
                ),
            ],
          ),
          
          if (task.description != null) ...[
            const SizedBox(height: 16),
            Text(
              task.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Task details
          _buildDetailRow(
            Icons.schedule,
            'Scheduled',
            '${task.scheduledAt.hour.toString().padLeft(2, '0')}:${task.scheduledAt.minute.toString().padLeft(2, '0')}',
          ),
          _buildDetailRow(
            Icons.timer,
            'Duration',
            '${task.duration.inMinutes} minutes',
          ),
          _buildDetailRow(
            Icons.bolt,
            'Energy Required',
            '${task.energyRequired}/5',
          ),
          _buildDetailRow(
            Icons.flag,
            'Priority',
            task.priority.name.toUpperCase(),
          ),
          
          const SizedBox(height: 24),
          
          // Actions
          Row(
            children: [
              if (!task.isCompleted) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(timelineProvider.notifier).toggleTaskComplete(task.id);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(timelineProvider.notifier).deleteTask(task.id);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: AppColors.textTertiary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Reschedule Dialog
class _RescheduleDialog extends StatefulWidget {
  final Task task;
  final Function(DateTime) onReschedule;

  const _RescheduleDialog({
    required this.task,
    required this.onReschedule,
  });

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.task.scheduledAt;
    _selectedTime = TimeOfDay.fromDateTime(widget.task.scheduledAt);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reschedule Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: Text(_selectedTime.format(context)),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) {
                setState(() => _selectedTime = time);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final newDateTime = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );
            widget.onReschedule(newDateTime);
            Navigator.of(context).pop();
          },
          child: const Text('Reschedule'),
        ),
      ],
    );
  }
}