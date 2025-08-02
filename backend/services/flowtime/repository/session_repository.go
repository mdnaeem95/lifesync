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

type SessionRepository interface {
	Create(ctx context.Context, session *models.FocusSession) (*models.FocusSession, error)
	GetByID(ctx context.Context, sessionID, userID string) (*models.FocusSession, error)
	GetActive(ctx context.Context, userID string) (*models.FocusSession, error)
	Update(ctx context.Context, session *models.FocusSession) error
	GetHistory(ctx context.Context, userID string, start, end time.Time) ([]*models.FocusSession, error)
	GetByTaskID(ctx context.Context, taskID string) ([]*models.FocusSession, error)
}

type sessionRepository struct {
	db  *sql.DB
	log logger.Logger
}

func NewSessionRepository(db *sql.DB, log logger.Logger) SessionRepository {
	return &sessionRepository{
		db:  db,
		log: log,
	}
}

func (r *sessionRepository) Create(ctx context.Context, session *models.FocusSession) (*models.FocusSession, error) {
	log := r.log.WithContext(ctx).WithField("operation", "create_session")

	session.ID = uuid.New().String()
	session.CreatedAt = time.Now()
	session.UpdatedAt = time.Now()

	query := `
		INSERT INTO focus_sessions (
			id, user_id, task_id, started_at, session_type, 
			status, duration, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(
		ctx, query,
		session.ID, session.UserID, session.TaskID, session.StartedAt,
		session.SessionType, session.Status, session.Duration,
		session.CreatedAt, session.UpdatedAt,
	).Scan(&session.ID, &session.CreatedAt, &session.UpdatedAt)

	if err != nil {
		log.WithError(err).Error("Failed to create session")
		return nil, fmt.Errorf("failed to create session: %w", err)
	}

	log.WithField("session_id", session.ID).Info("Session created")
	return session, nil
}

func (r *sessionRepository) GetByID(ctx context.Context, sessionID, userID string) (*models.FocusSession, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":  "get_session_by_id",
		"session_id": sessionID,
		"user_id":    userID,
	})

	var session models.FocusSession
	query := `
		SELECT 
			id, user_id, task_id, started_at, ended_at, paused_at,
			duration, session_type, status, created_at, updated_at
		FROM focus_sessions
		WHERE id = $1 AND user_id = $2
	`

	err := r.db.QueryRowContext(ctx, query, sessionID, userID).Scan(
		&session.ID, &session.UserID, &session.TaskID, &session.StartedAt,
		&session.EndedAt, &session.PausedAt, &session.Duration,
		&session.SessionType, &session.Status, &session.CreatedAt, &session.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		log.Debug("Session not found")
		return nil, fmt.Errorf("session not found")
	}
	if err != nil {
		log.WithError(err).Error("Failed to get session")
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	return &session, nil
}

func (r *sessionRepository) GetActive(ctx context.Context, userID string) (*models.FocusSession, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_active_session",
		"user_id":   userID,
	})

	var session models.FocusSession
	query := `
		SELECT 
			id, user_id, task_id, started_at, ended_at, paused_at,
			duration, session_type, status, created_at, updated_at
		FROM focus_sessions
		WHERE user_id = $1 AND status IN ('active', 'paused')
		ORDER BY started_at DESC
		LIMIT 1
	`

	err := r.db.QueryRowContext(ctx, query, userID).Scan(
		&session.ID, &session.UserID, &session.TaskID, &session.StartedAt,
		&session.EndedAt, &session.PausedAt, &session.Duration,
		&session.SessionType, &session.Status, &session.CreatedAt, &session.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		log.WithError(err).Error("Failed to get active session")
		return nil, fmt.Errorf("failed to get active session: %w", err)
	}

	return &session, nil
}

func (r *sessionRepository) Update(ctx context.Context, session *models.FocusSession) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":  "update_session",
		"session_id": session.ID,
		"user_id":    session.UserID,
	})

	session.UpdatedAt = time.Now()

	query := `
		UPDATE focus_sessions SET
			ended_at = $1, paused_at = $2, duration = $3,
			status = $4, updated_at = $5
		WHERE id = $6 AND user_id = $7
	`

	result, err := r.db.ExecContext(
		ctx, query,
		session.EndedAt, session.PausedAt, session.Duration,
		session.Status, session.UpdatedAt,
		session.ID, session.UserID,
	)

	if err != nil {
		log.WithError(err).Error("Failed to update session")
		return fmt.Errorf("failed to update session: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("session not found")
	}

	log.Info("Session updated")
	return nil
}

func (r *sessionRepository) GetHistory(ctx context.Context, userID string, start, end time.Time) ([]*models.FocusSession, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_session_history",
		"user_id":   userID,
		"start":     start,
		"end":       end,
	})

	query := `
		SELECT 
			id, user_id, task_id, started_at, ended_at, paused_at,
			duration, session_type, status, created_at, updated_at
		FROM focus_sessions
		WHERE user_id = $1 AND started_at >= $2 AND started_at < $3
		ORDER BY started_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID, start, end)
	if err != nil {
		log.WithError(err).Error("Failed to get session history")
		return nil, fmt.Errorf("failed to get session history: %w", err)
	}
	defer rows.Close()

	var sessions []*models.FocusSession
	for rows.Next() {
		var session models.FocusSession
		if err := rows.Scan(
			&session.ID, &session.UserID, &session.TaskID, &session.StartedAt,
			&session.EndedAt, &session.PausedAt, &session.Duration,
			&session.SessionType, &session.Status, &session.CreatedAt, &session.UpdatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan session")
			continue
		}
		sessions = append(sessions, &session)
	}

	return sessions, nil
}

func (r *sessionRepository) GetByTaskID(ctx context.Context, taskID string) ([]*models.FocusSession, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_sessions_by_task",
		"task_id":   taskID,
	})

	query := `
		SELECT 
			id, user_id, task_id, started_at, ended_at, paused_at,
			duration, session_type, status, created_at, updated_at
		FROM focus_sessions
		WHERE task_id = $1
		ORDER BY started_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, taskID)
	if err != nil {
		log.WithError(err).Error("Failed to get sessions by task")
		return nil, fmt.Errorf("failed to get sessions by task: %w", err)
	}
	defer rows.Close()

	var sessions []*models.FocusSession
	for rows.Next() {
		var session models.FocusSession
		if err := rows.Scan(
			&session.ID, &session.UserID, &session.TaskID, &session.StartedAt,
			&session.EndedAt, &session.PausedAt, &session.Duration,
			&session.SessionType, &session.Status, &session.CreatedAt, &session.UpdatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan session")
			continue
		}
		sessions = append(sessions, &session)
	}

	return sessions, nil
}
