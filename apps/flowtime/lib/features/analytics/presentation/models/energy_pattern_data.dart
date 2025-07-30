import 'package:equatable/equatable.dart';

class EnergyPatternData extends Equatable {
  final List<HourlyEnergy> hourlyPattern;
  final int peakEnergyHour;
  final int lowestEnergyHour;
  final List<int> optimalFocusHours;
  final List<int> optimalMeetingHours;
  final List<int> optimalAdminHours;
  final Map<String, double> factorImpacts;
  final ChronoType chronoType;

  const EnergyPatternData({
    required this.hourlyPattern,
    required this.peakEnergyHour,
    required this.lowestEnergyHour,
    required this.optimalFocusHours,
    required this.optimalMeetingHours,
    required this.optimalAdminHours,
    required this.factorImpacts,
    required this.chronoType,
  });

  @override
  List<Object?> get props => [
        hourlyPattern,
        peakEnergyHour,
        lowestEnergyHour,
        optimalFocusHours,
        optimalMeetingHours,
        optimalAdminHours,
        factorImpacts,
        chronoType,
      ];
}

class HourlyEnergy extends Equatable {
  final int hour;
  final double averageEnergy;
  final double standardDeviation;
  final int sampleSize;

  const HourlyEnergy({
    required this.hour,
    required this.averageEnergy,
    required this.standardDeviation,
    required this.sampleSize,
  });

  @override
  List<Object?> get props => [hour, averageEnergy, standardDeviation, sampleSize];
}

enum ChronoType {
  morningLark,
  nightOwl,
  thirdBird,
}

extension ChronoTypeExtension on ChronoType {
  String get displayName {
    switch (this) {
      case ChronoType.morningLark:
        return 'Morning Lark';
      case ChronoType.nightOwl:
        return 'Night Owl';
      case ChronoType.thirdBird:
        return 'Third Bird';
    }
  }

  String get description {
    switch (this) {
      case ChronoType.morningLark:
        return 'Peak performance in the morning hours';
      case ChronoType.nightOwl:
        return 'Most productive in the evening and night';
      case ChronoType.thirdBird:
        return 'Balanced energy throughout the day';
    }
  }
}