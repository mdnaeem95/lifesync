import 'package:equatable/equatable.dart';
import '../../presentation/providers/focus_session_provider.dart';

class FocusSession extends Equatable {
  final String id;
  final String userId;
  final String? taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration plannedDuration;
  final Duration? actualDuration;
  final FocusProtocol focusProtocol;
  final int interruptions;
  final int? energyLevelStart;
  final int? energyLevelEnd;
  final String? notes;
  final DateTime createdAt;
  final bool isPaused;
  
  const FocusSession({
    required this.id,
    required this.userId,
    this.taskId,
    required this.startedAt,
    this.endedAt,
    required this.plannedDuration,
    this.actualDuration,
    required this.focusProtocol,
    this.interruptions = 0,
    this.energyLevelStart,
    this.energyLevelEnd,
    this.notes,
    DateTime? createdAt,
    this.isPaused = false,
  }) : createdAt = createdAt ?? startedAt;
  
  FocusSession copyWith({
    String? id,
    String? userId,
    String? taskId,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? plannedDuration,
    Duration? actualDuration,
    FocusProtocol? focusProtocol,
    int? interruptions,
    int? energyLevelStart,
    int? energyLevelEnd,
    String? notes,
    DateTime? createdAt,
    bool? isPaused,
  }) {
    return FocusSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      actualDuration: actualDuration ?? this.actualDuration,
      focusProtocol: focusProtocol ?? this.focusProtocol,
      interruptions: interruptions ?? this.interruptions,
      energyLevelStart: energyLevelStart ?? this.energyLevelStart,
      energyLevelEnd: energyLevelEnd ?? this.energyLevelEnd,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isPaused: isPaused ?? this.isPaused,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'task_id': taskId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'planned_duration': plannedDuration.inMinutes,
      'actual_duration': actualDuration?.inMinutes,
      'focus_protocol': focusProtocol.name,
      'interruptions': interruptions,
      'energy_level_start': energyLevelStart,
      'energy_level_end': energyLevelEnd,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'],
      userId: json['user_id'],
      taskId: json['task_id'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      plannedDuration: Duration(minutes: json['planned_duration']),
      actualDuration: json['actual_duration'] != null 
          ? Duration(minutes: json['actual_duration']) 
          : null,
      focusProtocol: FocusProtocol.values.firstWhere(
        (p) => p.name == json['focus_protocol'],
        orElse: () => FocusProtocol.pomodoro,
      ),
      interruptions: json['interruptions'] ?? 0,
      energyLevelStart: json['energy_level_start'],
      energyLevelEnd: json['energy_level_end'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    userId,
    taskId,
    startedAt,
    endedAt,
    plannedDuration,
    actualDuration,
    focusProtocol,
    interruptions,
    energyLevelStart,
    energyLevelEnd,
    notes,
    createdAt,
    isPaused,
  ];
}