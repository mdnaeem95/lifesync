import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../timeline/presentation/providers/energy_provider.dart';
import '../widgets/energy_meter.dart';
import '../widgets/energy_graph.dart';
import '../widgets/energy_factors_grid.dart';
import '../widgets/energy_insights_card.dart';
import '../widgets/optimal_timing_card.dart';

class EnergyDashboardScreen extends ConsumerStatefulWidget {
  const EnergyDashboardScreen({super.key});

  @override
  ConsumerState<EnergyDashboardScreen> createState() => _EnergyDashboardScreenState();
}

class _EnergyDashboardScreenState extends ConsumerState<EnergyDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEnergy = ref.watch(currentEnergyProvider);
    final predictedEnergy = ref.watch(predictedEnergyLevelsProvider);
    final energyInsights = ref.watch(energyInsightsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar with Aura Orb
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.8),
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Title
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Energy Dashboard',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                foreground: Paint()
                                  ..shader = AppColors.primaryGradient.createShader(
                                    const Rect.fromLTWH(0, 0, 200, 50),
                                  ),
                              ),
                            ).animate().fadeIn().slideX(),
                            const SizedBox(height: 4),
                            Text(
                              _getDateString(),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ).animate().fadeIn(delay: 100.ms),
                          ],
                        ),
                      ),
                      // Aura Orb
                      _buildAuraOrb(currentEnergy.value ?? 70),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Energy Meter
                  currentEnergy.when(
                    data: (level) => EnergyMeter(
                      currentLevel: level,
                      animationController: _animationController,
                    ).animate().fadeIn().scale(),
                    loading: () => const EnergyMeterSkeleton(),
                    error: (_, __) => const EnergyMeterError(),
                  ),
                  const SizedBox(height: 32),

                  // 24-Hour Energy Forecast
                  _buildSectionCard(
                    title: '24-Hour Energy Forecast',
                    subtitle: 'Today → Tomorrow',
                    child: predictedEnergy.when(
                      data: (levels) => EnergyGraph(
                        energyLevels: levels,
                        currentHour: DateTime.now().hour,
                      ),
                      loading: () => const EnergyGraphSkeleton(),
                      error: (_, __) => const EnergyGraphError(),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),

                  // Energy Factors
                  Text(
                    'Energy Factors',
                    style: Theme.of(context).textTheme.titleLarge,
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 16),
                  const EnergyFactorsGrid()
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 24),

                  // AI Insights
                  energyInsights.when(
                    data: (insights) => EnergyInsightsCard(
                      insights: insights,
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                    loading: () => const EnergyInsightsCardSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // Optimal Task Timing
                  Text(
                    'Optimal Task Timing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 16),
                  energyInsights.when(
                    data: (insights) => OptimalTimingCard(
                      peakHour: insights.peakEnergyHour,
                      lowHour: insights.lowEnergyHour,
                    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
                    loading: () => const OptimalTimingCardSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 80), // Bottom nav spacing
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAuraOrb(int energyLevel) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getEnergyGradient(energyLevel),
        boxShadow: [
          BoxShadow(
            color: _getEnergyColor(energyLevel).withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$energyLevel',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.1, 1.1),
      duration: 2.seconds,
      curve: Curves.easeInOut,
    ).then().scale(
      begin: const Offset(1.1, 1.1),
      end: const Offset(1, 1),
      duration: 2.seconds,
      curve: Curves.easeInOut,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        backgroundBlendMode: BlendMode.overlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Required for 5 items
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: 1, // Energy is index 1
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/timeline');
              break;
            case 1:
              break; // Already on energy
            case 2:
              context.go('/planning');
              break;
            case 3:
              context.go('/insights');
              break;
            case 4:
              context.go('/focus');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Energy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_week),
            label: 'Planning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Focus',
          ),
        ],
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    final weekday = _getWeekday(now.weekday);
    final month = _getMonth(now.month);
    return '$weekday, $month ${now.day}';
  }

  String _getWeekday(int day) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return weekdays[day - 1];
  }

  String _getMonth(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  LinearGradient _getEnergyGradient(int level) {
    if (level >= 80) {
      return LinearGradient(
        colors: [AppColors.success, AppColors.focus],
      );
    } else if (level >= 60) {
      return LinearGradient(
        colors: [AppColors.focus, AppColors.primary],
      );
    } else if (level >= 40) {
      return LinearGradient(
        colors: [AppColors.warning, AppColors.focus],
      );
    } else {
      return LinearGradient(
        colors: [AppColors.error, AppColors.warning],
      );
    }
  }

  Color _getEnergyColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.primary;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

// Skeleton Loaders
class EnergyMeterSkeleton extends StatelessWidget {
  const EnergyMeterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceDark,
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(),
      ).shimmer(
        duration: 1.5.seconds,
        color: AppColors.borderSubtle,
      ),
    );
  }
}

class EnergyGraphSkeleton extends StatelessWidget {
  const EnergyGraphSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: 1.5.seconds,
      color: AppColors.borderSubtle,
    );
  }
}

class EnergyInsightsCardSkeleton extends StatelessWidget {
  const EnergyInsightsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryDark.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: 1.5.seconds,
      color: AppColors.borderSubtle,
    );
  }
}

class OptimalTimingCardSkeleton extends StatelessWidget {
  const OptimalTimingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(width: 60, height: 20),
              ),
            ],
          ),
        ),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: 1.5.seconds,
      color: AppColors.borderSubtle,
    );
  }
}

// Error States
class EnergyMeterError extends StatelessWidget {
  const EnergyMeterError({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load energy data',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class EnergyGraphError extends StatelessWidget {
  const EnergyGraphError({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Text(
        'Energy predictions unavailable',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}