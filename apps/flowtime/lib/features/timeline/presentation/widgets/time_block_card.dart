import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/time_block.dart';
import '../../domain/entities/task.dart';

class TimeBlockCard extends StatelessWidget {
  final TimeBlock timeBlock;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onReschedule;

  const TimeBlockCard({
    super.key,
    required this.timeBlock,
    required this.onTap,
    this.onComplete,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    if (timeBlock.task == null) {
      return _buildEmptyBlock(context);
    }

    return _buildTaskBlock(context);
  }

  Widget _buildEmptyBlock(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            style: BorderStyle.dotted,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: Colors.grey[600],
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskBlock(BuildContext context) {
    final task = timeBlock.task!;
    final color = _getTaskColor(task.taskType);
    final isOverdue = !task.isCompleted && 
        task.scheduledAt.isBefore(DateTime.now());

    return GestureDetector(
      onTap: onTap,
      onLongPress: onReschedule,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? AppColors.error : color,
            width: timeBlock.isCurrentBlock ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and energy
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.isFlexible)
                        Icon(
                          Icons.swap_vert,
                          size: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                    ],
                  ),
                  
                  if (task.description != null && 
                      timeBlock.duration.inMinutes > 30) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // Footer with duration and energy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Duration
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(task.duration),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      
                      // Energy indicator
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < task.energyRequired
                                  ? Icons.bolt
                                  : Icons.bolt_outlined,
                              size: 10,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Complete button for current tasks
                  if (timeBlock.isCurrentBlock && onComplete != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        onPressed: onComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Mark Complete',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTaskColor(TaskType type) {
    switch (type) {
      case TaskType.focus:
        return AppColors.primary;
      case TaskType.meeting:
        return AppColors.secondary;
      case TaskType.break:
        return AppColors.energyHigh;
      case TaskType.admin:
        return AppColors.warning;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}