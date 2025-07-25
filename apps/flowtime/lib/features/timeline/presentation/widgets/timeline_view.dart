import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/time_block.dart';
import '../../domain/entities/task.dart';
import 'time_block_card.dart';
import 'current_time_indicator.dart';

class TimelineView extends StatelessWidget {
  final ScrollController scrollController;
  final List<TimeBlock> timeBlocks;
  final Function(Task) onTaskTap;
  final Function(Task) onTaskComplete;
  final Function(Task) onTaskReschedule;
  final Function(TimeBlock) onEmptyBlockTap;

  const TimelineView({
    super.key,
    required this.scrollController,
    required this.timeBlocks,
    required this.onTaskTap,
    required this.onTaskComplete,
    required this.onTaskReschedule,
    required this.onEmptyBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    // If no tasks, show empty state
    if (timeBlocks.isEmpty) {
      return _buildEmptyState(context);
    }

    return Stack(
      children: [
        // Timeline with hour markers
        CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 40, // Top padding
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final hour = index;
                  final hourBlocks = timeBlocks.where((block) {
                    return block.startTime.hour <= hour &&
                        block.endTime.hour > hour;
                  }).toList();

                  return _buildHourRow(context, hour, hourBlocks);
                },
                childCount: 24,
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 100, // Bottom padding
              ),
            ),
          ],
        ),
        
        // Current time indicator
        CurrentTimeIndicator(
          scrollController: scrollController,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ).animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: 24),
          Text(
            'Your day is wide open',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ).animate()
              .fadeIn(delay: 200.ms, duration: 600.ms)
              .slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first task',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textTertiary,
            ),
          ).animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.2),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => onEmptyBlockTap(
              TimeBlock(
                startTime: DateTime.now(),
                endTime: DateTime.now().add(const Duration(hours: 1)),
                task: null,
                predictedEnergyLevel: 75,
                isCurrentBlock: true,
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ).animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .scale(begin: const Offset(0.9, 0.9)),
        ],
      ),
    );
  }

  Widget _buildHourRow(BuildContext context, int hour, List<TimeBlock> blocks) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour label
          Container(
            width: 60,
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Text(
              _formatHour(hour),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Time blocks or empty space
          Expanded(
            child: blocks.isEmpty
                ? _buildEmptyHourSpace(context, hour)
                : Stack(
                    children: blocks.map((block) {
                      final startMinute = block.startTime.hour == hour
                          ? block.startTime.minute
                          : 0;
                      final endMinute = block.endTime.hour == hour
                          ? block.endTime.minute
                          : 60;
                      
                      // Calculate precise positioning
                      final topOffset = (startMinute / 60) * 80;
                      final height = ((endMinute - startMinute) / 60) * 80;

                      return Positioned(
                        top: topOffset,
                        left: 0,
                        right: 16,
                        height: height.clamp(20.0, 80.0), // Minimum height for visibility
                        child: TimeBlockCard(
                          timeBlock: block,
                          onTap: () {
                            if (block.task != null) {
                              onTaskTap(block.task!);
                            }
                          },
                          onComplete: block.task != null
                              ? () => onTaskComplete(block.task!)
                              : null,
                          onReschedule: block.task != null && block.task!.isFlexible
                              ? () => onTaskReschedule(block.task!)
                              : null,
                        ).animate()
                            .fadeIn(delay: (hour * 30).ms)
                            .slideX(begin: 0.05),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHourSpace(BuildContext context, int hour) {
    return InkWell(
      onTap: () {
        // Create a time block for this hour when tapped
        final now = DateTime.now();
        final blockStart = DateTime(now.year, now.month, now.day, hour);
        
        onEmptyBlockTap(
          TimeBlock(
            startTime: blockStart,
            endTime: blockStart.add(const Duration(hours: 1)),
            task: null,
            predictedEnergyLevel: 75,
            isCurrentBlock: false,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: Icon(
              Icons.add,
              color: Colors.grey.withValues(alpha: 0.0), // Invisible by default
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }
}