package services

import (
	"context"
	"fmt"
	"time"

	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
)

type SessionService interface {
	StartSession(ctx context.Context, userID string, req models.StartSessionRequest) (*models.FocusSession, error)
	PauseSession(ctx context.Context, sessionID, userID string) error
	ResumeSession(ctx context.Context, sessionID, userID string) error
	CompleteSession(ctx context.Context, sessionID, userID string) error
	GetActiveSession(ctx context.Context, userID string) (*models.FocusSession, error)
	GetSessionHistory(ctx context.Context, userID string, days int) ([]*models.FocusSession, error)
}

type sessionService struct {
	sessionRepo repository.SessionRepository
	taskRepo    repository.TaskRepository
	log         logger.Logger
}

func NewSessionService(
	sessionRepo repository.SessionRepository,
	taskRepo repository.TaskRepository,
	log logger.Logger,
) SessionService {
	return &sessionService{
		sessionRepo: sessionRepo,
		taskRepo:    taskRepo,
		log:         log,
	}
}

func (s *sessionService) StartSession(ctx context.Context, userID string, req models.StartSessionRequest) (*models.FocusSession, error) {
	log := s.log.WithContext(ctx).WithField("operation", "start_session")

	// Check if there's already an active session
	activeSession, err := s.sessionRepo.GetActive(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to check active session")
		return nil, fmt.Errorf("failed to check active session: %w", err)
	}

	if activeSession != nil {
		return nil, fmt.Errorf("active session already exists")
	}

	// Validate task if provided
	if req.TaskID != nil {
		task, err := s.taskRepo.GetByID(ctx, *req.TaskID, userID)
		if err != nil {
			log.WithError(err).Debug("Task not found")
			return nil, fmt.Errorf("task not found")
		}

		// Check if task is already completed
		if task.CompletedAt != nil {
			return nil, fmt.Errorf("cannot start session for completed task")
		}
	}

	// Create new session
	session := &models.FocusSession{
		UserID:      userID,
		TaskID:      req.TaskID,
		StartedAt:   time.Now(),
		SessionType: req.SessionType,
		Status:      "active",
		Duration:    0,
	}

	createdSession, err := s.sessionRepo.Create(ctx, session)
	if err != nil {
		log.WithError(err).Error("Failed to create session")
		return nil, fmt.Errorf("failed to create session: %w", err)
	}

	log.WithField("session_id", createdSession.ID).Info("Session started")
	return createdSession, nil
}

func (s *sessionService) PauseSession(ctx context.Context, sessionID, userID string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":  "pause_session",
		"session_id": sessionID,
	})

	// Get session
	session, err := s.sessionRepo.GetByID(ctx, sessionID, userID)
	if err != nil {
		log.WithError(err).Debug("Session not found")
		return err
	}

	// Validate session status
	if session.Status != "active" {
		return fmt.Errorf("can only pause active sessions")
	}

	// Calculate duration and pause
	now := time.Now()
	sessionDuration := int(now.Sub(session.StartedAt).Seconds())

	session.PausedAt = &now
	session.Duration += sessionDuration
	session.Status = "paused"

	if err := s.sessionRepo.Update(ctx, session); err != nil {
		log.WithError(err).Error("Failed to pause session")
		return fmt.Errorf("failed to pause session: %w", err)
	}

	log.Info("Session paused")
	return nil
}

func (s *sessionService) ResumeSession(ctx context.Context, sessionID, userID string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":  "resume_session",
		"session_id": sessionID,
	})

	// Get session
	session, err := s.sessionRepo.GetByID(ctx, sessionID, userID)
	if err != nil {
		log.WithError(err).Debug("Session not found")
		return err
	}

	// Validate session status
	if session.Status != "paused" {
		return fmt.Errorf("can only resume paused sessions")
	}

	// Resume session
	session.StartedAt = time.Now() // Reset start time for duration calculation
	session.PausedAt = nil
	session.Status = "active"

	if err := s.sessionRepo.Update(ctx, session); err != nil {
		log.WithError(err).Error("Failed to resume session")
		return fmt.Errorf("failed to resume session: %w", err)
	}

	log.Info("Session resumed")
	return nil
}

func (s *sessionService) CompleteSession(ctx context.Context, sessionID, userID string) error {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":  "complete_session",
		"session_id": sessionID,
	})

	// Get session
	session, err := s.sessionRepo.GetByID(ctx, sessionID, userID)
	if err != nil {
		log.WithError(err).Debug("Session not found")
		return err
	}

	// Validate session status
	if session.Status != "active" && session.Status != "paused" {
		return fmt.Errorf("session already completed or cancelled")
	}

	// Calculate final duration
	now := time.Now()
	if session.Status == "active" {
		sessionDuration := int(now.Sub(session.StartedAt).Seconds())
		session.Duration += sessionDuration
	}

	session.EndedAt = &now
	session.Status = "completed"

	if err := s.sessionRepo.Update(ctx, session); err != nil {
		log.WithError(err).Error("Failed to complete session")
		return fmt.Errorf("failed to complete session: %w", err)
	}

	log.WithFields(map[string]interface{}{
		"duration_seconds": session.Duration,
		"task_id":          session.TaskID,
	}).Info("Session completed")

	return nil
}

func (s *sessionService) GetActiveSession(ctx context.Context, userID string) (*models.FocusSession, error) {
	log := s.log.WithContext(ctx).WithField("operation", "get_active_session")

	session, err := s.sessionRepo.GetActive(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get active session")
		return nil, fmt.Errorf("failed to get active session: %w", err)
	}

	return session, nil
}

func (s *sessionService) GetSessionHistory(ctx context.Context, userID string, days int) ([]*models.FocusSession, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_session_history",
		"user_id":   userID,
		"days":      days,
	})

	end := time.Now()
	start := end.AddDate(0, 0, -days)

	sessions, err := s.sessionRepo.GetHistory(ctx, userID, start, end)
	if err != nil {
		log.WithError(err).Error("Failed to get session history")
		return nil, fmt.Errorf("failed to get session history: %w", err)
	}

	log.WithField("count", len(sessions)).Debug("Retrieved session history")
	return sessions, nil
}
