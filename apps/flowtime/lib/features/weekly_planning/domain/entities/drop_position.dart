import 'package:equatable/equatable.dart';

class DropPosition extends Equatable {
  final int dayIndex; // 0-6 (Mon-Sun)
  final int hour; // 0-23
  final int minute; // 0-59
  final bool isValid;
  final String? conflictingTaskId;

  const DropPosition({
    required this.dayIndex,
    required this.hour,
    this.minute = 0,
    this.isValid = true,
    this.conflictingTaskId,
  });

  DateTime toDateTime(DateTime weekStart) {
    return weekStart.add(Duration(
      days: dayIndex,
      hours: hour - weekStart.hour,
      minutes: minute - weekStart.minute,
    ));
  }

  bool hasConflict() => conflictingTaskId != null;

  @override
  List<Object?> get props => [
        dayIndex,
        hour,
        minute,
        isValid,
        conflictingTaskId,
      ];
}