package services

import (
	"context"
	"fmt"
	"time"

	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
)

type TaskService interface {
	CreateTask(ctx context.Context, userID string, req models.CreateTaskRequest) (*models.Task, error)
	GetTask(ctx context.Context, taskID, userID string) (*models.Task, error)
	GetUserTasks(ctx context.Context, userID string, includeCompleted bool) ([]*models.Task, error)
	GetTasksForDate(ctx context.Context, userID string, date time.Time) ([]*models.Task, error)
	UpdateTask(ctx context.Context, taskID, userID string, req models.UpdateTaskRequest) (*models.Task, error)
	DeleteTask(ctx context.Context, taskID, userID string) error
	CompleteTask(ctx context.Context, taskID, userID string) error
	RescheduleTask(ctx context.Context, taskID, userID string, newTime time.Time) error
	GetUpcomingTasks(ctx context.Context, userID string, limit int) ([]*models.Task, error)
}

type taskService struct {
	taskRepo repository.TaskRepository
	log      logger.Logger
}

func NewTaskService(taskRepo repository.TaskRepository, log logger.Logger) TaskService {
	return &taskService{
		taskRepo: taskRepo,
		log:      log,
	}
}

func (s *taskService) CreateTask(ctx context.Context, userID string, req models.CreateTaskRequest) (*models.Task, error) {
	log := s.log.WithContext(ctx).WithField("operation", "create_task")

	task := &models.Task{
		UserID:         userID,
		Title:          req.Title,
		Description:    req.Description,
		Duration:       req.Duration,
		ScheduledAt:    req.ScheduledAt,
		TaskType:       req.TaskType,
		EnergyRequired: req.EnergyRequired,
		Priority:       req.Priority,
		IsFlexible:     req.IsFlexible,
	}

	createdTask, err := s.taskRepo.Create(ctx, task)
	if err != nil {
		log.WithError(err).Error("Failed to create task")
		return nil, fmt.Errorf("failed to create task: %w", err)
	}

	log.WithField("task_id", createdTask.ID).Info("Task created successfully")
	return createdTask, nil
}

func (s *taskService) GetTask(ctx context.Context, taskID, userID string) (*models.Task, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_task",
		"task_id":   taskID,
		"user_id":   userID,
	})

	task, err := s.taskRepo.GetByID(ctx, taskID, userID)
	if err != nil {
		log.WithError(err).Debug("Failed to get task")
		return nil, err
	}

	return task, nil
}

func (s *taskService) GetUserTasks(ctx context.Context, userID string, includeCompleted bool) ([]*models.Task, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":         "get_user_tasks",
		"user_id":           userID,
		"include_completed": includeCompleted,
	})

	tasks, err := s.taskRepo.GetByUser(ctx, userID, includeCompleted)
	if err != nil {
		log.WithError(err).Error("Failed to get user tasks")
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}

	log.WithField("count", len(tasks)).Debug("Retrieved user tasks")
	return tasks, nil
}

func (s *taskService) GetTasksForDate(ctx context.Context, userID string, date time.Time) ([]*models.Task, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_tasks_for_date",
		"user_id":   userID,
		"date":      date.Format("2006-01-02"),
	})

	// Get start and end of day
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	tasks, err := s.taskRepo.GetByDateRange(ctx, userID, startOfDay, endOfDay)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks for date")
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}

	log.WithField("count", len(tasks)).Debug("Retrieved tasks for date")
	return tasks, nil
}

func (s *taskService) UpdateTask(ctx context.Context, taskID, userID string, req models.UpdateTaskRequest) (*models.Task, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "update_task",
		"task_id":   taskID,
		"user_id":   userID,
	})

	// Get existing task
	task, err := s.taskRepo.GetByID(ctx, taskID, userID)
	if err != nil {
		log.WithError(err).Debug("Task not found")
		return nil, err
	}

	// Update fields if provided
	if req.Title != nil {
		task.Title = *req.Title
	}
	if req.Description != nil {
		task.Description = req.Description
	}
	if req.Duration != nil {
		task.Duration = *req.Duration
	}
	if req.ScheduledAt != nil {
		task.ScheduledAt = req.ScheduledAt
	}
	if req.TaskType != nil {
		task.TaskType = *req.TaskType
	}
	if req.EnergyRequired != nil {
		task.EnergyRequired = *req.EnergyRequired
	}
	if req.Priority != nil {
		task.Priority = *req.Priority
	}
	if req.IsFlexible != nil {
		task.IsFlexible = *req.IsFlexible
	}

	if err := s.taskRepo.Update(ctx, task); err != nil {
		log.WithError(err).Error("Failed to update task")
		return nil, fmt.Errorf("failed to update task: %w", err)
	}

	log.Info("Task updated successfully")
	return task, nil
}

func (s *taskService) DeleteTask(ctx context.Context, taskID, userID string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "delete_task",
		"task_id":   taskID,
		"user_id":   userID,
	})

	if err := s.taskRepo.Delete(ctx, taskID, userID); err != nil {
		log.WithError(err).Error("Failed to delete task")
		return err
	}

	log.Info("Task deleted successfully")
	return nil
}

func (s *taskService) CompleteTask(ctx context.Context, taskID, userID string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "complete_task",
		"task_id":   taskID,
		"user_id":   userID,
	})

	if err := s.taskRepo.MarkComplete(ctx, taskID, userID); err != nil {
		log.WithError(err).Error("Failed to complete task")
		return err
	}

	log.Info("Task completed successfully")
	return nil
}

func (s *taskService) RescheduleTask(ctx context.Context, taskID, userID string, newTime time.Time) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "reschedule_task",
		"task_id":   taskID,
		"user_id":   userID,
		"new_time":  newTime,
	})

	// Get existing task
	task, err := s.taskRepo.GetByID(ctx, taskID, userID)
	if err != nil {
		log.WithError(err).Debug("Task not found")
		return err
	}

	// Update scheduled time
	task.ScheduledAt = &newTime

	if err := s.taskRepo.Update(ctx, task); err != nil {
		log.WithError(err).Error("Failed to reschedule task")
		return fmt.Errorf("failed to reschedule task: %w", err)
	}

	log.Info("Task rescheduled successfully")
	return nil
}

func (s *taskService) GetUpcomingTasks(ctx context.Context, userID string, limit int) ([]*models.Task, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_upcoming_tasks",
		"user_id":   userID,
		"limit":     limit,
	})

	tasks, err := s.taskRepo.GetUpcoming(ctx, userID, limit)
	if err != nil {
		log.WithError(err).Error("Failed to get upcoming tasks")
		return nil, fmt.Errorf("failed to get upcoming tasks: %w", err)
	}

	log.WithField("count", len(tasks)).Debug("Retrieved upcoming tasks")
	return tasks, nil
}
