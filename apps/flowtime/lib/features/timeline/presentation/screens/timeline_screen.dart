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
    final scrollPosition = hoursSinceMidnight * 120.0; // 120px per hour
    
    _scrollController.animateTo(
      scrollPosition - 200, // Offset to show some context
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
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
                ref.read(timelineProvider.notifier).loadTasksForDate(date);
              },
              onTodayPressed: () {
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
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Error loading timeline: $error'),
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
        onPressed: () => _showAddTaskBottomSheet(),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // Navigate to different screens
          switch (index) {
            case 0:
              // Already on timeline
              break;
            case 1:
              // Navigate to Energy Dashboard
              context.go('/energy');
              break;
            case 2:
              // Navigate to Focus Mode
              context.go('/focus');
              break;
            case 3:
              // Navigate to Analytics
              context.go('/insights');
              break;
            case 4:
              // Navigate to Account/Profile
              context.go('/account');
              break;
          }
        },
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  void _showTaskDetails(Task task) {
    // Show task details bottom sheet
  }

  void _showRescheduleDialog(Task task) {
    // Show reschedule dialog
  }

  void _showQuickAddTask(TimeBlock timeBlock) {
    // Show quick add task dialog
  }

  void _showAddTaskBottomSheet() {
    // Show add task bottom sheet
  }
}