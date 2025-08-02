package repository

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
)

type EnergyRepository interface {
	RecordLevel(ctx context.Context, energy *models.EnergyLevel) error
	GetCurrent(ctx context.Context, userID string) (*models.EnergyLevel, error)
	GetHistory(ctx context.Context, userID string, start, end time.Time) ([]*models.EnergyLevel, error)
	GetPattern(ctx context.Context, userID string, dayOfWeek, hourOfDay int) (*models.EnergyPattern, error)
	UpdatePattern(ctx context.Context, pattern *models.EnergyPattern) error
	CreatePattern(ctx context.Context, pattern *models.EnergyPattern) error
	GetAllPatterns(ctx context.Context, userID string) ([]*models.EnergyPattern, error)
}

type energyRepository struct {
	db  *sql.DB
	log logger.Logger
}

func NewEnergyRepository(db *sql.DB, log logger.Logger) EnergyRepository {
	return &energyRepository{
		db:  db,
		log: log,
	}
}

func (r *energyRepository) RecordLevel(ctx context.Context, energy *models.EnergyLevel) error {
	log := r.log.WithContext(ctx).WithField("operation", "record_energy_level")

	energy.ID = uuid.New().String()
	energy.CreatedAt = time.Now()

	// Convert factors map to JSON
	factorsJSON, err := json.Marshal(energy.Factors)
	if err != nil {
		log.WithError(err).Error("Failed to marshal factors")
		return fmt.Errorf("failed to marshal factors: %w", err)
	}

	query := `
		INSERT INTO energy_levels (id, user_id, level, recorded_at, factors, source, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`

	_, err = r.db.ExecContext(
		ctx, query,
		energy.ID, energy.UserID, energy.Level,
		energy.RecordedAt, factorsJSON, energy.Source,
		energy.CreatedAt,
	)

	if err != nil {
		log.WithError(err).Error("Failed to record energy level")
		return fmt.Errorf("failed to record energy level: %w", err)
	}

	log.WithFields(map[string]interface{}{
		"user_id": energy.UserID,
		"level":   energy.Level,
		"source":  energy.Source,
	}).Info("Energy level recorded")

	// Update energy pattern asynchronously
	go r.updateEnergyPattern(context.Background(), energy.UserID, energy.RecordedAt, energy.Level)

	return nil
}

func (r *energyRepository) GetCurrent(ctx context.Context, userID string) (*models.EnergyLevel, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_current_energy",
		"user_id":   userID,
	})

	var energy models.EnergyLevel
	var factorsJSON []byte

	query := `
		SELECT id, user_id, level, recorded_at, factors, source, created_at
		FROM energy_levels
		WHERE user_id = $1
		ORDER BY recorded_at DESC
		LIMIT 1
	`

	err := r.db.QueryRowContext(ctx, query, userID).Scan(
		&energy.ID, &energy.UserID, &energy.Level,
		&energy.RecordedAt, &factorsJSON, &energy.Source,
		&energy.CreatedAt,
	)

	if err == sql.ErrNoRows {
		log.Debug("No energy levels found")
		return nil, nil
	}
	if err != nil {
		log.WithError(err).Error("Failed to get current energy level")
		return nil, fmt.Errorf("failed to get current energy level: %w", err)
	}

	// Unmarshal factors
	if len(factorsJSON) > 0 {
		if err := json.Unmarshal(factorsJSON, &energy.Factors); err != nil {
			log.WithError(err).Warn("Failed to unmarshal factors")
		}
	}

	return &energy, nil
}

func (r *energyRepository) GetHistory(ctx context.Context, userID string, start, end time.Time) ([]*models.EnergyLevel, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_energy_history",
		"user_id":   userID,
		"start":     start,
		"end":       end,
	})

	query := `
		SELECT id, user_id, level, recorded_at, factors, source, created_at
		FROM energy_levels
		WHERE user_id = $1 AND recorded_at >= $2 AND recorded_at < $3
		ORDER BY recorded_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID, start, end)
	if err != nil {
		log.WithError(err).Error("Failed to get energy history")
		return nil, fmt.Errorf("failed to get energy history: %w", err)
	}
	defer rows.Close()

	var levels []*models.EnergyLevel
	for rows.Next() {
		var energy models.EnergyLevel
		var factorsJSON []byte

		if err := rows.Scan(
			&energy.ID, &energy.UserID, &energy.Level,
			&energy.RecordedAt, &factorsJSON, &energy.Source,
			&energy.CreatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan energy level")
			continue
		}

		// Unmarshal factors
		if len(factorsJSON) > 0 {
			if err := json.Unmarshal(factorsJSON, &energy.Factors); err != nil {
				log.WithError(err).Warn("Failed to unmarshal factors")
			}
		}

		levels = append(levels, &energy)
	}

	return levels, nil
}

func (r *energyRepository) GetPattern(ctx context.Context, userID string, dayOfWeek, hourOfDay int) (*models.EnergyPattern, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":   "get_energy_pattern",
		"user_id":     userID,
		"day_of_week": dayOfWeek,
		"hour_of_day": hourOfDay,
	})

	var pattern models.EnergyPattern
	query := `
		SELECT id, user_id, day_of_week, hour_of_day, average_energy, sample_count, created_at, updated_at
		FROM energy_patterns
		WHERE user_id = $1 AND day_of_week = $2 AND hour_of_day = $3
	`

	err := r.db.QueryRowContext(ctx, query, userID, dayOfWeek, hourOfDay).Scan(
		&pattern.ID, &pattern.UserID, &pattern.DayOfWeek, &pattern.HourOfDay,
		&pattern.AverageEnergy, &pattern.SampleCount, &pattern.CreatedAt, &pattern.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		log.WithError(err).Error("Failed to get energy pattern")
		return nil, fmt.Errorf("failed to get energy pattern: %w", err)
	}

	return &pattern, nil
}

func (r *energyRepository) UpdatePattern(ctx context.Context, pattern *models.EnergyPattern) error {
	log := r.log.WithContext(ctx).WithField("operation", "update_energy_pattern")

	pattern.UpdatedAt = time.Now()

	query := `
		UPDATE energy_patterns 
		SET average_energy = $1, sample_count = $2, updated_at = $3
		WHERE id = $4
	`

	_, err := r.db.ExecContext(
		ctx, query,
		pattern.AverageEnergy, pattern.SampleCount, pattern.UpdatedAt, pattern.ID,
	)

	if err != nil {
		log.WithError(err).Error("Failed to update energy pattern")
		return fmt.Errorf("failed to update energy pattern: %w", err)
	}

	return nil
}

func (r *energyRepository) CreatePattern(ctx context.Context, pattern *models.EnergyPattern) error {
	log := r.log.WithContext(ctx).WithField("operation", "create_energy_pattern")

	pattern.ID = uuid.New().String()
	pattern.CreatedAt = time.Now()
	pattern.UpdatedAt = time.Now()

	query := `
		INSERT INTO energy_patterns (
			id, user_id, day_of_week, hour_of_day, average_energy, 
			sample_count, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.db.ExecContext(
		ctx, query,
		pattern.ID, pattern.UserID, pattern.DayOfWeek, pattern.HourOfDay,
		pattern.AverageEnergy, pattern.SampleCount, pattern.CreatedAt, pattern.UpdatedAt,
	)

	if err != nil {
		log.WithError(err).Error("Failed to create energy pattern")
		return fmt.Errorf("failed to create energy pattern: %w", err)
	}

	return nil
}

func (r *energyRepository) GetAllPatterns(ctx context.Context, userID string) ([]*models.EnergyPattern, error) {
	log := r.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_all_energy_patterns",
		"user_id":   userID,
	})

	query := `
		SELECT id, user_id, day_of_week, hour_of_day, average_energy, sample_count, created_at, updated_at
		FROM energy_patterns
		WHERE user_id = $1
		ORDER BY day_of_week, hour_of_day
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get energy patterns")
		return nil, fmt.Errorf("failed to get energy patterns: %w", err)
	}
	defer rows.Close()

	var patterns []*models.EnergyPattern
	for rows.Next() {
		var pattern models.EnergyPattern
		if err := rows.Scan(
			&pattern.ID, &pattern.UserID, &pattern.DayOfWeek, &pattern.HourOfDay,
			&pattern.AverageEnergy, &pattern.SampleCount, &pattern.CreatedAt, &pattern.UpdatedAt,
		); err != nil {
			log.WithError(err).Error("Failed to scan energy pattern")
			continue
		}
		patterns = append(patterns, &pattern)
	}

	return patterns, nil
}

// updateEnergyPattern updates the energy pattern based on new energy reading
func (r *energyRepository) updateEnergyPattern(ctx context.Context, userID string, recordedAt time.Time, level int) {
	dayOfWeek := int(recordedAt.Weekday())
	hourOfDay := recordedAt.Hour()

	pattern, err := r.GetPattern(ctx, userID, dayOfWeek, hourOfDay)
	if err != nil {
		r.log.WithError(err).Error("Failed to get pattern for update")
		return
	}

	if pattern == nil {
		// Create new pattern
		pattern = &models.EnergyPattern{
			UserID:        userID,
			DayOfWeek:     dayOfWeek,
			HourOfDay:     hourOfDay,
			AverageEnergy: float64(level),
			SampleCount:   1,
		}
		if err := r.CreatePattern(ctx, pattern); err != nil {
			r.log.WithError(err).Error("Failed to create energy pattern")
		}
	} else {
		// Update existing pattern with running average
		newAverage := (pattern.AverageEnergy*float64(pattern.SampleCount) + float64(level)) / float64(pattern.SampleCount+1)
		pattern.AverageEnergy = newAverage
		pattern.SampleCount++

		if err := r.UpdatePattern(ctx, pattern); err != nil {
			r.log.WithError(err).Error("Failed to update energy pattern")
		}
	}
}
