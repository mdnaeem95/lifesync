import 'package:equatable/equatable.dart';
import 'task.dart';

class TimeBlock extends Equatable {
  final DateTime startTime;
  final DateTime endTime;
  final Task? task;
  final int predictedEnergyLevel;
  final bool isCurrentBlock;

  const TimeBlock({
    required this.startTime,
    required this.endTime,
    this.task,
    required this.predictedEnergyLevel,
    required this.isCurrentBlock,
  });

  Duration get duration => endTime.difference(startTime);

  bool get isFreeTime => task == null;

  @override
  List<Object?> get props => [
        startTime,
        endTime,
        task,
        predictedEnergyLevel,
        isCurrentBlock,
      ];
}