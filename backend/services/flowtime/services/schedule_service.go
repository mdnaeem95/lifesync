package services

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
)

type ScheduleService interface {
	OptimizeSchedule(ctx context.Context, userID string, date time.Time, respectCurrent bool) error
	GetSuggestedTimeSlots(ctx context.Context, userID string, taskID string) ([]models.TimeSlotSuggestion, error)
	AutoReschedule(ctx context.Context, userID string) error
}

type scheduleService struct {
	taskRepo      repository.TaskRepository
	energyService EnergyService
	prefRepo      repository.PreferencesRepository
	log           logger.Logger
}

func NewScheduleService(
	taskRepo repository.TaskRepository,
	energyService EnergyService,
	prefRepo repository.PreferencesRepository,
	log logger.Logger,
) ScheduleService {
	return &scheduleService{
		taskRepo:      taskRepo,
		energyService: energyService,
		prefRepo:      prefRepo,
		log:           log,
	}
}

func (s *scheduleService) OptimizeSchedule(ctx context.Context, userID string, date time.Time, respectCurrent bool) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":       "optimize_schedule",
		"user_id":         userID,
		"date":            date.Format("2006-01-02"),
		"respect_current": respectCurrent,
	})

	// Get user preferences
	prefs, err := s.prefRepo.GetByUserID(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get user preferences")
		return fmt.Errorf("failed to get preferences: %w", err)
	}

	// Get all tasks for the day
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	tasks, err := s.taskRepo.GetByDateRange(ctx, userID, startOfDay, endOfDay)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks")
		return fmt.Errorf("failed to get tasks: %w", err)
	}

	// Separate flexible and fixed tasks
	var flexibleTasks []*models.Task
	var fixedTasks []*models.Task

	for _, task := range tasks {
		if task.IsFlexible && (task.ScheduledAt == nil || !respectCurrent) {
			flexibleTasks = append(flexibleTasks, task)
		} else {
			fixedTasks = append(fixedTasks, task)
		}
	}

	// Sort flexible tasks by priority and energy requirement
	sort.Slice(flexibleTasks, func(i, j int) bool {
		// Higher priority first
		if flexibleTasks[i].Priority != flexibleTasks[j].Priority {
			return flexibleTasks[i].Priority > flexibleTasks[j].Priority
		}
		// Higher energy requirement first (schedule when fresh)
		return flexibleTasks[i].EnergyRequired > flexibleTasks[j].EnergyRequired
	})

	// Get work hours from preferences
	workStart, _ := time.Parse("15:04", prefs.WorkHoursStart)
	workEnd, _ := time.Parse("15:04", prefs.WorkHoursEnd)

	// Create time slots for the day
	slots := s.generateTimeSlots(date, workStart, workEnd, prefs.PreferredTaskTime)

	// Mark slots occupied by fixed tasks
	for _, task := range fixedTasks {
		if task.ScheduledAt != nil {
			s.markSlotsOccupied(slots, *task.ScheduledAt, task.Duration)
		}
	}

	// Schedule flexible tasks in optimal slots
	for _, task := range flexibleTasks {
		slot, err := s.findOptimalSlot(ctx, userID, task, slots)
		if err != nil {
			log.WithError(err).Warn("Failed to find optimal slot for task")
			continue
		}

		// Update task with new schedule
		task.ScheduledAt = &slot.StartTime
		if err := s.taskRepo.Update(ctx, task); err != nil {
			log.WithError(err).Error("Failed to update task schedule")
			continue
		}

		// Mark slots as occupied
		s.markSlotsOccupied(slots, slot.StartTime, task.Duration)

		log.WithFields(map[string]interface{}{
			"task_id":      task.ID,
			"scheduled_at": slot.StartTime,
		}).Debug("Task scheduled")
	}

	log.Info("Schedule optimization completed")
	return nil
}

func (s *scheduleService) GetSuggestedTimeSlots(ctx context.Context, userID string, taskID string) ([]models.TimeSlotSuggestion, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_suggested_time_slots",
		"user_id":   userID,
		"task_id":   taskID,
	})

	// Get the task
	task, err := s.taskRepo.GetByID(ctx, taskID, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get task")
		return nil, fmt.Errorf("failed to get task: %w", err)
	}

	// Get optimal time slots based on task requirements
	slots, err := s.energyService.GetOptimalTimeSlots(ctx, userID, task.Duration, 5)
	if err != nil {
		log.WithError(err).Error("Failed to get optimal time slots")
		return nil, fmt.Errorf("failed to get optimal time slots: %w", err)
	}

	// Filter slots based on task energy requirements
	var suggestions []models.TimeSlotSuggestion
	for _, slot := range slots {
		// Only suggest slots where energy level meets task requirements
		if slot.EnergyLevel >= task.EnergyRequired*20 { // Convert 1-5 to 20-100 scale
			suggestions = append(suggestions, slot)
		}
	}

	return suggestions, nil
}

func (s *scheduleService) AutoReschedule(ctx context.Context, userID string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "auto_reschedule",
		"user_id":   userID,
	})

	// Get all incomplete flexible tasks
	tasks, err := s.taskRepo.GetByUser(ctx, userID, false)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks")
		return fmt.Errorf("failed to get tasks: %w", err)
	}

	// Find overdue flexible tasks
	now := time.Now()
	var overdueTasks []*models.Task

	for _, task := range tasks {
		if task.IsFlexible && task.ScheduledAt != nil && task.ScheduledAt.Before(now) {
			overdueTasks = append(overdueTasks, task)
		}
	}

	// Reschedule overdue tasks
	for _, task := range overdueTasks {
		// Find next available slot
		slots, err := s.GetSuggestedTimeSlots(ctx, userID, task.ID)
		if err != nil || len(slots) == 0 {
			log.WithError(err).Warn("Failed to find slots for overdue task")
			continue
		}

		// Use the first available slot
		task.ScheduledAt = &slots[0].StartTime
		if err := s.taskRepo.Update(ctx, task); err != nil {
			log.WithError(err).Error("Failed to reschedule task")
			continue
		}

		log.WithFields(map[string]interface{}{
			"task_id":      task.ID,
			"new_schedule": slots[0].StartTime,
		}).Info("Task auto-rescheduled")
	}

	return nil
}

// Helper methods

type timeSlot struct {
	StartTime time.Time
	EndTime   time.Time
	Occupied  bool
}

func (s *scheduleService) generateTimeSlots(date time.Time, workStart, workEnd time.Time, slotDuration int) []*timeSlot {
	var slots []*timeSlot

	// Adjust times to the correct date
	start := time.Date(
		date.Year(), date.Month(), date.Day(),
		workStart.Hour(), workStart.Minute(), 0, 0,
		date.Location(),
	)
	end := time.Date(
		date.Year(), date.Month(), date.Day(),
		workEnd.Hour(), workEnd.Minute(), 0, 0,
		date.Location(),
	)

	// Generate slots
	current := start
	for current.Before(end) {
		slot := &timeSlot{
			StartTime: current,
			EndTime:   current.Add(time.Duration(slotDuration) * time.Minute),
			Occupied:  false,
		}
		slots = append(slots, slot)
		current = current.Add(time.Duration(slotDuration) * time.Minute)
	}

	return slots
}

func (s *scheduleService) markSlotsOccupied(slots []*timeSlot, startTime time.Time, duration int) {
	endTime := startTime.Add(time.Duration(duration) * time.Minute)

	for _, slot := range slots {
		// Check if this slot overlaps with the task
		if slot.StartTime.Before(endTime) && slot.EndTime.After(startTime) {
			slot.Occupied = true
		}
	}
}

func (s *scheduleService) findOptimalSlot(ctx context.Context, userID string, task *models.Task, slots []*timeSlot) (*timeSlot, error) {
	var bestSlot *timeSlot
	bestScore := -1.0

	for i, slot := range slots {
		if slot.Occupied {
			continue
		}

		// Check if we have enough consecutive free slots
		slotsNeeded := (task.Duration + int(slot.EndTime.Sub(slot.StartTime).Minutes()) - 1) / int(slot.EndTime.Sub(slot.StartTime).Minutes())
		if !s.hasConsecutiveFreeSlots(slots[i:], slotsNeeded) {
			continue
		}

		// Predict energy level for this slot
		energyLevel, err := s.energyService.PredictEnergyLevel(ctx, userID, slot.StartTime)
		if err != nil {
			continue
		}

		// Calculate score based on energy match and time preferences
		score := s.calculateSlotScore(task, slot, energyLevel)

		if score > bestScore {
			bestScore = score
			bestSlot = slot
		}
	}

	if bestSlot == nil {
		return nil, fmt.Errorf("no suitable time slot found")
	}

	return bestSlot, nil
}

func (s *scheduleService) hasConsecutiveFreeSlots(slots []*timeSlot, needed int) bool {
	if len(slots) < needed {
		return false
	}

	for i := 0; i < needed; i++ {
		if slots[i].Occupied {
			return false
		}
	}

	return true
}

func (s *scheduleService) calculateSlotScore(task *models.Task, slot *timeSlot, energyLevel int) float64 {
	// Energy match score (0-1)
	requiredEnergy := float64(task.EnergyRequired * 20) // Convert to 0-100 scale
	energyScore := 1.0 - (math.Abs(requiredEnergy-float64(energyLevel)) / 100.0)

	// Time preference score (prefer morning for high-energy tasks)
	hour := slot.StartTime.Hour()
	timeScore := 0.5
	if task.EnergyRequired >= 4 && hour >= 9 && hour <= 11 {
		timeScore = 1.0 // Morning bonus for high-energy tasks
	} else if task.EnergyRequired <= 2 && hour >= 13 && hour <= 15 {
		timeScore = 0.8 // Afternoon is fine for low-energy tasks
	}

	// Combined score
	return (energyScore * 0.7) + (timeScore * 0.3)
}
