import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import './date_provider.dart';

// Current energy level provider
final currentEnergyProvider = FutureProvider<int>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  
  try {
    final response = await apiClient.get(ApiEndpoints.energyCurrent);
    return response.data['level'] as int;
  } catch (e) {
    // Return default energy if API fails
    return 75;
  }
});

// Predicted energy levels for the day (24 hours)
final predictedEnergyLevelsProvider = FutureProvider<List<int>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  
  try {
    final response = await apiClient.get(
      '${ApiEndpoints.energy}/predictions',
      queryParameters: {
        'date': selectedDate.toIso8601String().split('T')[0],
      },
    );
    
    return List<int>.from(response.data['predictions']);
  } catch (e) {
    // Return default energy pattern if API fails
    return _generateDefaultEnergyPattern();
  }
});

// Energy history provider
final energyHistoryProvider = FutureProvider.family<List<EnergyReading>, DateRange>((ref, dateRange) async {
  final apiClient = ref.watch(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '${ApiEndpoints.energy}/history',
      queryParameters: {
        'start_date': dateRange.start.toIso8601String(),
        'end_date': dateRange.end.toIso8601String(),
      },
    );
    
    return (response.data['readings'] as List)
        .map((json) => EnergyReading.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
});

// Record energy level
final recordEnergyProvider = StateNotifierProvider<RecordEnergyNotifier, AsyncValue<void>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RecordEnergyNotifier(apiClient);
});

class RecordEnergyNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _apiClient;

  RecordEnergyNotifier(this._apiClient) : super(const AsyncValue.data(null));

  Future<void> recordEnergy(int level, {Map<String, dynamic>? factors}) async {
    state = const AsyncValue.loading();
    
    try {
      await _apiClient.post(
        ApiEndpoints.energy,
        data: {
          'level': level,
          'factors': factors ?? {},
          'source': 'manual',
        },
      );
      
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}

// Helper function to generate default energy pattern
List<int> _generateDefaultEnergyPattern() {
  // Based on typical chronobiology patterns
  return [
    30, 25, 20, 20, 25, 30, // 12 AM - 5 AM (sleeping)
    40, 50, 60, 75, 85, 90, // 6 AM - 11 AM (morning peak)
    85, 75, 65, 55, 50, 55, // 12 PM - 5 PM (afternoon dip)
    65, 70, 65, 55, 45, 35, // 6 PM - 11 PM (evening decline)
  ];
}

// Models
class EnergyReading {
  final int level;
  final DateTime recordedAt;
  final Map<String, dynamic> factors;

  EnergyReading({
    required this.level,
    required this.recordedAt,
    required this.factors,
  });

  factory EnergyReading.fromJson(Map<String, dynamic> json) {
    return EnergyReading(
      level: json['level'],
      recordedAt: DateTime.parse(json['recorded_at']),
      factors: json['factors'] ?? {},
    );
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

// Energy insights provider
final energyInsightsProvider = FutureProvider<EnergyInsights>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  
  try {
    final response = await apiClient.get('${ApiEndpoints.energy}/insights');
    return EnergyInsights.fromJson(response.data);
  } catch (e) {
    return EnergyInsights.empty();
  }
});

class EnergyInsights {
  final int averageEnergy;
  final int peakEnergyHour;
  final int lowEnergyHour;
  final List<String> recommendations;
  final Map<String, double> factorImpacts;

  EnergyInsights({
    required this.averageEnergy,
    required this.peakEnergyHour,
    required this.lowEnergyHour,
    required this.recommendations,
    required this.factorImpacts,
  });

  factory EnergyInsights.fromJson(Map<String, dynamic> json) {
    return EnergyInsights(
      averageEnergy: json['average_energy'],
      peakEnergyHour: json['peak_energy_hour'],
      lowEnergyHour: json['low_energy_hour'],
      recommendations: List<String>.from(json['recommendations']),
      factorImpacts: Map<String, double>.from(json['factor_impacts']),
    );
  }

  factory EnergyInsights.empty() {
    return EnergyInsights(
      averageEnergy: 70,
      peakEnergyHour: 10,
      lowEnergyHour: 15,
      recommendations: [],
      factorImpacts: {},
    );
  }
}