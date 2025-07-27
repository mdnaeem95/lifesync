import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../providers/focus_session_provider.dart';

// Progress Ring Painter
class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ProgressRingPainter({
    required this.progress,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius - 4, backgroundPaint);
    
    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    final progressAngle = 2 * math.pi * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Protocol Picker Sheet
class ProtocolPickerSheet extends StatelessWidget {
  final FocusProtocol selectedProtocol;
  final Function(FocusProtocol, int) onProtocolSelected;
  
  const ProtocolPickerSheet({
    required this.selectedProtocol,
    required this.onProtocolSelected,
  });
  
  @override
  Widget build(BuildContext context) {
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
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text(
            'Choose Focus Protocol',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          ...FocusProtocol.values.map((protocol) {
            final isSelected = protocol == selectedProtocol;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  onProtocolSelected(protocol, protocol.defaultDuration.inSeconds);
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? AppColors.primary 
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary 
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getProtocolIcon(protocol),
                          color: isSelected 
                              ? Colors.white 
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              protocol.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              protocol.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ).animate()
                  .fadeIn(delay: Duration(milliseconds: protocol.index * 100))
                  .slideX(begin: 0.1),
            );
          }),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  IconData _getProtocolIcon(FocusProtocol protocol) {
    switch (protocol) {
      case FocusProtocol.pomodoro:
        return Icons.timer;
      case FocusProtocol.timeboxing:
        return Icons.view_module;
      case FocusProtocol.deepWork:
        return Icons.psychology;
      case FocusProtocol.custom:
        return Icons.tune;
    }
  }
}

// Session Completion Dialog
class SessionCompletionDialog extends StatelessWidget {
  final int sessionDuration;
  final VoidCallback onContinue;
  final VoidCallback onFinish;
  
  const SessionCompletionDialog({
    required this.sessionDuration,
    required this.onContinue,
    required this.onFinish,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 48,
                color: AppColors.success,
              ),
            ).animate()
                .scale(begin: const Offset(0, 0), duration: 600.ms)
                .then()
                .shake(duration: 300.ms),
            
            const SizedBox(height: 24),
            
            Text(
              'Great Focus!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate()
                .fadeIn(delay: 300.ms)
                .slideY(begin: 0.2),
            
            const SizedBox(height: 8),
            
            Text(
              'You completed ${sessionDuration ~/ 60} minutes',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ).animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.2),
            
            const SizedBox(height: 32),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onFinish,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Finish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ).animate()
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }
}

// Quick Focus Stats Widget (for dashboard integration)
class FocusStatsCard extends StatelessWidget {
  final int todayMinutes;
  final int weekStreak;
  final int sessionsToday;
  
  const FocusStatsCard({
    super.key,
    required this.todayMinutes,
    required this.weekStreak,
    required this.sessionsToday,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Focus Stats',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'Today',
                value: '${todayMinutes}m',
                icon: Icons.timer,
              ),
              _StatItem(
                label: 'Streak',
                value: '$weekStreak days',
                icon: Icons.whatshot,
              ),
              _StatItem(
                label: 'Sessions',
                value: sessionsToday.toString(),
                icon: Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}