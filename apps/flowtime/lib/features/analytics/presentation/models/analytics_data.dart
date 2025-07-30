import 'package:equatable/equatable.dart';

class AnalyticsData extends Equatable {
  final int totalTasks;
  final int completedTasks;
  final int todayCompletedTasks;
  final int todayFocusMinutes;
  final int currentEnergyLevel;
  final double averageCompletionRate;
  final Map<String, double> taskTypeDistribution;
  final List<FlowAchievement> flowAchievements;
  final List<AIInsight> aiInsights;
  final DateTime lastUpdated;

  const AnalyticsData({
    required this.totalTasks,
    required this.completedTasks,
    required this.todayCompletedTasks,
    required this.todayFocusMinutes,
    required this.currentEnergyLevel,
    required this.averageCompletionRate,
    required this.taskTypeDistribution,
    required this.flowAchievements,
    required this.aiInsights,
    required this.lastUpdated,
  });

  factory AnalyticsData.empty() {
    return AnalyticsData(
      totalTasks: 0,
      completedTasks: 0,
      todayCompletedTasks: 0,
      todayFocusMinutes: 0,
      currentEnergyLevel: 70,
      averageCompletionRate: 0.0,
      taskTypeDistribution: {},
      flowAchievements: [],
      aiInsights: [],
      lastUpdated: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        totalTasks,
        completedTasks,
        todayCompletedTasks,
        todayFocusMinutes,
        currentEnergyLevel,
        averageCompletionRate,
        taskTypeDistribution,
        flowAchievements,
        aiInsights,
        lastUpdated,
      ];
}

class FlowAchievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress;
  final int level;

  const FlowAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.isUnlocked,
    this.unlockedAt,
    required this.progress,
    required this.level,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        iconName,
        isUnlocked,
        unlockedAt,
        progress,
        level,
      ];
}

class AIInsight extends Equatable {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final String actionableAdvice;
  final double confidenceScore;
  final DateTime generatedAt;

  const AIInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.actionableAdvice,
    required this.confidenceScore,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        actionableAdvice,
        confidenceScore,
        generatedAt,
      ];
}

enum InsightType {
  energyPattern,
  productivity,
  scheduling,
  habits,
  recommendation,
}