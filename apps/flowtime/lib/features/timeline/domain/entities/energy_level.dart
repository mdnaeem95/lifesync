import 'package:equatable/equatable.dart';

class EnergyLevel extends Equatable {
  final String id;
  final int level; // 1-100
  final DateTime recordedAt;
  final Map<String, dynamic>? factors; // sleep, exercise, stress, etc.

  const EnergyLevel({
    required this.id,
    required this.level,
    required this.recordedAt,
    this.factors,
  });

  @override
  List<Object?> get props => [id, level, recordedAt, factors];
}