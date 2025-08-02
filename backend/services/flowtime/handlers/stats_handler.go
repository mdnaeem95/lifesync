package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/services"
)

type StatsHandler struct {
	statsService services.StatsService
	log          logger.Logger
}

func NewStatsHandler(statsService services.StatsService, log logger.Logger) *StatsHandler {
	return &StatsHandler{
		statsService: statsService,
		log:          log,
	}
}

// GetDailyStats handles GET /api/stats/daily
func (h *StatsHandler) GetDailyStats(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	// Get date from query param (default today)
	dateStr := c.Query("date")
	var date time.Time
	var err error

	if dateStr != "" {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			log.WithError(err).Warn("Invalid date format")
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format. Use YYYY-MM-DD"})
			return
		}
	} else {
		date = time.Now()
	}

	stats, err := h.statsService.GetDailyStats(ctx, userID, date)
	if err != nil {
		log.WithError(err).Error("Failed to get daily stats")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get daily stats"})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetWeeklyStats handles GET /api/stats/weekly
func (h *StatsHandler) GetWeeklyStats(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	stats, err := h.statsService.GetWeeklyStats(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get weekly stats")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get weekly stats"})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetInsights handles GET /api/stats/insights
func (h *StatsHandler) GetInsights(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	insights, err := h.statsService.GetInsights(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get insights")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get insights"})
		return
	}

	c.JSON(http.StatusOK, insights)
}
