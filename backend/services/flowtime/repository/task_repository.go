package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
)

type TaskRepository interface {
	Create(ctx context.Context, task *models.Task) (*models.Task, error)
	GetByID(ctx context.Context, taskID, userID string) (*models.Task, error)
	GetByUser(ctx context.Context, userID string, includeCompleted bool) ([]*models.Task, error)
	GetByDateRange(ctx context.Context, userID string, start, end time.Time) ([]*models.Task, error)
	Update(ctx context.Context, task *models.Task) error
	Delete(ctx context.Context, taskID, userID string) error
	MarkComplete(ctx context.Context, taskID, userID string) error
	GetUpcoming(ctx context.Context, userID string, limit int) ([]*models.Task, error)
}

type taskRepository struct {
	db  *sql.DB
	log logger.Logger
}

func NewTaskRepository(db *sql.DB, log logger.Logger) TaskRepository {
	return &taskRepository{
		db:  db,
		log: log,
	}
}

func (r *taskRepository) Create(ctx context.Context, task *models.Task) (*models.Task, error) {
	log := r.log.WithContext(ctx).WithField("operation", "create_task")

	task.ID = uuid.New().String()
	task.CreatedAt = time.Now()
	task.UpdatedAt = time.Now()

	query := `
		INSERT INTO tasks (
			id, user_id, title, description, duration, scheduled_at,
			task_type, energy_required, priority, is_flexible,
			created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(
		ctx, query,
		task.ID, task.UserID, task.Title, task.Description,
		task.Duration, task.ScheduledAt, task.TaskType,
		task.EnergyRequired, task.Priority, task.IsFlexible,
		task.CreatedAt, task.UpdatedAt,
	).Scan(&task.ID, &task.CreatedAt, &task.UpdatedAt)

	if err != nil {
		log.WithError(err).Error("Failed to create task")
		return nil, fmt.Errorf("failed to create task: %w", err)
	}

	log.WithField("task_id", task.ID).Info("Task created")
	return task, nil
}

func (r *taskRepository) GetByID(ctx context.Context, taskID, userID string) (*models.Task, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_task_by_id",
		"task_id":   taskID,
		"user_id":   userID,
	})

	var task models.Task
	query := `
		SELECT 
			id, user_id, title, description, duration, scheduled_at,
			completed_at, task_type, energy_required, priority, is_flexible,
			created_at, updated_at
		FROM tasks
		WHERE id = $1 AND user_id = $2
	`

	err := r.db.QueryRowContext(ctx, query, taskID, userID).Scan(
		&task.ID, &task.UserID, &task.Title, &task.Description,
		&task.Duration, &task.ScheduledAt, &task.CompletedAt,
		&task.TaskType, &task.EnergyRequired, &task.Priority,
		&task.IsFlexible, &task.CreatedAt, &task.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		log.Debug("Task not found")
		return nil, fmt.Errorf("task not found")
	}
	if err != nil {
		log.WithError(err).Error("Failed to get task")
		return nil, fmt.Errorf("failed to get task: %w", err)
	}

	return &task, nil
}

func (r *taskRepository) GetByUser(ctx context.Context, userID string, includeCompleted bool) ([]*models.Task, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":         "get_tasks_by_user",
		"user_id":           userID,
		"include_completed": includeCompleted,
	})

	query := `
		SELECT 
			id, user_id, title, description, duration, scheduled_at,
			completed_at, task_type, energy_required, priority, is_flexible,
			created_at, updated_at
		FROM tasks
		WHERE user_id = $1
	`

	if !includeCompleted {
		query += " AND completed_at IS NULL"
	}

	query += " ORDER BY COALESCE(scheduled_at, created_at) ASC"

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks")
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}
	defer rows.Close()

	var tasks []*models.Task
	for rows.Next() {
		var task models.Task
		if err := rows.Scan(
			&task.ID, &task.UserID, &task.Title, &task.Description,
			&task.Duration, &task.ScheduledAt, &task.CompletedAt,
			&task.TaskType, &task.EnergyRequired, &task.Priority,
			&task.IsFlexible, &task.CreatedAt, &task.UpdatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan task")
			continue
		}
		tasks = append(tasks, &task)
	}

	log.WithField("count", len(tasks)).Debug("Tasks retrieved")
	return tasks, nil
}

func (r *taskRepository) GetByDateRange(ctx context.Context, userID string, start, end time.Time) ([]*models.Task, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_tasks_by_date_range",
		"user_id":   userID,
		"start":     start,
		"end":       end,
	})

	query := `
		SELECT 
			id, user_id, title, description, duration, scheduled_at,
			completed_at, task_type, energy_required, priority, is_flexible,
			created_at, updated_at
		FROM tasks
		WHERE user_id = $1 
		AND scheduled_at >= $2 
		AND scheduled_at < $3
		ORDER BY scheduled_at ASC
	`

	rows, err := r.db.QueryContext(ctx, query, userID, start, end)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks by date range")
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}
	defer rows.Close()

	var tasks []*models.Task
	for rows.Next() {
		var task models.Task
		if err := rows.Scan(
			&task.ID, &task.UserID, &task.Title, &task.Description,
			&task.Duration, &task.ScheduledAt, &task.CompletedAt,
			&task.TaskType, &task.EnergyRequired, &task.Priority,
			&task.IsFlexible, &task.CreatedAt, &task.UpdatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan task")
			continue
		}
		tasks = append(tasks, &task)
	}

	return tasks, nil
}

func (r *taskRepository) Update(ctx context.Context, task *models.Task) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "update_task",
		"task_id":   task.ID,
		"user_id":   task.UserID,
	})

	task.UpdatedAt = time.Now()

	query := `
		UPDATE tasks SET
			title = $1, description = $2, duration = $3,
			scheduled_at = $4, task_type = $5, energy_required = $6,
			priority = $7, is_flexible = $8, updated_at = $9
		WHERE id = $10 AND user_id = $11
	`

	result, err := r.db.ExecContext(
		ctx, query,
		task.Title, task.Description, task.Duration,
		task.ScheduledAt, task.TaskType, task.EnergyRequired,
		task.Priority, task.IsFlexible, task.UpdatedAt,
		task.ID, task.UserID,
	)

	if err != nil {
		log.WithError(err).Error("Failed to update task")
		return fmt.Errorf("failed to update task: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("task not found")
	}

	log.Info("Task updated")
	return nil
}

func (r *taskRepository) Delete(ctx context.Context, taskID, userID string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "delete_task",
		"task_id":   taskID,
		"user_id":   userID,
	})

	query := `DELETE FROM tasks WHERE id = $1 AND user_id = $2`

	result, err := r.db.ExecContext(ctx, query, taskID, userID)
	if err != nil {
		log.WithError(err).Error("Failed to delete task")
		return fmt.Errorf("failed to delete task: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("task not found")
	}

	log.Info("Task deleted")
	return nil
}

func (r *taskRepository) MarkComplete(ctx context.Context, taskID, userID string) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "mark_task_complete",
		"task_id":   taskID,
		"user_id":   userID,
	})

	query := `
		UPDATE tasks 
		SET completed_at = $1, updated_at = $2
		WHERE id = $3 AND user_id = $4 AND completed_at IS NULL
	`

	now := time.Now()
	result, err := r.db.ExecContext(ctx, query, now, now, taskID, userID)
	if err != nil {
		log.WithError(err).Error("Failed to mark task complete")
		return fmt.Errorf("failed to mark task complete: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("task not found or already completed")
	}

	log.Info("Task marked as complete")
	return nil
}

func (r *taskRepository) GetUpcoming(ctx context.Context, userID string, limit int) ([]*models.Task, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_upcoming_tasks",
		"user_id":   userID,
		"limit":     limit,
	})

	query := `
		SELECT 
			id, user_id, title, description, duration, scheduled_at,
			completed_at, task_type, energy_required, priority, is_flexible,
			created_at, updated_at
		FROM tasks
		WHERE user_id = $1 
		AND completed_at IS NULL
		AND scheduled_at > $2
		ORDER BY scheduled_at ASC
		LIMIT $3
	`

	rows, err := r.db.QueryContext(ctx, query, userID, time.Now(), limit)
	if err != nil {
		log.WithError(err).Error("Failed to get upcoming tasks")
		return nil, fmt.Errorf("failed to get upcoming tasks: %w", err)
	}
	defer rows.Close()

	var tasks []*models.Task
	for rows.Next() {
		var task models.Task
		if err := rows.Scan(
			&task.ID, &task.UserID, &task.Title, &task.Description,
			&task.Duration, &task.ScheduledAt, &task.CompletedAt,
			&task.TaskType, &task.EnergyRequired, &task.Priority,
			&task.IsFlexible, &task.CreatedAt, &task.UpdatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan task")
			continue
		}
		tasks = append(tasks, &task)
	}

	return tasks, nil
}
