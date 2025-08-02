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

type PreferencesRepository interface {
	GetByUserID(ctx context.Context, userID string) (*models.UserPreferences, error)
	Create(ctx context.Context, prefs *models.UserPreferences) error
	Update(ctx context.Context, prefs *models.UserPreferences) error
}

type preferencesRepository struct {
	db  *sql.DB
	log logger.Logger
}

func NewPreferencesRepository(db *sql.DB, log logger.Logger) PreferencesRepository {
	return &preferencesRepository{
		db:  db,
		log: log,
	}
}

func (r *preferencesRepository) GetByUserID(ctx context.Context, userID string) (*models.UserPreferences, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_preferences_by_user",
		"user_id":   userID,
	})

	var prefs models.UserPreferences
	query := `
		SELECT 
			id, user_id, work_hours_start, work_hours_end, break_duration,
			focus_protocol, energy_update_freq, notifications_on, smart_scheduling,
			preferred_task_time, created_at, updated_at
		FROM user_preferences
		WHERE user_id = $1
	`

	err := r.db.QueryRowContext(ctx, query, userID).Scan(
		&prefs.ID, &prefs.UserID, &prefs.WorkHoursStart, &prefs.WorkHoursEnd,
		&prefs.BreakDuration, &prefs.FocusProtocol, &prefs.EnergyUpdateFreq,
		&prefs.NotificationsOn, &prefs.SmartScheduling, &prefs.PreferredTaskTime,
		&prefs.CreatedAt, &prefs.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		// Create default preferences for new user
		log.Debug("No preferences found, creating defaults")
		defaultPrefs := r.createDefaultPreferences(userID)
		if err := r.Create(ctx, defaultPrefs); err != nil {
			return nil, err
		}
		return defaultPrefs, nil
	}
	if err != nil {
		log.WithError(err).Error("Failed to get preferences")
		return nil, fmt.Errorf("failed to get preferences: %w", err)
	}

	return &prefs, nil
}

func (r *preferencesRepository) Create(ctx context.Context, prefs *models.UserPreferences) error {
	log := r.log.WithContext(ctx).WithField("operation", "create_preferences")

	prefs.ID = uuid.New().String()
	prefs.CreatedAt = time.Now()
	prefs.UpdatedAt = time.Now()

	query := `
		INSERT INTO user_preferences (
			id, user_id, work_hours_start, work_hours_end, break_duration,
			focus_protocol, energy_update_freq, notifications_on, smart_scheduling,
			preferred_task_time, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	_, err := r.db.ExecContext(
		ctx, query,
		prefs.ID, prefs.UserID, prefs.WorkHoursStart, prefs.WorkHoursEnd,
		prefs.BreakDuration, prefs.FocusProtocol, prefs.EnergyUpdateFreq,
		prefs.NotificationsOn, prefs.SmartScheduling, prefs.PreferredTaskTime,
		prefs.CreatedAt, prefs.UpdatedAt,
	)

	if err != nil {
		log.WithError(err).Error("Failed to create preferences")
		return fmt.Errorf("failed to create preferences: %w", err)
	}

	log.WithField("user_id", prefs.UserID).Info("Preferences created")
	return nil
}

func (r *preferencesRepository) Update(ctx context.Context, prefs *models.UserPreferences) error {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "update_preferences",
		"user_id":   prefs.UserID,
	})

	prefs.UpdatedAt = time.Now()

	query := `
		UPDATE user_preferences SET
			work_hours_start = $1, work_hours_end = $2, break_duration = $3,
			focus_protocol = $4, energy_update_freq = $5, notifications_on = $6,
			smart_scheduling = $7, preferred_task_time = $8, updated_at = $9
		WHERE user_id = $10
	`

	result, err := r.db.ExecContext(
		ctx, query,
		prefs.WorkHoursStart, prefs.WorkHoursEnd, prefs.BreakDuration,
		prefs.FocusProtocol, prefs.EnergyUpdateFreq, prefs.NotificationsOn,
		prefs.SmartScheduling, prefs.PreferredTaskTime, prefs.UpdatedAt,
		prefs.UserID,
	)

	if err != nil {
		log.WithError(err).Error("Failed to update preferences")
		return fmt.Errorf("failed to update preferences: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("preferences not found")
	}

	log.Info("Preferences updated")
	return nil
}

func (r *preferencesRepository) createDefaultPreferences(userID string) *models.UserPreferences {
	return &models.UserPreferences{
		UserID:            userID,
		WorkHoursStart:    "09:00",
		WorkHoursEnd:      "17:00",
		BreakDuration:     15,
		FocusProtocol:     "pomodoro",
		EnergyUpdateFreq:  60,
		NotificationsOn:   true,
		SmartScheduling:   true,
		PreferredTaskTime: 60,
	}
}
