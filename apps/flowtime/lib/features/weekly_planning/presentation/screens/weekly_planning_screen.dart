import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logging/logging.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/weekly_planning_provider.dart';
import '../widgets/week_header.dart';
import '../widgets/time_grid.dart';
import '../widgets/draggable_task_card.dart';
import '../widgets/weekly_stats_card.dart';
import '../widgets/energy_heatmap_overlay.dart';
import '../../../timeline/domain/entities/task.dart';

class WeeklyPlanningScreen extends ConsumerStatefulWidget {
  const WeeklyPlanningScreen({super.key});

  @override
  ConsumerState<WeeklyPlanningScreen> createState() => _WeeklyPlanningScreenState();
}

class _WeeklyPlanningScreenState extends ConsumerState<WeeklyPlanningScreen>
    with TickerProviderStateMixin {
  final _logger = Logger('WeeklyPlanningScreen');
  late AnimationController _gridAnimationController;
  late AnimationController _heatmapAnimationController;
  late ScrollController _horizontalScrollController;
  late ScrollController _verticalScrollController;
  
  bool _showEnergyHeatmap = true;
  bool _isDragging = false;
  Task? _draggedTask;
  Offset? _dragOffset;
  DateTime _selectedWeek = DateTime.now();
  
  // Grid dimensions
  static const double _hourHeight = 60.0;
  static const double _dayWidth = 150.0;
  static const double _timeColumnWidth = 60.0;
  static const int _startHour = 6;
  static const int _endHour = 23;

  @override
  void initState() {
    super.initState();
    _logger.info('WeeklyPlanningScreen initialized');
    
    _gridAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _heatmapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
    
    // Log scroll positions for debugging
    _horizontalScrollController.addListener(() {
      _logger.finest('Horizontal scroll: ${_horizontalScrollController.offset}');
    });
    
    _verticalScrollController.addListener(() {
      _logger.finest('Vertical scroll: ${_verticalScrollController.offset}');
    });
    
    // Trigger initial animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.fine('Starting initial animations');
      _gridAnimationController.forward();
      if (_showEnergyHeatmap) {
        _heatmapAnimationController.forward();
      }
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _logger.info('WeeklyPlanningScreen disposed');
    _gridAnimationController.dispose();
    _heatmapAnimationController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1;
    final currentHour = now.hour;
    
    _logger.fine('Scrolling to current time: Day $currentDayIndex, Hour $currentHour');
    
    // Scroll horizontally to current day
    if (_horizontalScrollController.hasClients) {
      final horizontalOffset = currentDayIndex * _dayWidth;
      _horizontalScrollController.animateTo(
        horizontalOffset.clamp(0.0, _horizontalScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
    
    // Scroll vertically to current hour
    if (_verticalScrollController.hasClients) {
      final verticalOffset = (currentHour - _startHour) * _hourHeight;
      _verticalScrollController.animateTo(
        verticalOffset.clamp(0.0, _verticalScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleTaskDragStart(Task task, Offset globalPosition) {
    _logger.info('Drag started for task: ${task.title} at position: $globalPosition');
    setState(() {
      _isDragging = true;
      _draggedTask = task;
      _dragOffset = globalPosition;
    });
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handleTaskDragUpdate(Offset globalPosition) {
    if (!_isDragging || _draggedTask == null) return;
    
    setState(() {
      _dragOffset = globalPosition;
    });
  }

  void _handleTaskDragEnd(Offset globalPosition) {
    if (!_isDragging || _draggedTask == null) return;
    
    _logger.info('Drag ended at position: $globalPosition');
    
    // Calculate drop position
    final dropResult = _calculateDropPosition(globalPosition);
    
    if (dropResult != null) {
      _logger.info('Task dropped at: Day ${dropResult.day}, Hour ${dropResult.hour}');
      
      // Update task schedule
      ref.read(weeklyPlanningProvider.notifier).rescheduleTask(
        _draggedTask!,
        dropResult.day,
        dropResult.hour,
      );
      
      // Success feedback
      HapticFeedback.mediumImpact();
    } else {
      _logger.warning('Invalid drop position');
      // Error feedback
      HapticFeedback.heavyImpact();
    }
    
    setState(() {
      _isDragging = false;
      _draggedTask = null;
      _dragOffset = null;
    });
  }

  DropPosition? _calculateDropPosition(Offset globalPosition) {
    // Convert global position to local grid position
    final RenderBox? gridBox = context.findRenderObject() as RenderBox?;
    if (gridBox == null) return null;
    
    final localPosition = gridBox.globalToLocal(globalPosition);
    
    // Account for scroll offset and grid margins
    final adjustedX = localPosition.dx + _horizontalScrollController.offset - _timeColumnWidth;
    final adjustedY = localPosition.dy + _verticalScrollController.offset - 100; // Header height
    
    // Calculate day and hour
    final dayIndex = (adjustedX / _dayWidth).floor();
    final hourIndex = (adjustedY / _hourHeight).floor();
    
    // Validate bounds
    if (dayIndex < 0 || dayIndex >= 7 || hourIndex < 0 || hourIndex >= (_endHour - _startHour)) {
      return null;
    }
    
    return DropPosition(
      day: dayIndex,
      hour: _startHour + hourIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyData = ref.watch(weeklyPlanningProvider);
    
    _logger.finest('Building WeeklyPlanningScreen');
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with week selector and stats
                _buildHeader(),
                
                // Main grid area
                Expanded(
                  child: weeklyData.when(
                    data: (data) => _buildPlanningGrid(data),
                    loading: () => _buildLoadingState(),
                    error: (error, stack) {
                      _logger.severe('Error loading weekly data', error, stack);
                      return _buildErrorState(error);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Floating action buttons
          Positioned(
            right: 16,
            bottom: 80,
            child: _buildFloatingControls(),
          ),
          
          // Drag overlay
          if (_isDragging && _draggedTask != null && _dragOffset != null)
            Positioned(
              left: _dragOffset!.dx - 75,
              top: _dragOffset!.dy - 30,
              child: IgnorePointer(
                child: DraggableTaskCard(
                  task: _draggedTask!,
                  isDragging: true,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Week selector
          WeekHeader(
            selectedWeek: _selectedWeek,
            onWeekChanged: (newWeek) {
              _logger.info('Week changed to: $newWeek');
              setState(() => _selectedWeek = newWeek);
              ref.read(weeklyPlanningProvider.notifier).loadWeek(newWeek);
            },
          ).animate().fadeIn().slideY(begin: -0.2),
          
          const SizedBox(height: 16),
          
          // Weekly stats
          Consumer(
            builder: (context, ref, _) {
              final stats = ref.watch(weeklyStatsProvider);
              return stats.when(
                data: (data) => WeeklyStatsCard(stats: data)
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideX(begin: -0.1),
                loading: () => const SizedBox(height: 60),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningGrid(WeeklyPlanningData data) {
    _logger.fine('Building planning grid with ${data.tasks.length} tasks');
    
    return Stack(
      children: [
        // Time grid background
        SingleChildScrollView(
          controller: _verticalScrollController,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Stack(
              children: [
                // Grid lines and time labels
                TimeGrid(
                  startHour: _startHour,
                  endHour: _endHour,
                  hourHeight: _hourHeight,
                  dayWidth: _dayWidth,
                  timeColumnWidth: _timeColumnWidth,
                  animationController: _gridAnimationController,
                ),
                
                // Energy heatmap overlay
                if (_showEnergyHeatmap)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: EnergyHeatmapOverlay(
                        energyData: data.energyPredictions,
                        startHour: _startHour,
                        endHour: _endHour,
                        hourHeight: _hourHeight,
                        dayWidth: _dayWidth,
                        timeColumnWidth: _timeColumnWidth,
                        animationController: _heatmapAnimationController,
                      ),
                    ),
                  ),
                
                // Task blocks
                ...data.tasks.map((task) => _buildTaskBlock(task, data)),
              ],
            ),
          ),
        ),
        
        // Current time indicator
        _buildCurrentTimeIndicator(),
      ],
    );
  }

  Widget _buildTaskBlock(Task task, WeeklyPlanningData data) {
    final scheduledDate = task.scheduledAt;
    final dayIndex = scheduledDate.weekday - 1;
    final hour = scheduledDate.hour;
    final minute = scheduledDate.minute;
    
    final left = _timeColumnWidth + (dayIndex * _dayWidth) + 4;
    final top = ((hour - _startHour) * _hourHeight) + (minute / 60 * _hourHeight);
    final height = (task.duration.inMinutes / 60) * _hourHeight - 8;
    
    _logger.finest('Positioning task "${task.title}" at day $dayIndex, hour $hour');
    
    return Positioned(
      left: left,
      top: top,
      width: _dayWidth - 8,
      height: height,
      child: GestureDetector(
        onPanStart: (details) => _handleTaskDragStart(task, details.globalPosition),
        onPanUpdate: (details) => _handleTaskDragUpdate(details.globalPosition),
        onPanEnd: (details) => _handleTaskDragEnd(details.globalPosition),
        child: DraggableTaskCard(
          task: task,
          isDragging: false,
          onTap: () => _showTaskDetails(task),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1;
    final currentHour = now.hour;
    final currentMinute = now.minute;
    
    if (currentHour < _startHour || currentHour > _endHour) {
      return const SizedBox.shrink();
    }
    
    final left = _timeColumnWidth + (currentDayIndex * _dayWidth);
    final top = ((currentHour - _startHour) * _hourHeight) + 
                (currentMinute / 60 * _hourHeight);
    
    return Positioned(
      left: left,
      top: top - _verticalScrollController.offset,
      child: Container(
        width: _dayWidth,
        height: 2,
        color: AppColors.error,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(),
      ).fadeIn().then().fadeOut(
        duration: 1.seconds,
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        // Toggle energy heatmap
        FloatingActionButton(
          mini: true,
          backgroundColor: _showEnergyHeatmap ? AppColors.primary : AppColors.surfaceDark,
          onPressed: () {
            _logger.info('Toggling energy heatmap: ${!_showEnergyHeatmap}');
            setState(() => _showEnergyHeatmap = !_showEnergyHeatmap);
            if (_showEnergyHeatmap) {
              _heatmapAnimationController.forward();
            } else {
              _heatmapAnimationController.reverse();
            }
          },
          child: Icon(
            Icons.gradient,
            color: _showEnergyHeatmap ? Colors.white : AppColors.textSecondary,
          ),
        ),
        
        // Batch scheduling
        FloatingActionButton(
          mini: true,
          backgroundColor: AppColors.surfaceDark,
          onPressed: _showBatchScheduling,
          child: const Icon(Icons.auto_fix_high, color: AppColors.textSecondary),
        ),
        
        // Add task
        FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: _showAddTask,
          child: const Icon(Icons.add),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.2);
  }

  Widget _buildLoadingState() {
    _logger.fine('Showing loading state');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading weekly schedule...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load weekly schedule',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.refresh(weeklyPlanningProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
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
        type: BottomNavigationBarType.fixed, // Required for 5 items
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: 2, // Planning is index 2
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: (index) {
          _logger.fine('Bottom nav tapped: $index');
          switch (index) {
            case 0:
              context.go('/timeline');
              break;
            case 1:
              context.go('/energy');
              break;
            case 2:
              break; // Already on planning
            case 3:
              context.go('/insights');
              break;
            case 4:
              context.go('/focus');
              break;
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
            icon: Icon(Icons.calendar_view_week),
            label: 'Planning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Focus',
          ),
        ],
      ),
    );
  }

  void _showTaskDetails(Task task) {
    _logger.info('Showing details for task: ${task.title}');
    // Implementation would show task details bottom sheet
  }

  void _showBatchScheduling() {
    _logger.info('Opening batch scheduling dialog');
    // Implementation would show batch scheduling interface
  }

  void _showAddTask() {
    _logger.info('Opening add task dialog');
    // Implementation would show add task interface
  }
}

class DropPosition {
  final int day;
  final int hour;

  DropPosition({required this.day, required this.hour});
}

class WeeklyPlanningData {
  final List<Task> tasks;
  final Map<int, Map<int, int>> energyPredictions; // day -> hour -> energy level

  WeeklyPlanningData({
    required this.tasks,
    required this.energyPredictions,
  });
}