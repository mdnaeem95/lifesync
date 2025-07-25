import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import 'dart:math';

class EnergyMeter extends StatelessWidget {
  final int currentLevel;
  final AnimationController animationController;

  const EnergyMeter({
    super.key,
    required this.currentLevel,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring with gradient
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (animationController.value * 0.02),
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: -1.57, // Start from top
                      endAngle: -1.57 + (currentLevel / 100 * 6.28), // Convert to radians
                      colors: _getGradientColors(),
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          // Inner circle
          Container(
            width: 224,
            height: 224,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.backgroundDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Energy percentage
                ShaderMask(
                  shaderCallback: (bounds) => _getEnergyGradient().createShader(bounds),
                  child: Text(
                    '$currentLevel%',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Energy',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getEnergyStatus(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Particles effect
          ..._buildParticles(),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    return [
      AppColors.success,
      AppColors.focus,
      AppColors.primary,
      AppColors.warning,
      AppColors.cardDark,
    ];
  }

  LinearGradient _getEnergyGradient() {
    if (currentLevel >= 80) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.success, AppColors.focus],
      );
    } else if (currentLevel >= 60) {
      return AppColors.focusGradient;
    } else if (currentLevel >= 40) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.warning, AppColors.focus],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.error, AppColors.warning],
      );
    }
  }

  String _getEnergyStatus() {
    if (currentLevel >= 80) return 'Peak Performance';
    if (currentLevel >= 60) return 'High Energy';
    if (currentLevel >= 40) return 'Moderate Energy';
    if (currentLevel >= 20) return 'Low Energy';
    return 'Rest Needed';
  }

  Color _getStatusColor() {
    if (currentLevel >= 80) return AppColors.success;
    if (currentLevel >= 60) return AppColors.primary;
    if (currentLevel >= 40) return AppColors.warning;
    return AppColors.error;
  }

  List<Widget> _buildParticles() {
    return List.generate(6, (index) {
      final angle = index * 60 * 3.14 / 180;
      final radius = 140.0;
      return Positioned(
        left: 120 + radius * cos(angle),
        top: 120 + radius * cos(angle),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor().withValues(alpha: 0.6),
          ),
        ).animate(
          onPlay: (controller) => controller.repeat(),
        ).scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.5, 1.5),
          duration: 2.seconds,
          delay: Duration(milliseconds: index * 200),
        ).fadeOut(
          begin: 1,
          duration: 2.seconds,
          delay: Duration(milliseconds: index * 200),
        ),
      );
    });
  }
}