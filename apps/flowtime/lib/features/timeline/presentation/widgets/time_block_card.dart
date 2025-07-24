import 'package:flutter/material.dart';
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

    Widget card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEmpty
              ? AppColors.surfaceDark.withValues(alpha: 0.5)
              : _getBackgroundColor(task.taskType),
          borderRadius: BorderRadius.circular(16),
          border: timeBlock.isCurrentBlock
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${timeBlock.startTime.hour.toString().padLeft(2, '0')}:${timeBlock.startTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (!isEmpty && task.isFlexible)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Flexible',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (!isEmpty && task.isCompleted)
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isEmpty ? 'Free time' : task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isEmpty 
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
                decoration: task?.isCompleted ?? false
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (!isEmpty && task.description != null) ...[
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
                if (!isEmpty) ...[
                  _buildChip(
                    Icons.timer,
                    '${task.duration.inMinutes} min',
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    Icons.bolt,
                    'Energy: ${task.energyRequired}/5',
                    color: _getEnergyColor(task.energyRequired),
                  ),
                ],
                const Spacer(),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getEnergyColor(timeBlock.predictedEnergyLevel),
                    border: Border.all(
                      color: _getEnergyBorderColor(timeBlock.predictedEnergyLevel),
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

    // Add highlight effect for current block without continuous animation
    if (timeBlock.isCurrentBlock) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: card,
      );
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
    if (type == null) return AppColors.surfaceDark;
    
    switch (type) {
      case TaskType.focus:
        return AppColors.primary;
      case TaskType.meeting:
        return AppColors.secondary;
      case TaskType.breakTask:
        return AppColors.success;
      case TaskType.admin:
        return AppColors.warning;
    }
  }

  Color _getEnergyColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.primary;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Color _getEnergyBorderColor(int level) {
    return _getEnergyColor(level).withValues(alpha: 0.5);
  }
}