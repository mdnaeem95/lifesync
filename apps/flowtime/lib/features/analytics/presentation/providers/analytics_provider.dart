import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../models/analytics_data.dart';
import '../models/productivity_metrics.dart';
import '../models/energy_pattern_data.dart';

final _logger = Logger('AnalyticsProviders');

// Repository provider
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  _logger.info('Creating AnalyticsRepository instance');
  return AnalyticsRepositoryImpl(ref);
});

// Main analytics data provider
final analyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  _logger.fine('Fetching analytics data');
  
  try {
    final repository = ref.watch(analyticsRepositoryProvider);
    final data = await repository.getAnalyticsOverview();
    
    _logger.info('Analytics data loaded successfully: ${data.totalTasks} total tasks');
    return data;
  } catch (error, stack) {
    _logger.severe('Failed to load analytics data', error, stack);
    rethrow;
  }
});

// Productivity metrics provider
final productivityMetricsProvider = FutureProvider<ProductivityMetrics>((ref) async {
  _logger.fine('Fetching productivity metrics');
  
  try {
    final repository = ref.watch(analyticsRepositoryProvider);
    final metrics = await repository.getProductivityMetrics();
    
    _logger.info('Productivity metrics loaded: ${metrics.completionRate}% completion rate');
    return metrics;
  } catch (error, stack) {
    _logger.severe('Failed to load productivity metrics', error, stack);
    rethrow;
  }
});

// Energy patterns provider
final energyPatternsProvider = FutureProvider<EnergyPatternData>((ref) async {
  _logger.fine('Fetching energy patterns');
  
  try {
    final repository = ref.watch(analyticsRepositoryProvider);
    final patterns = await repository.getEnergyPatterns();
    
    _logger.info('Energy patterns loaded: Peak hour at ${patterns.peakEnergyHour}');
    return patterns;
  } catch (error, stack) {
    _logger.severe('Failed to load energy patterns', error, stack);
    rethrow;
  }
});

// Date range provider for filtering
final analyticsDateRangeProvider = StateProvider<DateRange>((ref) {
  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 7));
  
  _logger.fine('Analytics date range: $startDate to $endDate');
  
  return DateRange(start: startDate, end: endDate);
});

// Filtered analytics provider
final filteredAnalyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  final dateRange = ref.watch(analyticsDateRangeProvider);
  _logger.fine('Fetching filtered analytics for ${dateRange.start} to ${dateRange.end}');
  
  try {
    final repository = ref.watch(analyticsRepositoryProvider);
    final data = await repository.getAnalyticsForDateRange(dateRange);
    
    _logger.info('Filtered analytics loaded: ${data.totalTasks} tasks in range');
    return data;
  } catch (error, stack) {
    _logger.severe('Failed to load filtered analytics', error, stack);
    rethrow;
  }
});

// Task type distribution provider
final taskTypeDistributionProvider = FutureProvider<Map<String, double>>((ref) async {
  _logger.fine('Calculating task type distribution');
  
  try {
    final analytics = await ref.watch(analyticsProvider.future);
    final distribution = analytics.taskTypeDistribution;
    
    _logger.info('Task distribution: Focus ${distribution['focus']}%, Meeting ${distribution['meeting']}%');
    return distribution;
  } catch (error, stack) {
    _logger.severe('Failed to calculate task distribution', error, stack);
    rethrow;
  }
});

// Streak tracking provider
final streakProvider = FutureProvider<StreakData>((ref) async {
  _logger.fine('Fetching streak data');
  
  try {
    final repository = ref.watch(analyticsRepositoryProvider);
    final streaks = await repository.getStreakData();
    
    _logger.info('Streak data: Current ${streaks.currentStreak}, Best ${streaks.bestStreak}');
    return streaks;
  } catch (error, stack) {
    _logger.severe('Failed to load streak data', error, stack);
    rethrow;
  }
});

// Live metrics provider (refreshes periodically)
final liveMetricsProvider = StreamProvider<LiveMetrics>((ref) async* {
  _logger.fine('Starting live metrics stream');
  
  final repository = ref.watch(analyticsRepositoryProvider);
  
  await for (final metrics in repository.getLiveMetrics()) {
    _logger.finest('Live metrics update: Energy ${metrics.currentEnergy}, Active tasks ${metrics.activeTasks}');
    yield metrics;
  }
});

// Models for the providers
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastActiveDate;
  final List<DateTime> streakDates;

  StreakData({
    required this.currentStreak,
    required this.bestStreak,
    this.lastActiveDate,
    required this.streakDates,
  });
}

class LiveMetrics {
  final int currentEnergy;
  final int activeTasks;
  final int completedToday;
  final Duration focusTimeToday;
  final DateTime timestamp;

  LiveMetrics({
    required this.currentEnergy,
    required this.activeTasks,
    required this.completedToday,
    required this.focusTimeToday,
    required this.timestamp,
  });
}