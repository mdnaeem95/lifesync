import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/energy_level.dart';

// Current energy level provider
final currentEnergyProvider = StateProvider<AsyncValue<int>>((ref) {
  // TODO: Fetch from actual data source
  return const AsyncValue.data(75);
});

// Predicted energy levels for the day
final predictedEnergyLevelsProvider = StateProvider<AsyncValue<List<EnergyPrediction>>>((ref) {
  // TODO: Implement ML-based prediction
  final predictions = <EnergyPrediction>[];
  final now = DateTime.now();
  
  for (var hour = 0; hour < 24; hour++) {
    final time = DateTime(now.year, now.month, now.day, hour);
    predictions.add(EnergyPrediction(
      time: time,
      level: _calculateEnergyLevel(hour),
    ));
  }
  
  return AsyncValue.data(predictions);
});

int _calculateEnergyLevel(int hour) {
  // Simple energy curve simulation
  if (hour >= 6 && hour <= 9) return 70 + (hour - 6) * 5; // Morning rise
  if (hour >= 10 && hour <= 12) return 85; // Peak morning
  if (hour >= 13 && hour <= 15) return 60; // Post-lunch dip
  if (hour >= 16 && hour <= 18) return 70; // Afternoon recovery
  if (hour >= 19 && hour <= 21) return 65; // Evening
  if (hour >= 22 || hour <= 5) return 40; // Night/Sleep
  return 50;
}

class EnergyPrediction {
  final DateTime time;
  final int level;

  EnergyPrediction({required this.time, required this.level});
}

// Energy history provider
final energyHistoryProvider = FutureProvider.family<List<EnergyLevel>, DateRange>((ref, range) async {
  // TODO: Fetch from database
  await Future.delayed(const Duration(milliseconds: 500));
  
  final history = <EnergyLevel>[];
  var current = range.start;
  
  while (current.isBefore(range.end)) {
    history.add(EnergyLevel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      level: 50 + (DateTime.now().millisecondsSinceEpoch % 50),
      recordedAt: current,
      factors: {
        'sleep': 7.5,
        'exercise': true,
        'stress': 3,
      },
    ));
    current = current.add(const Duration(hours: 1));
  }
  
  return history;
});

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}