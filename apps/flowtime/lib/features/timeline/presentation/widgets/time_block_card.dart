import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/time_block.dart';
import '../../domain/entities/task.dart';

class TimeBlockCard extends StatelessWidget {
  final TimeBlock timeBlock;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onReschedule;
  final bool isSwipeable;

  const TimeBlockCard({
    super.key,
    required this.timeBlock,
    this.onTap,
    this.onComplete,
    this.onReschedule,
    this.isSwipeable = true,
  });

  @override
  Widget build(BuildContext context) {
    final task = timeBlock.task;
    final isEmpty = task == null;
    
    Widget card = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(task?.taskType),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBorderColor(task?.taskType),
            width: timeBlock.isCurrentBlock ? 2 : 1,
          ),
          boxShadow: timeBlock.isCurrentBlock
              ? [
                  BoxShadow(
                    color: _getBorderColor(task?.taskType).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time display
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(timeBlock.startTime),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    _formatTime(timeBlock.endTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEmpty)
                    Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (task.isFlexible)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.swap_horiz,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChip(
                          Icons.timer_outlined,
                          '${task.duration.inMinutes} min',
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          Icons.bolt,
                          'Energy ${task.energyRequired}/5',
                          color: _getEnergyColor(task.energyRequired),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Energy indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getEnergyColor(timeBlock.predictedEnergyLevel)
                    .withValues(alpha: 0.2),
                border: Border.all(
                  color: _getEnergyColor(timeBlock.predictedEnergyLevel),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '${timeBlock.predictedEnergyLevel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isSwipeable && !isEmpty && !task.isCompleted) {
      card = Dismissible(
        key: Key(timeBlock.task!.id),
        background: _buildSwipeBackground(true),
        secondaryBackground: _buildSwipeBackground(false),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            onReschedule?.call();
            return false;
          } else if (direction == DismissDirection.startToEnd) {
            onComplete?.call();
            return false;
          }
          return false;
        },
        child: card,
      );
    }

    if (timeBlock.isCurrentBlock) {
      return card.animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 3000.ms, color: Colors.white.withValues(alpha: 0.1));
    }

    return card;
  }

  Widget _buildChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground(bool isComplete) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.success : AppColors.warning,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isComplete ? Alignment.centerLeft : Alignment.centerRight,
      child: Icon(
        isComplete ? Icons.check_circle : Icons.schedule,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Color _getBackgroundColor(TaskType? type) {
    if (type == null) return AppColors.surfaceDark.withValues(alpha: 0.5);
    
    switch (type) {
      case TaskType.focus:
        return AppColors.focus.withValues(alpha: 0.15);
      case TaskType.meeting:
        return AppColors.warning.withValues(alpha: 0.15);
      case TaskType.breakTask:
        return AppColors.success.withValues(alpha: 0.15);
      case TaskType.admin:
        return AppColors.secondary.withValues(alpha: 0.15);
    }
  }

  Color _getBorderColor(TaskType? type) {
    if (type == null) return Colors.white.withValues(alpha: 0.1);
    
    switch (type) {
      case TaskType.focus:
        return AppColors.focus;
      case TaskType.meeting:
        return AppColors.warning;
      case TaskType.breakTask:
        return AppColors.success;
      case TaskType.admin:
        return AppColors.secondary;
    }
  }

  Color _getEnergyColor(int energy) {
    if (energy >= 80) return AppColors.success;
    if (energy >= 60) return AppColors.focus;
    if (energy >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}