package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
)

type PreferencesHandler struct {
	prefRepo  repository.PreferencesRepository
	log       logger.Logger
	validator *validator.Validate
}

func NewPreferencesHandler(prefRepo repository.PreferencesRepository, log logger.Logger) *PreferencesHandler {
	return &PreferencesHandler{
		prefRepo:  prefRepo,
		log:       log,
		validator: validator.New(),
	}
}

// GetPreferences handles GET /api/preferences
func (h *PreferencesHandler) GetPreferences(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	preferences, err := h.prefRepo.GetByUserID(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get preferences")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get preferences"})
		return
	}

	c.JSON(http.StatusOK, preferences)
}

// UpdatePreferences handles PUT /api/preferences
func (h *PreferencesHandler) UpdatePreferences(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	var req models.UpdatePreferencesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid update preferences request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Preferences validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	// Get existing preferences
	prefs, err := h.prefRepo.GetByUserID(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get existing preferences")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update preferences"})
		return
	}

	// Update fields if provided
	if req.WorkHoursStart != nil {
		prefs.WorkHoursStart = *req.WorkHoursStart
	}
	if req.WorkHoursEnd != nil {
		prefs.WorkHoursEnd = *req.WorkHoursEnd
	}
	if req.BreakDuration != nil {
		prefs.BreakDuration = *req.BreakDuration
	}
	if req.FocusProtocol != nil {
		prefs.FocusProtocol = *req.FocusProtocol
	}
	if req.EnergyUpdateFreq != nil {
		prefs.EnergyUpdateFreq = *req.EnergyUpdateFreq
	}
	if req.NotificationsOn != nil {
		prefs.NotificationsOn = *req.NotificationsOn
	}
	if req.SmartScheduling != nil {
		prefs.SmartScheduling = *req.SmartScheduling
	}
	if req.PreferredTaskTime != nil {
		prefs.PreferredTaskTime = *req.PreferredTaskTime
	}

	// Update in database
	if err := h.prefRepo.Update(ctx, prefs); err != nil {
		log.WithError(err).Error("Failed to update preferences")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update preferences"})
		return
	}

	log.Info("Preferences updated successfully")
	c.JSON(http.StatusOK, prefs)
}
