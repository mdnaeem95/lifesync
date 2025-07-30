import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/analytics_provider.dart';
import '../models/analytics_data.dart';
import '../models/energy_pattern_data.dart';
import '../widgets/productivity_metrics_card.dart';
import '../widgets/energy_pattern_chart.dart';
import '../widgets/task_completion_chart.dart';
import '../widgets/flow_state_achievements.dart';
import '../widgets/weekly_trends_chart.dart';
import '../widgets/ai_insights_card.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> 
    with SingleTickerProviderStateMixin {
  final _logger = Logger('AnalyticsScreen');
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _logger.info('AnalyticsScreen initialized');
    _tabController = TabController(length: 3, vsync: this);
    
    // Log tab changes for debugging
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _logger.fine('Tab changed to index: ${_tabController.index}');
      }
    });
  }

  @override
  void dispose() {
    _logger.info('AnalyticsScreen disposed');
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.finest('Building AnalyticsScreen');
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Productivity'),
            Tab(text: 'Patterns'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildProductivityTab(),
          _buildPatternsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    _logger.fine('Building Overview tab');
    
    final analyticsState = ref.watch(analyticsProvider);
    
    return analyticsState.when(
      data: (data) {
        _logger.fine('Analytics data loaded: ${data.totalTasks} tasks');
        
        return RefreshIndicator(
          onRefresh: () => ref.refresh(analyticsProvider.future),
          color: AppColors.primary,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Summary
                _buildSectionHeader('Today\'s Summary'),
                const SizedBox(height: 12),
                _buildTodaySummaryCards(data).animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.1),
                
                const SizedBox(height: 24),
                
                // Flow State Achievements
                _buildSectionHeader('Flow State Achievements'),
                const SizedBox(height: 12),
                FlowStateAchievements(
                  achievements: data.flowAchievements,
                ).animate()
                    .fadeIn(delay: 200.ms, duration: 600.ms)
                    .slideX(begin: -0.1),
                
                const SizedBox(height: 24),
                
                // AI Insights
                _buildSectionHeader('AI Insights'),
                const SizedBox(height: 12),
                AIInsightsCard(
                  insights: data.aiInsights,
                ).animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
              ],
            ),
          ),
        );
      },
      loading: () {
        _logger.fine('Loading analytics data...');
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      },
      error: (error, stack) {
        _logger.severe('Error loading analytics', error, stack);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Failed to load analytics'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(analyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductivityTab() {
    _logger.fine('Building Productivity tab');
    
    final productivityData = ref.watch(productivityMetricsProvider);
    
    return productivityData.when(
      data: (data) {
        _logger.fine('Productivity data loaded: ${data.completionRate}% completion rate');
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Productivity Score
              ProductivityMetricsCard(
                metrics: data,
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.9, 0.9)),
              
              const SizedBox(height: 20),
              
              // Task Completion by Type
              _buildSectionHeader('Task Completion by Type'),
              const SizedBox(height: 12),
              TaskCompletionChart(
                completionData: data.taskCompletionByType,
              ).animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms),
              
              const SizedBox(height: 20),
              
              // Weekly Trends
              _buildSectionHeader('Weekly Trends'),
              const SizedBox(height: 12),
              WeeklyTrendsChart(
                trendData: data.weeklyTrends,
              ).animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (error, stack) {
        _logger.severe('Error loading productivity metrics', error, stack);
        return _buildErrorWidget(() => ref.refresh(productivityMetricsProvider));
      },
    );
  }

  Widget _buildPatternsTab() {
    _logger.fine('Building Patterns tab');
    
    final patternsData = ref.watch(energyPatternsProvider);
    
    return patternsData.when(
      data: (data) {
        _logger.fine('Energy patterns loaded: Peak hour at ${data.peakEnergyHour}');
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Energy Patterns
              _buildSectionHeader('Energy Patterns'),
              const SizedBox(height: 12),
              EnergyPatternChart(
                patterns: data,
              ).animate()
                  .fadeIn(duration: 600.ms),
              
              const SizedBox(height: 20),
              
              // Best Times for Tasks
              _buildSectionHeader('Optimal Task Timing'),
              const SizedBox(height: 12),
              _buildOptimalTimingCards(data).animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms),
              
              const SizedBox(height: 20),
              
              // Energy Factors
              _buildSectionHeader('Energy Impact Factors'),
              const SizedBox(height: 12),
              _buildEnergyFactorsCard(data.factorImpacts).animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (error, stack) {
        _logger.severe('Error loading energy patterns', error, stack);
        return _buildErrorWidget(() => ref.refresh(energyPatternsProvider));
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTodaySummaryCards(AnalyticsData data) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Tasks Completed',
            '${data.todayCompletedTasks}',
            Icons.check_circle_outline,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Focus Time',
            '${data.todayFocusMinutes} min',
            Icons.timer_outlined,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Energy',
            '${data.currentEnergyLevel}%',
            Icons.battery_charging_full,
            _getEnergyColor(data.currentEnergyLevel),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimalTimingCards(EnergyPatternData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          _buildTimingRow('Deep Focus', data.optimalFocusHours, Icons.psychology, AppColors.primary),
          const Divider(height: 24),
          _buildTimingRow('Meetings', data.optimalMeetingHours, Icons.groups, AppColors.warning),
          const Divider(height: 24),
          _buildTimingRow('Admin Tasks', data.optimalAdminHours, Icons.task_alt, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildTimingRow(String taskType, List<int> hours, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            taskType,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          hours.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', '),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyFactorsCard(Map<String, double> factors) {
    final sortedFactors = factors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: sortedFactors.map((entry) {
          final impact = entry.value;
          final color = impact > 0 ? AppColors.success : AppColors.error;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${impact > 0 ? '+' : ''}${impact.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorWidget(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Something went wrong'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Color _getEnergyColor(int level) {
    if (level >= 80) return AppColors.success;
    if (level >= 60) return AppColors.primary;
    if (level >= 40) return AppColors.warning;
    return AppColors.error;
  }
}