package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/services"
)

type ScheduleHandler struct {
	scheduleService services.ScheduleService
	taskService     services.TaskService
	log             logger.Logger
	validator       *validator.Validate
}

func NewScheduleHandler(
	scheduleService services.ScheduleService,
	taskService services.TaskService,
	log logger.Logger,
) *ScheduleHandler {
	return &ScheduleHandler{
		scheduleService: scheduleService,
		taskService:     taskService,
		log:             log,
		validator:       validator.New(),
	}
}

// GetTodaySchedule handles GET /api/schedule/today
func (h *ScheduleHandler) GetTodaySchedule(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	today := time.Now()
	tasks, err := h.taskService.GetTasksForDate(ctx, userID, today)
	if err != nil {
		log.WithError(err).Error("Failed to get today's schedule")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get schedule"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"date":  today.Format("2006-01-02"),
		"tasks": tasks,
	})
}

// GetWeekSchedule handles GET /api/schedule/week
func (h *ScheduleHandler) GetWeekSchedule(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	// Get start of week (Monday)
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	startOfWeek := now.AddDate(0, 0, -weekday+1)
	startOfWeek = time.Date(startOfWeek.Year(), startOfWeek.Month(), startOfWeek.Day(), 0, 0, 0, 0, startOfWeek.Location())

	weekSchedule := make(map[string][]*models.Task)

	// Get tasks for each day of the week
	for i := 0; i < 7; i++ {
		date := startOfWeek.AddDate(0, 0, i)
		tasks, err := h.taskService.GetTasksForDate(ctx, userID, date)
		if err != nil {
			log.WithError(err).Warn("Failed to get tasks for date")
			tasks = []*models.Task{} // Empty array instead of nil
		}
		weekSchedule[date.Format("2006-01-02")] = tasks
	}

	c.JSON(http.StatusOK, gin.H{
		"week_start": startOfWeek.Format("2006-01-02"),
		"schedule":   weekSchedule,
	})
}

// OptimizeSchedule handles POST /api/schedule/optimize
func (h *ScheduleHandler) OptimizeSchedule(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	var req models.ScheduleOptimizationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid optimize schedule request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Schedule optimization validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	if err := h.scheduleService.OptimizeSchedule(ctx, userID, req.Date, req.RespectCurrent); err != nil {
		log.WithError(err).Error("Failed to optimize schedule")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to optimize schedule"})
		return
	}

	// Get the optimized schedule
	tasks, err := h.taskService.GetTasksForDate(ctx, userID, req.Date)
	if err != nil {
		log.WithError(err).Error("Failed to get optimized schedule")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get optimized schedule"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Schedule optimized successfully",
		"tasks":   tasks,
	})
}

// GetTimeSlotSuggestions handles GET /api/schedule/suggestions
func (h *ScheduleHandler) GetTimeSlotSuggestions(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	taskID := c.Query("task_id")
	if taskID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "task_id is required"})
		return
	}

	suggestions, err := h.scheduleService.GetSuggestedTimeSlots(ctx, userID, taskID)
	if err != nil {
		log.WithError(err).Error("Failed to get time slot suggestions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get suggestions"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"suggestions": suggestions})
}
