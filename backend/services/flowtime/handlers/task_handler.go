package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/models"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/services"
)

type TaskHandler struct {
	taskService services.TaskService
	log         logger.Logger
	validator   *validator.Validate
}

func NewTaskHandler(taskService services.TaskService, log logger.Logger) *TaskHandler {
	return &TaskHandler{
		taskService: taskService,
		log:         log,
		validator:   validator.New(),
	}
}

// CreateTask handles POST /api/tasks
func (h *TaskHandler) CreateTask(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	var req models.CreateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid create task request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Task validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	task, err := h.taskService.CreateTask(ctx, userID, req)
	if err != nil {
		log.WithError(err).Error("Failed to create task")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create task"})
		return
	}

	c.JSON(http.StatusCreated, task)
}

// GetTasks handles GET /api/tasks
func (h *TaskHandler) GetTasks(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	// Query parameters
	includeCompleted := c.Query("include_completed") == "true"
	dateStr := c.Query("date")

	// If specific date requested
	if dateStr != "" {
		date, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			log.WithError(err).Warn("Invalid date format")
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format"})
			return
		}

		tasks, err := h.taskService.GetTasksForDate(ctx, userID, date)
		if err != nil {
			log.WithError(err).Error("Failed to get tasks for date")
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get tasks"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"tasks": tasks})
		return
	}

	// Get all tasks
	tasks, err := h.taskService.GetUserTasks(ctx, userID, includeCompleted)
	if err != nil {
		log.WithError(err).Error("Failed to get tasks")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get tasks"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"tasks": tasks})
}

// GetTask handles GET /api/tasks/:id
func (h *TaskHandler) GetTask(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	taskID := c.Param("id")
	log := h.log.WithContext(ctx)

	task, err := h.taskService.GetTask(ctx, taskID, userID)
	if err != nil {
		log.WithError(err).Debug("Task not found")
		c.JSON(http.StatusNotFound, gin.H{"error": "Task not found"})
		return
	}

	c.JSON(http.StatusOK, task)
}

// UpdateTask handles PUT /api/tasks/:id
func (h *TaskHandler) UpdateTask(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	taskID := c.Param("id")
	log := h.log.WithContext(ctx)

	var req models.UpdateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid update task request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Task validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	task, err := h.taskService.UpdateTask(ctx, taskID, userID, req)
	if err != nil {
		log.WithError(err).Error("Failed to update task")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update task"})
		return
	}

	c.JSON(http.StatusOK, task)
}

// DeleteTask handles DELETE /api/tasks/:id
func (h *TaskHandler) DeleteTask(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	taskID := c.Param("id")
	log := h.log.WithContext(ctx)

	if err := h.taskService.DeleteTask(ctx, taskID, userID); err != nil {
		log.WithError(err).Error("Failed to delete task")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete task"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Task deleted successfully"})
}

// CompleteTask handles POST /api/tasks/:id/complete
func (h *TaskHandler) CompleteTask(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	taskID := c.Param("id")
	log := h.log.WithContext(ctx)

	if err := h.taskService.CompleteTask(ctx, taskID, userID); err != nil {
		log.WithError(err).Error("Failed to complete task")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete task"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Task completed successfully"})
}

// RescheduleTask handles POST /api/tasks/:id/reschedule
func (h *TaskHandler) RescheduleTask(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	taskID := c.Param("id")
	log := h.log.WithContext(ctx)

	var req struct {
		NewTime time.Time `json:"new_time" validate:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid reschedule request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.taskService.RescheduleTask(ctx, taskID, userID, req.NewTime); err != nil {
		log.WithError(err).Error("Failed to reschedule task")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reschedule task"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Task rescheduled successfully"})
}

// GetUpcomingTasks handles GET /api/tasks/upcoming
func (h *TaskHandler) GetUpcomingTasks(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	// Get limit from query param
	limit := 10
	if limitStr := c.Query("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 50 {
			limit = l
		}
	}

	tasks, err := h.taskService.GetUpcomingTasks(ctx, userID, limit)
	if err != nil {
		log.WithError(err).Error("Failed to get upcoming tasks")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get upcoming tasks"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"tasks": tasks})
}
