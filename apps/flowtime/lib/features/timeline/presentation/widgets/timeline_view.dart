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
    return Stack(
      children: [
        // Timeline background with hour markers
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
                        block.endTime.hour >= hour;
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

  Widget _buildHourRow(BuildContext context, int hour, List<TimeBlock> blocks) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
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
          
          // Time blocks
          Expanded(
            child: Stack(
              children: blocks.map((block) {
                final startMinute = block.startTime.hour == hour
                    ? block.startTime.minute
                    : 0;
                final endMinute = block.endTime.hour == hour
                    ? block.endTime.minute
                    : 60;
                    
                final topOffset = (startMinute / 60) * 120;
                final height = ((endMinute - startMinute) / 60) * 120;

                return Positioned(
                  top: topOffset,
                  left: 0,
                  right: 16,
                  height: height,
                  child: TimeBlockCard(
                    timeBlock: block,
                    onTap: () {
                      if (block.task != null) {
                        onTaskTap(block.task!);
                      } else {
                        onEmptyBlockTap(block);
                      }
                    },
                    onComplete: block.task != null
                        ? () => onTaskComplete(block.task!)
                        : null,
                    onReschedule: block.task != null && block.task!.isFlexible
                        ? () => onTaskReschedule(block.task!)
                        : null,
                  ).animate()
                      .fadeIn(delay: (hour * 50).ms)
                      .slideX(begin: 0.1),
                );
              }).toList(),
            ),
          ),
        ],
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