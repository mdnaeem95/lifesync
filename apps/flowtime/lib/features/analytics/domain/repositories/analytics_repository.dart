import '../../../analytics/presentation/models/analytics_data.dart';
import '../../../analytics/presentation/models/productivity_metrics.dart';
import '../../../analytics/presentation/models/energy_pattern_data.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsData> getAnalyticsOverview();
  Future<ProductivityMetrics> getProductivityMetrics();
  Future<EnergyPatternData> getEnergyPatterns();
  Future<AnalyticsData> getAnalyticsForDateRange(DateRange dateRange);
  Future<StreakData> getStreakData();
  Stream<LiveMetrics> getLiveMetrics();
}