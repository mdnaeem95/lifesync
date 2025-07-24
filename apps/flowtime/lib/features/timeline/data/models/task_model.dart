import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_model.freezed.dart';
part 'task_model.g.dart';

@freezed
class TaskModel with _$TaskModel {
  const factory TaskModel({
    required String id,
    required String title,
    String? description,
    required DateTime scheduledAt,
    required int duration,
    required String taskType,
    required String priority,
    required int energyRequired,
    required bool isCompleted,
    required bool isFlexible,
    DateTime? completedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    Map<String, dynamic>? metadata,
  }) = _TaskModel;

  factory TaskModel.fromJson(Map<String, dynamic> json) => 
      _$TaskModelFromJson(json);
}