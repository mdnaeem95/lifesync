import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class FloatingAddButton extends StatefulWidget {
  final AnimationController animationController;
  final VoidCallback onPressed;

  const FloatingAddButton({
    super.key,
    required this.animationController,
    required this.onPressed,
  });

  @override
  State<FloatingAddButton> createState() => _FloatingAddButtonState();
}

class _FloatingAddButtonState extends State<FloatingAddButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      widget.animationController.forward();
    } else {
      widget.animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quick action buttons
        if (_isExpanded) ...[
          _buildQuickActionButton(
            icon: Icons.bolt,
            label: 'Quick Task',
            color: AppColors.primary,
            onTap: () {
              _toggleExpanded();
              widget.onPressed();
            },
          ).animate().fadeIn().slideY(begin: 0.5),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.coffee,
            label: 'Break',
            color: AppColors.energyHigh,
            onTap: () {
              _toggleExpanded();
              // TODO: Add break
            },
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.5),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.meeting_room,
            label: 'Meeting',
            color: AppColors.secondary,
            onTap: () {
              _toggleExpanded();
              // TODO: Add meeting
            },
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.5),
          const SizedBox(height: 16),
        ],
        
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleExpanded,
          backgroundColor: AppColors.primary,
          child: AnimatedIcon(
            icon: AnimatedIcons.add_event,
            progress: widget.animationController,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}