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

type SessionHandler struct {
	sessionService services.SessionService
	log            logger.Logger
	validator      *validator.Validate
}

func NewSessionHandler(sessionService services.SessionService, log logger.Logger) *SessionHandler {
	return &SessionHandler{
		sessionService: sessionService,
		log:            log,
		validator:      validator.New(),
	}
}

// StartSession handles POST /api/sessions/start
func (h *SessionHandler) StartSession(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	var req models.StartSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid start session request")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := h.validator.Struct(req); err != nil {
		log.WithError(err).Warn("Session validation failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation failed", "details": err.Error()})
		return
	}

	session, err := h.sessionService.StartSession(ctx, userID, req)
	if err != nil {
		log.WithError(err).Error("Failed to start session")
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, session)
}

// PauseSession handles POST /api/sessions/:id/pause
func (h *SessionHandler) PauseSession(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	sessionID := c.Param("id")
	log := h.log.WithContext(ctx)

	if err := h.sessionService.PauseSession(ctx, sessionID, userID); err != nil {
		log.WithError(err).Error("Failed to pause session")
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Session paused successfully"})
}

// ResumeSession handles POST /api/sessions/:id/resume
func (h *SessionHandler) ResumeSession(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	sessionID := c.Param("id")
	log := h.log.WithContext(ctx)

	if err := h.sessionService.ResumeSession(ctx, sessionID, userID); err != nil {
		log.WithError(err).Error("Failed to resume session")
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Session resumed successfully"})
}

// CompleteSession handles POST /api/sessions/:id/complete
func (h *SessionHandler) CompleteSession(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	sessionID := c.Param("id")
	log := h.log.WithContext(ctx)

	if err := h.sessionService.CompleteSession(ctx, sessionID, userID); err != nil {
		log.WithError(err).Error("Failed to complete session")
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Session completed successfully"})
}

// GetActiveSession handles GET /api/sessions/active
func (h *SessionHandler) GetActiveSession(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("userID")
	log := h.log.WithContext(ctx)

	session, err := h.sessionService.GetActiveSession(ctx, userID)
	if err != nil {
		log.WithError(err).Error("Failed to get active session")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get active session"})
		return
	}

	if session == nil {
		c.JSON(http.StatusOK, gin.H{
			"session": nil,
			"message": "No active session",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"session": session})
}

// GetSessionHistory handles GET /api/sessions/history
func (h *SessionHandler) GetSessionHistory(c *gin.Context) {
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

	sessions, err := h.sessionService.GetSessionHistory(ctx, userID, days)
	if err != nil {
		log.WithError(err).Error("Failed to get session history")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get session history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"sessions": sessions,
		"days":     days,
	})
}
