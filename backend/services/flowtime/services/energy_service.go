package services

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
)

type EnergyService interface {
	RecordEnergyLevel(ctx context.Context, userID string, req models.RecordEnergyRequest) error
	GetCurrentEnergy(ctx context.Context, userID string) (*models.EnergyLevel, error)
	GetEnergyHistory(ctx context.Context, userID string, days int) ([]*models.EnergyLevel, error)
	GetEnergyPatterns(ctx context.Context, userID string) ([]*models.EnergyPattern, error)
	PredictEnergyLevel(ctx context.Context, userID string, targetTime time.Time) (int, error)
	GetOptimalTimeSlots(ctx context.Context, userID string, duration int, count int) ([]models.TimeSlotSuggestion, error)
}

type energyService struct {
	energyRepo repository.EnergyRepository
	log        logger.Logger
}

func NewEnergyService(energyRepo repository.EnergyRepository, log logger.Logger) EnergyService {
	return &energyService{
		energyRepo: energyRepo,
		log:        log,
	}
}

func (s *energyService) RecordEnergyLevel(ctx context.Context, userID string, req models.RecordEnergyRequest) error {
	log := s.log.WithContext(ctx).WithField("operation", "record_energy_level")

	energy := &models.EnergyLevel{
		UserID:     userID,
		Level:      req.Level,
		RecordedAt: time.Now(),
		Factors:    req.Factors,
		Source:     req.Source,
	}

	if err := s.energyRepo.RecordLevel(ctx, energy); err != nil {
		log.WithError(err).Error("Failed to record energy level")
		return fmt.Errorf("failed to record energy level: %w", err)
	}

	log.WithFields(map[string]interface{}{
		"user_id": userID,
		"level":   req.Level,
		"source":  req.Source,
	}).Info("Energy level recorded")

	return nil
}

func (s *energyService) GetCurrentEnergy(ctx context.Context, userID string) (*models.EnergyLevel, error) {
	log := s.log.WithContext(ctx).WithField("operation", "get_current_energy")

	// Get most recent energy level
	current, err := s.energyRepo.GetCurrent(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get current energy")
		return nil, fmt.Errorf("failed to get current energy: %w", err)
	}

	// If no recorded energy or it's older than 2 hours, predict it
	if current == nil || time.Since(current.RecordedAt) > 2*time.Hour {
		predictedLevel, err := s.PredictEnergyLevel(ctx, userID, time.Now())
		if err != nil {
			log.WithError(err).Warn("Failed to predict energy level")
			// Return last known if prediction fails
			return current, nil
		}

		// Create predicted energy level
		current = &models.EnergyLevel{
			UserID:     userID,
			Level:      predictedLevel,
			RecordedAt: time.Now(),
			Source:     "predicted",
			Factors: map[string]interface{}{
				"based_on": "energy_patterns",
			},
		}
	}

	return current, nil
}

func (s *energyService) GetEnergyHistory(ctx context.Context, userID string, days int) ([]*models.EnergyLevel, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_energy_history",
		"user_id":   userID,
		"days":      days,
	})

	end := time.Now()
	start := end.AddDate(0, 0, -days)

	history, err := s.energyRepo.GetHistory(ctx, userID, start, end)
	if err != nil {
		log.WithError(err).Error("Failed to get energy history")
		return nil, fmt.Errorf("failed to get energy history: %w", err)
	}

	log.WithField("count", len(history)).Debug("Retrieved energy history")
	return history, nil
}

func (s *energyService) GetEnergyPatterns(ctx context.Context, userID string) ([]*models.EnergyPattern, error) {
	log := s.log.WithContext(ctx).WithField("operation", "get_energy_patterns")

	patterns, err := s.energyRepo.GetAllPatterns(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get energy patterns")
		return nil, fmt.Errorf("failed to get energy patterns: %w", err)
	}

	return patterns, nil
}

func (s *energyService) PredictEnergyLevel(ctx context.Context, userID string, targetTime time.Time) (int, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation":   "predict_energy_level",
		"user_id":     userID,
		"target_time": targetTime,
	})

	dayOfWeek := int(targetTime.Weekday())
	hourOfDay := targetTime.Hour()

	// Get pattern for this time
	pattern, err := s.energyRepo.GetPattern(ctx, userID, dayOfWeek, hourOfDay)
	if err != nil {
		log.WithError(err).Error("Failed to get energy pattern")
		return 50, err // Default to medium energy
	}

	if pattern == nil || pattern.SampleCount < 3 {
		// Not enough data, use circadian rhythm defaults
		return s.getDefaultEnergyLevel(hourOfDay), nil
	}

	// Apply ultradian rhythm adjustment (90-minute cycles)
	minutesIntoDay := targetTime.Hour()*60 + targetTime.Minute()
	ultradianPhase := float64(minutesIntoDay%90) / 90.0
	ultradianAdjustment := math.Sin(ultradianPhase*math.Pi*2) * 5

	predictedLevel := int(pattern.AverageEnergy + ultradianAdjustment)

	// Clamp to valid range
	if predictedLevel < 1 {
		predictedLevel = 1
	} else if predictedLevel > 100 {
		predictedLevel = 100
	}

	log.WithField("predicted_level", predictedLevel).Debug("Energy level predicted")
	return predictedLevel, nil
}

func (s *energyService) GetOptimalTimeSlots(ctx context.Context, userID string, duration int, count int) ([]models.TimeSlotSuggestion, error) {
	log := s.log.WithContext(ctx).WithFields(map[string]interface{}{
		"operation": "get_optimal_time_slots",
		"user_id":   userID,
		"duration":  duration,
		"count":     count,
	})

	suggestions := []models.TimeSlotSuggestion{}
	now := time.Now()

	// Check next 7 days
	for d := 0; d < 7; d++ {
		checkDate := now.AddDate(0, 0, d)

		// Check each hour of the work day (8 AM to 6 PM)
		for h := 8; h < 18; h++ {
			slotStart := time.Date(
				checkDate.Year(), checkDate.Month(), checkDate.Day(),
				h, 0, 0, 0, checkDate.Location(),
			)

			// Skip if in the past
			if slotStart.Before(now) {
				continue
			}

			slotEnd := slotStart.Add(time.Duration(duration) * time.Minute)

			// Predict energy for this slot
			energyLevel, err := s.PredictEnergyLevel(ctx, userID, slotStart)
			if err != nil {
				log.WithError(err).Warn("Failed to predict energy for slot")
				continue
			}

			// Calculate conflict score (0-1, lower is better)
			// In a real implementation, this would check calendar conflicts
			conflictScore := 0.0

			// Create suggestion
			suggestion := models.TimeSlotSuggestion{
				StartTime:     slotStart,
				EndTime:       slotEnd,
				EnergyLevel:   energyLevel,
				ConflictScore: conflictScore,
				Reason:        s.getSlotReason(energyLevel, h),
			}

			suggestions = append(suggestions, suggestion)
		}
	}

	// Sort by energy level (descending) and conflict score (ascending)
	// In a real implementation, use a proper sorting algorithm

	// Return top N suggestions
	if len(suggestions) > count {
		suggestions = suggestions[:count]
	}

	return suggestions, nil
}

// getDefaultEnergyLevel returns circadian rhythm-based default energy levels
func (s *energyService) getDefaultEnergyLevel(hour int) int {
	// Based on typical circadian rhythms
	switch {
	case hour >= 6 && hour < 9:
		return 60 // Morning rise
	case hour >= 9 && hour < 11:
		return 80 // Morning peak
	case hour >= 11 && hour < 13:
		return 75 // Pre-lunch
	case hour >= 13 && hour < 15:
		return 50 // Post-lunch dip
	case hour >= 15 && hour < 17:
		return 70 // Afternoon recovery
	case hour >= 17 && hour < 19:
		return 65 // Early evening
	case hour >= 19 && hour < 21:
		return 55 // Evening decline
	case hour >= 21 && hour < 23:
		return 40 // Pre-sleep
	default:
		return 30 // Night time
	}
}

// getSlotReason provides a human-readable reason for the time slot suggestion
func (s *energyService) getSlotReason(energyLevel int, hour int) string {
	switch {
	case energyLevel >= 80:
		return "Peak energy period - ideal for complex tasks"
	case energyLevel >= 70:
		return "High energy - good for focused work"
	case energyLevel >= 60:
		return "Moderate energy - suitable for regular tasks"
	case energyLevel >= 50:
		return "Lower energy - better for routine tasks"
	default:
		return "Low energy period - consider breaks or light tasks"
	}
}
