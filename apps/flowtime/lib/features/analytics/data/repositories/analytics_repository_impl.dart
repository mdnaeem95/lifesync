import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../presentation/models/analytics_data.dart';
import '../../presentation/models/productivity_metrics.dart';
import '../../presentation/models/energy_pattern_data.dart';
import '../../presentation/providers/analytics_provider.dart' as analytics;
import '../../../timeline/presentation/providers/timeline_provider.dart';
import '../../../timeline/presentation/providers/energy_provider.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final Ref _ref;
  final _logger = Logger('AnalyticsRepositoryImpl');

  AnalyticsRepositoryImpl(this._ref);

  @override
  Future<AnalyticsData> getAnalyticsOverview() async {
    _logger.fine('Fetching analytics overview');
    
    try {
      // In a real app, this would fetch from backend
      // For now, we'll aggregate data from existing providers
      
      final timelineState = _ref.read(timelineProvider);
      final timelineData = timelineState.value ?? [];
      final currentEnergy = _ref.read(currentEnergyProvider).value ?? 70;
      
      // Calculate metrics
      final totalTasks = timelineData.where((block) => block.task != null).length;
      final completedTasks = timelineData.where((block) => block.task?.isCompleted ?? false).length;
      final todayBlocks = timelineData.where((block) {
        final now = DateTime.now();
        return block.startTime.year == now.year &&
               block.startTime.month == now.month &&
               block.startTime.day == now.day;
      }).toList();
      
      final todayCompletedTasks = todayBlocks.where((block) => block.task?.isCompleted ?? false).length;
      final todayFocusMinutes = todayBlocks
          .where((block) => block.task?.taskType.name == 'focus')
          .fold(0, (sum, block) => sum + (block.task?.duration.inMinutes ?? 0));
      
      // Generate mock achievements
      final achievements = _generateMockAchievements();
      
      // Generate AI insights
      final insights = _generateAIInsights(totalTasks, completedTasks, currentEnergy);
      
      final data = AnalyticsData(
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        todayCompletedTasks: todayCompletedTasks,
        todayFocusMinutes: todayFocusMinutes,
        currentEnergyLevel: currentEnergy,
        averageCompletionRate: totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0,
        taskTypeDistribution: _calculateTaskDistribution(timelineData),
        flowAchievements: achievements,
        aiInsights: insights,
        lastUpdated: DateTime.now(),
      );
      
      _logger.info('Analytics overview loaded: $totalTasks tasks, $completedTasks completed');
      return data;
    } catch (error, stack) {
      _logger.severe('Failed to fetch analytics overview', error, stack);
      return AnalyticsData.empty();
    }
  }

  @override
  Future<ProductivityMetrics> getProductivityMetrics() async {
    _logger.fine('Fetching productivity metrics');
    
    try {
      // Mock data - replace with actual API calls
      final taskTypeMetrics = {
        'focus': const TaskTypeMetrics(
          taskType: 'Focus',
          totalTasks: 45,
          completedTasks: 38,
          completionRate: 84.4,
          averageDuration: 52,
          typeColor: AppColors.primary,
        ),
        'meeting': const TaskTypeMetrics(
          taskType: 'Meeting',
          totalTasks: 23,
          completedTasks: 21,
          completionRate: 91.3,
          averageDuration: 45,
          typeColor: AppColors.warning,
        ),
        'break': const TaskTypeMetrics(
          taskType: 'Break',
          totalTasks: 30,
          completedTasks: 30,
          completionRate: 100.0,
          averageDuration: 15,
          typeColor: AppColors.success,
        ),
        'admin': const TaskTypeMetrics(
          taskType: 'Admin',
          totalTasks: 15,
          completedTasks: 12,
          completionRate: 80.0,
          averageDuration: 30,
          typeColor: AppColors.secondary,
        ),
      };

      final weeklyTrends = _generateWeeklyTrends();

      final metrics = ProductivityMetrics(
        completionRate: 85.5,
        focusScore: 78.3,
        totalFocusMinutes: 2340,
        averageTaskDuration: 45,
        taskCompletionByType: taskTypeMetrics,
        weeklyTrends: weeklyTrends,
        productivityScore: 82.7,
      );
      
      _logger.info('Productivity metrics loaded: ${metrics.completionRate}% completion rate');
      return metrics;
    } catch (error, stack) {
      _logger.severe('Failed to fetch productivity metrics', error, stack);
      rethrow;
    }
  }

  @override
  Future<EnergyPatternData> getEnergyPatterns() async {
    _logger.fine('Fetching energy patterns');
    
    try {
      final hourlyPattern = List.generate(24, (hour) {
        // Simulate energy pattern based on chronobiology
        double baseEnergy = 50.0;
        if (hour >= 6 && hour <= 10) {
          // Morning peak
          baseEnergy = 70 + (hour - 6) * 5;
        } else if (hour >= 11 && hour <= 13) {
          // Pre-lunch dip
          baseEnergy = 80 - (hour - 11) * 10;
        } else if (hour >= 14 && hour <= 16) {
          // Afternoon dip
          baseEnergy = 50 + (hour - 14) * 5;
        } else if (hour >= 17 && hour <= 19) {
          // Evening recovery
          baseEnergy = 60 + (hour - 17) * 5;
        } else if (hour >= 20 && hour <= 23) {
          // Evening decline
          baseEnergy = 65 - (hour - 20) * 10;
        } else {
          // Night time
          baseEnergy = 25;
        }
        
        return HourlyEnergy(
          hour: hour,
          averageEnergy: baseEnergy + (math.Random().nextDouble() * 10 - 5),
          standardDeviation: 8.5,
          sampleSize: 30,
        );
      });

      final patterns = EnergyPatternData(
        hourlyPattern: hourlyPattern,
        peakEnergyHour: 10,
        lowestEnergyHour: 15,
        optimalFocusHours: [9, 10, 11, 18, 19],
        optimalMeetingHours: [10, 11, 14, 16],
        optimalAdminHours: [14, 15, 16],
        factorImpacts: {
          'Sleep Quality': 15.3,
          'Exercise': 12.7,
          'Nutrition': 8.5,
          'Stress': -11.2,
          'Screen Time': -7.8,
          'Meditation': 6.4,
        },
        chronoType: ChronoType.morningLark,
      );
      
      _logger.info('Energy patterns loaded: Peak at hour ${patterns.peakEnergyHour}');
      return patterns;
    } catch (error, stack) {
      _logger.severe('Failed to fetch energy patterns', error, stack);
      rethrow;
    }
  }

  @override
  Future<AnalyticsData> getAnalyticsForDateRange(analytics.DateRange dateRange) async {
    _logger.fine('Fetching analytics for date range: ${dateRange.start} to ${dateRange.end}');
    
    // For now, return same as overview
    // In real app, would filter by date range
    return getAnalyticsOverview();
  }

  @override
  Future<analytics.StreakData> getStreakData() async {
    _logger.fine('Fetching streak data');
    
    try {
      // Mock streak data
      final streakData = analytics.StreakData(
        currentStreak: 7,
        bestStreak: 14,
        lastActiveDate: DateTime.now().subtract(const Duration(days: 1)),
        streakDates: List.generate(
          7,
          (index) => DateTime.now().subtract(Duration(days: index)),
        ),
      );
      
      _logger.info('Streak data loaded: Current ${streakData.currentStreak} days');
      return streakData;
    } catch (error, stack) {
      _logger.severe('Failed to fetch streak data', error, stack);
      rethrow;
    }
  }

  @override
  Stream<analytics.LiveMetrics> getLiveMetrics() async* {
    _logger.fine('Starting live metrics stream');
    
    // Emit updates every 30 seconds
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      
      final currentEnergy = _ref.read(currentEnergyProvider).value ?? 70;
      final timelineState = _ref.read(timelineProvider);
      final timelineData = timelineState.value ?? [];
      
      final now = DateTime.now();
      final todayTasks = timelineData.where((block) {
        return block.startTime.year == now.year &&
               block.startTime.month == now.month &&
               block.startTime.day == now.day;
      }).toList();
      
      final activeTasks = todayTasks.where((block) => 
        block.task != null && !block.task!.isCompleted
      ).length;
      
      final completedToday = todayTasks.where((block) => 
        block.task?.isCompleted ?? false
      ).length;
      
      final focusTimeToday = Duration(
        minutes: todayTasks
          .where((block) => block.task?.taskType.name == 'focus')
          .fold(0, (sum, block) => sum + (block.task?.duration.inMinutes ?? 0))
      );
      
      final metrics = analytics.LiveMetrics(
        currentEnergy: currentEnergy,
        activeTasks: activeTasks,
        completedToday: completedToday,
        focusTimeToday: focusTimeToday,
        timestamp: DateTime.now(),
      );
      
      _logger.finest('Live metrics update: $activeTasks active, $completedToday completed');
      yield metrics;
    }
  }

  // Helper methods
  Map<String, double> _calculateTaskDistribution(List<dynamic> timelineData) {
    final taskCounts = <String, int>{};
    int totalTasks = 0;
    
    for (final block in timelineData) {
      if (block.task != null) {
        final type = block.task!.taskType.name;
        taskCounts[type] = (taskCounts[type] ?? 0) + 1;
        totalTasks++;
      }
    }
    
    if (totalTasks == 0) return {};
    
    return taskCounts.map((type, count) => 
      MapEntry(type, (count / totalTasks) * 100)
    );
  }

  List<FlowAchievement> _generateMockAchievements() {
    return [
      const FlowAchievement(
        id: '1',
        title: 'Early Bird',
        description: 'Complete 5 tasks before 9 AM',
        iconName: 'sunrise',
        isUnlocked: true,
        unlockedAt: null,
        progress: 1.0,
        level: 1,
      ),
      const FlowAchievement(
        id: '2',
        title: 'Flow Master',
        description: 'Maintain focus for 90 minutes straight',
        iconName: 'focus',
        isUnlocked: true,
        unlockedAt: null,
        progress: 1.0,
        level: 2,
      ),
      const FlowAchievement(
        id: '3',
        title: 'Week Warrior',
        description: 'Complete all tasks for 7 days',
        iconName: 'calendar',
        isUnlocked: false,
        progress: 0.71,
        level: 1,
      ),
    ];
  }

  List<AIInsight> _generateAIInsights(int totalTasks, int completedTasks, int currentEnergy) {
    final insights = <AIInsight>[];
    
    // Completion rate insight
    if (completedTasks > 0) {
      final completionRate = (completedTasks / totalTasks) * 100;
      insights.add(
        AIInsight(
          id: '1',
          title: completionRate > 80 ? 'Excellent Task Completion!' : 'Room for Improvement',
          description: 'Your task completion rate is ${completionRate.toStringAsFixed(1)}%',
          type: InsightType.productivity,
          actionableAdvice: completionRate > 80 
            ? 'Keep up the great work! Consider taking on more challenging tasks.'
            : 'Try breaking down larger tasks into smaller, manageable chunks.',
          confidenceScore: 0.85,
          generatedAt: DateTime.now(),
        ),
      );
    }
    
    // Energy insight
    insights.add(
      AIInsight(
        id: '2',
        title: 'Energy Pattern Detected',
        description: 'Your energy peaks around 10 AM and 6 PM',
        type: InsightType.energyPattern,
        actionableAdvice: 'Schedule your most important tasks during these peak hours for optimal performance.',
        confidenceScore: 0.78,
        generatedAt: DateTime.now(),
      ),
    );
    
    // Scheduling recommendation
    insights.add(
      AIInsight(
        id: '3',
        title: 'Optimize Your Schedule',
        description: 'You tend to overbook Tuesday afternoons',
        type: InsightType.scheduling,
        actionableAdvice: 'Consider spreading tasks more evenly throughout the week to avoid burnout.',
        confidenceScore: 0.82,
        generatedAt: DateTime.now(),
      ),
    );
    
    return insights;
  }

  List<WeeklyTrend> _generateWeeklyTrends() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return WeeklyTrend(
        date: date,
        completedTasks: 8 + (index * 2),
        totalTasks: 10 + index,
        focusMinutes: 180 + (index * 20),
        averageEnergy: 65 + (index * 2.5),
        productivityScore: 75 + (index * 3),
      );
    });
  }
}