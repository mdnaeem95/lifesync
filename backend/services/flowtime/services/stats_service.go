package services

import (
	"context"
	"fmt"
	"time"

	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
)

type StatsService interface {
	GetDailyStats(ctx context.Context, userID string, date time.Time) (*models.DailyStats, error)
	GetWeeklyStats(ctx context.Context, userID string) (map[string]interface{}, error)
	GetInsights(ctx context.Context, userID string) (map[string]interface{}, error)
}

type statsService struct {
	taskRepo    repository.TaskRepository
	sessionRepo repository.SessionRepository
	energyRepo  repository.EnergyRepository
	log         logger.Logger
}

func NewStatsService(
	taskRepo repository.TaskRepository,
	sessionRepo repository.SessionRepository,
	energyRepo repository.EnergyRepository,
	log logger.Logger,
) StatsService {
	return &statsService{
		taskRepo:    taskRepo,
		sessionRepo: sessionRepo,
		energyRepo:  energyRepo,
		log:         log,
	}
}

func (s *statsService) GetDailyStats(ctx context.Context, userID string, date time.Time) (*models.DailyStats, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_daily_stats",
		"user_id":   userID,
		"date":      date.Format("2006-01-02"),
	})

	// Get start and end of day
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	// Get tasks for the day
	tasks, err := s.taskRepo.GetByDateRange(ctx, userID, startOfDay, endOfDay)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks")
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}

	// Calculate task stats
	tasksCompleted := 0
	totalScheduled := 0
	for _, task := range tasks {
		if task.CompletedAt != nil && task.CompletedAt.After(startOfDay) && task.CompletedAt.Before(endOfDay) {
			tasksCompleted++
		}
		if task.ScheduledAt != nil {
			totalScheduled++
		}
	}

	// Get sessions for the day
	sessions, err := s.sessionRepo.GetHistory(ctx, userID, startOfDay, endOfDay)
	if err != nil {
		log.WithError(err).Error("Failed to get sessions")
		return nil, fmt.Errorf("failed to get sessions: %w", err)
	}

	// Calculate focus time
	totalFocusTime := 0
	for _, session := range sessions {
		if session.Status == "completed" {
			totalFocusTime += session.Duration / 60 // Convert to minutes
		}
	}

	// Get energy levels for the day
	energyLevels, err := s.energyRepo.GetHistory(ctx, userID, startOfDay, endOfDay)
	if err != nil {
		log.WithError(err).Error("Failed to get energy levels")
		return nil, fmt.Errorf("failed to get energy levels: %w", err)
	}

	// Calculate average energy
	var averageEnergy float64
	if len(energyLevels) > 0 {
		totalEnergy := 0
		for _, level := range energyLevels {
			totalEnergy += level.Level
		}
		averageEnergy = float64(totalEnergy) / float64(len(energyLevels))
	}

	// Find most productive hour
	hourProductivity := make(map[int]int)
	for _, session := range sessions {
		if session.Status == "completed" {
			hour := session.StartedAt.Hour()
			hourProductivity[hour] += session.Duration
		}
	}

	mostProductiveHour := 0
	maxProductivity := 0
	for hour, productivity := range hourProductivity {
		if productivity > maxProductivity {
			maxProductivity = productivity
			mostProductiveHour = hour
		}
	}

	// Calculate completion rate
	var taskCompletionRate float64
	if totalScheduled > 0 {
		taskCompletionRate = float64(tasksCompleted) / float64(totalScheduled)
	}

	// Calculate productivity score (simple formula)
	productivityScore := (taskCompletionRate * 0.4) + (float64(totalFocusTime) / 480 * 0.4) + (averageEnergy / 100 * 0.2)

	stats := &models.DailyStats{
		Date:               date,
		TasksCompleted:     tasksCompleted,
		TotalFocusTime:     totalFocusTime,
		AverageEnergyLevel: averageEnergy,
		ProductivityScore:  productivityScore * 100, // Convert to percentage
		MostProductiveHour: mostProductiveHour,
		TaskCompletionRate: taskCompletionRate,
	}

	log.WithField("stats", stats).Debug("Daily stats calculated")
	return stats, nil
}

func (s *statsService) GetWeeklyStats(ctx context.Context, userID string) (map[string]interface{}, error) {
	log := s.log.WithContext(ctx).WithField("operation", "get_weekly_stats")

	// Get stats for the last 7 days
	weekStats := make([]models.DailyStats, 7)
	now := time.Now()

	for i := 0; i < 7; i++ {
		date := now.AddDate(0, 0, -i)
		stats, err := s.GetDailyStats(ctx, userID, date)
		if err != nil {
			log.WithError(err).Warn("Failed to get daily stats")
			// Continue with empty stats for that day
			stats = &models.DailyStats{Date: date}
		}
		weekStats[6-i] = *stats // Reverse order to have oldest first
	}

	// Calculate weekly aggregates
	totalTasksCompleted := 0
	totalFocusTime := 0
	totalEnergySum := 0.0
	energyCount := 0

	for _, day := range weekStats {
		totalTasksCompleted += day.TasksCompleted
		totalFocusTime += day.TotalFocusTime
		if day.AverageEnergyLevel > 0 {
			totalEnergySum += day.AverageEnergyLevel
			energyCount++
		}
	}

	var weeklyAverageEnergy float64
	if energyCount > 0 {
		weeklyAverageEnergy = totalEnergySum / float64(energyCount)
	}

	// Find best day
	bestDay := weekStats[0]
	for _, day := range weekStats {
		if day.ProductivityScore > bestDay.ProductivityScore {
			bestDay = day
		}
	}

	return map[string]interface{}{
		"daily_stats":           weekStats,
		"total_tasks_completed": totalTasksCompleted,
		"total_focus_time":      totalFocusTime,
		"average_energy":        weeklyAverageEnergy,
		"best_day":              bestDay.Date.Format("Monday"),
		"trend":                 s.calculateTrend(weekStats),
	}, nil
}

func (s *statsService) GetInsights(ctx context.Context, userID string) (map[string]interface{}, error) {
	log := s.log.WithContext(ctx).WithField("operation", "get_insights")

	// Get energy patterns
	patterns, err := s.energyRepo.GetAllPatterns(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get energy patterns")
		return nil, fmt.Errorf("failed to get energy patterns: %w", err)
	}

	// Find peak energy times
	peakHours := s.findPeakEnergyHours(patterns)

	// Get recent sessions to analyze focus patterns
	sessions, err := s.sessionRepo.GetHistory(ctx, userID, time.Now().AddDate(0, 0, -30), time.Now())
	if err != nil {
		log.WithError(err).Error("Failed to get session history")
		return nil, fmt.Errorf("failed to get session history: %w", err)
	}

	// Analyze session patterns
	avgSessionDuration := s.calculateAverageSessionDuration(sessions)
	preferredSessionType := s.findPreferredSessionType(sessions)

	// Get task completion patterns
	tasks, err := s.taskRepo.GetByUser(ctx, userID, true)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks")
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}

	taskTypeCompletion := s.analyzeTaskTypeCompletion(tasks)

	insights := map[string]interface{}{
		"peak_energy_hours":      peakHours,
		"avg_session_duration":   avgSessionDuration,
		"preferred_session_type": preferredSessionType,
		"task_type_completion":   taskTypeCompletion,
		"recommendations":        s.generateRecommendations(patterns, sessions, tasks),
	}

	return insights, nil
}

// Helper methods

func (s *statsService) calculateTrend(weekStats []models.DailyStats) string {
	if len(weekStats) < 2 {
		return "stable"
	}

	// Compare first half to second half
	firstHalfAvg := 0.0
	secondHalfAvg := 0.0

	halfPoint := len(weekStats) / 2
	for i := 0; i < halfPoint; i++ {
		firstHalfAvg += weekStats[i].ProductivityScore
	}
	for i := halfPoint; i < len(weekStats); i++ {
		secondHalfAvg += weekStats[i].ProductivityScore
	}

	firstHalfAvg /= float64(halfPoint)
	secondHalfAvg /= float64(len(weekStats) - halfPoint)

	if secondHalfAvg > firstHalfAvg*1.1 {
		return "improving"
	} else if secondHalfAvg < firstHalfAvg*0.9 {
		return "declining"
	}
	return "stable"
}

func (s *statsService) findPeakEnergyHours(patterns []*models.EnergyPattern) []int {
	// Group by hour and average across days
	hourlyAverage := make(map[int]float64)
	hourlyCount := make(map[int]int)

	for _, pattern := range patterns {
		hourlyAverage[pattern.HourOfDay] += pattern.AverageEnergy
		hourlyCount[pattern.HourOfDay]++
	}

	// Calculate averages
	for hour, total := range hourlyAverage {
		hourlyAverage[hour] = total / float64(hourlyCount[hour])
	}

	// Find top 3 hours
	var peakHours []int
	threshold := 70.0 // Energy level above 70 is considered peak

	for hour, avg := range hourlyAverage {
		if avg >= threshold {
			peakHours = append(peakHours, hour)
		}
	}

	return peakHours
}

func (s *statsService) calculateAverageSessionDuration(sessions []*models.FocusSession) int {
	if len(sessions) == 0 {
		return 0
	}

	totalDuration := 0
	completedCount := 0

	for _, session := range sessions {
		if session.Status == "completed" {
			totalDuration += session.Duration
			completedCount++
		}
	}

	if completedCount == 0 {
		return 0
	}

	return (totalDuration / completedCount) / 60 // Convert to minutes
}

func (s *statsService) findPreferredSessionType(sessions []*models.FocusSession) string {
	typeCount := make(map[string]int)

	for _, session := range sessions {
		if session.Status == "completed" {
			typeCount[session.SessionType]++
		}
	}

	maxCount := 0
	preferredType := "pomodoro"

	for sessionType, count := range typeCount {
		if count > maxCount {
			maxCount = count
			preferredType = sessionType
		}
	}

	return preferredType
}

func (s *statsService) analyzeTaskTypeCompletion(tasks []*models.Task) map[string]float64 {
	typeTotal := make(map[string]int)
	typeCompleted := make(map[string]int)

	for _, task := range tasks {
		typeTotal[task.TaskType]++
		if task.CompletedAt != nil {
			typeCompleted[task.TaskType]++
		}
	}

	completion := make(map[string]float64)
	for taskType, total := range typeTotal {
		if total > 0 {
			completion[taskType] = float64(typeCompleted[taskType]) / float64(total)
		}
	}

	return completion
}

func (s *statsService) generateRecommendations(patterns []*models.EnergyPattern, sessions []*models.FocusSession, tasks []*models.Task) []string {
	recommendations := []string{}

	// Energy-based recommendations
	peakHours := s.findPeakEnergyHours(patterns)
	if len(peakHours) > 0 {
		recommendations = append(recommendations,
			fmt.Sprintf("Schedule high-priority tasks during your peak energy hours: %v", peakHours))
	}

	// Session-based recommendations
	avgDuration := s.calculateAverageSessionDuration(sessions)
	if avgDuration < 25 {
		recommendations = append(recommendations,
			"Your focus sessions are quite short. Consider using the Pomodoro technique to build longer focus periods")
	} else if avgDuration > 90 {
		recommendations = append(recommendations,
			"Your focus sessions are very long. Remember to take regular breaks to maintain energy")
	}

	// Task completion recommendations
	incompleteTasks := 0
	for _, task := range tasks {
		if task.CompletedAt == nil && task.ScheduledAt != nil && task.ScheduledAt.Before(time.Now()) {
			incompleteTasks++
		}
	}

	if incompleteTasks > 5 {
		recommendations = append(recommendations,
			"You have several overdue tasks. Consider using the auto-reschedule feature to optimize your schedule")
	}

	return recommendations
}
