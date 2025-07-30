import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../timeline/domain/entities/task.dart';

class DraggableTaskCard extends StatelessWidget {
  final Task task;
  final bool isDragging;
  final VoidCallback? onTap;
  final _logger = Logger('DraggableTaskCard');

  DraggableTaskCard({
    super.key,
    required this.task,
    required this.isDragging,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    _logger.finest('Building card for task: ${task.title}, isDragging: $isDragging');
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getTaskColor(task.taskType).withValues(alpha: isDragging ? 0.8 : 1.0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getTaskBorderColor(task.taskType),
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Task title
            Text(
              task.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getTaskTextColor(task.taskType),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Duration and energy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.duration.inMinutes}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: _getTaskTextColor(task.taskType).withValues(alpha: 0.8),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 12,
                      color: _getEnergyColor(task.energyRequired),
                    ),
                    Text(
                      '${task.energyRequired}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getTaskTextColor(task.taskType).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Flexibility indicator
            if (task.isFlexible)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 10,
                      color: _getTaskTextColor(task.taskType),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Flexible',
                      style: TextStyle(
                        fontSize: 9,
                        color: _getTaskTextColor(task.taskType),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(TaskType type) {
    switch (type) {
      case TaskType.focus:
        return AppColors.focus;
      case TaskType.meeting:
        return AppColors.meeting;
      case TaskType.admin:
        return AppColors.admin;
      case TaskType.breakTask:
        return AppColors.breakTask;
    }
  }

  Color _getTaskBorderColor(TaskType type) {
    switch (type) {
      case TaskType.focus:
        return AppColors.focus.withValues(alpha: 0.8);
      case TaskType.meeting:
        return AppColors.meeting.withValues(alpha: 0.8);
      case TaskType.admin:
        return AppColors.admin.withValues(alpha: 0.8);
      case TaskType.breakTask:
        return AppColors.breakTask.withValues(alpha: 0.8);
    }
  }

  Color _getTaskTextColor(TaskType type) {
    // All task types use white text on their colored backgrounds
    return Colors.white;
  }

  Color _getEnergyColor(int level) {
    if (level >= 4) return AppColors.error;
    if (level >= 3) return AppColors.warning;
    return AppColors.success;
  }
}