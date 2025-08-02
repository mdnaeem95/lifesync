package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/services"
)

type EnergyHandler struct {
	energyService services.EnergyService
	log           logger.Logger
	validator     *validator.Validate
}

func NewEnergyHandler(energyService services.EnergyService, log logger.Logger) *EnergyHandler {
	return &EnergyHandler{
		energyService: energyService,
		log:           log,
		validator:     validator.New(),
	}
}

// RecordEnergy handles POST /api/energy
func (h *EnergyHandler) RecordEnergy(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	var req models.RecordEnergyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid record energy request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Energy validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	if err := h.energyService.RecordEnergyLevel(ctx, userID, req); err != nil {
		log.WithError(err).Error("Failed to record energy level")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record energy level"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Energy level recorded successfully"})
}

// GetCurrentEnergy handles GET /api/energy/current
func (h *EnergyHandler) GetCurrentEnergy(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	energy, err := h.energyService.GetCurrentEnergy(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get current energy")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get current energy"})
		return
	}

	if energy == nil {
		c.JSON(http.StatusOK, gin.H{
			"energy":  nil,
			"message": "No energy data available",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"energy": energy})
}

// GetEnergyHistory handles GET /api/energy/history
func (h *EnergyHandler) GetEnergyHistory(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	// Get days from query param (default 7)
	days := 7
	if daysStr := c.Query("days"); daysStr != "" {
		if d, err := strconv.Atoi(daysStr); err == nil && d > 0 && d <= 30 {
			days = d
		}
	}

	history, err := h.energyService.GetEnergyHistory(ctx, userID, days)
	if err != nil {
		log.WithError(err).Error("Failed to get energy history")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get energy history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"history": history,
		"days":    days,
	})
}

// GetEnergyPatterns handles GET /api/energy/patterns
func (h *EnergyHandler) GetEnergyPatterns(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	patterns, err := h.energyService.GetEnergyPatterns(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get energy patterns")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get energy patterns"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"patterns": patterns})
}
