import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class EnergyFactorsGrid extends StatelessWidget {
  const EnergyFactorsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final factors = [
      FactorData(
        icon: '😴',
        label: 'Sleep Quality',
        value: '7.5 hours • 85%',
        color: AppColors.primaryDark,
      ),
      FactorData(
        icon: '🏃',
        label: 'Activity',
        value: '8,432 steps',
        color: AppColors.success,
      ),
      FactorData(
        icon: '🥗',
        label: 'Nutrition',
        value: 'Balanced',
        color: AppColors.warning,
      ),
      FactorData(
        icon: '🧘',
        label: 'Stress Level',
        value: 'Low',
        color: AppColors.error,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: factors.length,
      itemBuilder: (context, index) {
        final factor = factors[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: factor.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    factor.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    factor.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    factor.value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(
          delay: Duration(milliseconds: index * 100),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
      },
    );
  }
}

class FactorData {
  final String icon;
  final String label;
  final String value;
  final Color color;

  FactorData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}