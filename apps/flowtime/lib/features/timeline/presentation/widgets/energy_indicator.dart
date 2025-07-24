import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class EnergyIndicator extends StatelessWidget {
  final int currentLevel;
  final List<int> predictedLevels;

  const EnergyIndicator({
    super.key,
    required this.currentLevel,
    required this.predictedLevels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Current energy circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getEnergyColor(currentLevel),
                  _getEnergyColor(currentLevel).withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Center(
              child: Text(
                '$currentLevel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(width: 12),
          // Energy bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Energy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      _getEnergyDescription(currentLevel),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getEnergyColor(currentLevel),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeOutCubic,
                        width: MediaQuery.of(context).size.width *
                            (currentLevel / 100),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getEnergyColor(currentLevel),
                              _getEnergyColor(currentLevel).withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEnergyColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.focus;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _getEnergyDescription(int level) {
    if (level >= 80) return 'Peak Performance';
    if (level >= 60) return 'Good Focus';
    if (level >= 40) return 'Moderate';
    return 'Low Energy';
  }
}