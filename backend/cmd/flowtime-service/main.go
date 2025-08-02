package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/internal/middleware"
	"github.com/mdnaeem95/lifesync/backend/pkg/database"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/auth/services"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/handlers"
	"github.com/mdnaeem95/lifesync/backend/services/flowtime/repository"
	flowtimeServices "github.com/mdnaeem95/lifesync/backend/services/flowtime/services"
)

func main() {
	// Initialize logger
	log := logger.New()
	log.Info("Starting FlowTime Service")

	// Load configuration
	cfg := config.LoadFlowTimeConfig()
	log.WithField("config", cfg.GetSafeConfig()).Info("Configuration loaded")

	// Initialize database
	db, err := database.New(cfg.DatabaseURL)
	if err != nil {
		log.WithError(err).Fatal("Failed to connect to database")
	}
	defer db.Close()

	// Run migrations
	if err := database.RunFlowTimeMigrations(db); err != nil {
		log.WithError(err).Fatal("Failed to run migrations")
	}

	// Initialize repositories
	taskRepo := repository.NewTaskRepository(db, log)
	energyRepo := repository.NewEnergyRepository(db, log)
	sessionRepo := repository.NewSessionRepository(db, log)
	prefRepo := repository.NewPreferencesRepository(db, log)

	// Initialize services
	jwtService := services.NewJWTService(cfg.JWTSecret, log)
	taskService := flowtimeServices.NewTaskService(taskRepo, log)
	energyService := flowtimeServices.NewEnergyService(energyRepo, log)
	sessionService := flowtimeServices.NewSessionService(sessionRepo, taskRepo, log)
	scheduleService := flowtimeServices.NewScheduleService(taskRepo, energyService, prefRepo, log)
	statsService := flowtimeServices.NewStatsService(taskRepo, sessionRepo, energyRepo, log)

	// Initialize handlers
	taskHandler := handlers.NewTaskHandler(taskService, log)
	energyHandler := handlers.NewEnergyHandler(energyService, log)
	sessionHandler := handlers.NewSessionHandler(sessionService, log)
	scheduleHandler := handlers.NewScheduleHandler(scheduleService, taskService, log)
	statsHandler := handlers.NewStatsHandler(statsService, log)
	preferencesHandler := handlers.NewPreferencesHandler(prefRepo, log)

	// Setup router
	router := setupRouter(cfg, jwtService, taskHandler, energyHandler, sessionHandler, scheduleHandler, statsHandler, preferencesHandler, log)

	// Create server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.WithField("port", cfg.Port).Info("Starting HTTP server")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.WithError(err).Fatal("Failed to start server")
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.WithError(err).Error("Server forced to shutdown")
	}

	log.Info("Server exited")
}

func setupRouter(
	cfg *config.FlowTimeConfig,
	jwtService services.JWTService,
	taskHandler *handlers.TaskHandler,
	energyHandler *handlers.EnergyHandler,
	sessionHandler *handlers.SessionHandler,
	scheduleHandler *handlers.ScheduleHandler,
	statsHandler *handlers.StatsHandler,
	preferencesHandler *handlers.PreferencesHandler,
	log logger.Logger,
) *gin.Engine {
	// Set Gin mode
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Global middleware
	router.Use(middleware.Logger(log))
	router.Use(middleware.Recovery(log))
	router.Use(middleware.CORS(cfg.AllowedOrigins))
	router.Use(middleware.RequestID())

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "flowtime-service",
			"version": cfg.Version,
		})
	})

	// API routes - all require authentication
	api := router.Group("/api")
	api.Use(middleware.AuthRequired(jwtService))
	{
		// Task routes
		api.POST("/tasks", taskHandler.CreateTask)
		api.GET("/tasks", taskHandler.GetTasks)
		api.GET("/tasks/upcoming", taskHandler.GetUpcomingTasks)
		api.GET("/tasks/:id", taskHandler.GetTask)
		api.PUT("/tasks/:id", taskHandler.UpdateTask)
		api.DELETE("/tasks/:id", taskHandler.DeleteTask)
		api.POST("/tasks/:id/complete", taskHandler.CompleteTask)
		api.POST("/tasks/:id/reschedule", taskHandler.RescheduleTask)

		// Energy routes
		api.POST("/energy", energyHandler.RecordEnergy)
		api.GET("/energy/current", energyHandler.GetCurrentEnergy)
		api.GET("/energy/history", energyHandler.GetEnergyHistory)
		api.GET("/energy/patterns", energyHandler.GetEnergyPatterns)

		// Session routes
		api.POST("/sessions/start", sessionHandler.StartSession)
		api.POST("/sessions/:id/pause", sessionHandler.PauseSession)
		api.POST("/sessions/:id/resume", sessionHandler.ResumeSession)
		api.POST("/sessions/:id/complete", sessionHandler.CompleteSession)
		api.GET("/sessions/active", sessionHandler.GetActiveSession)
		api.GET("/sessions/history", sessionHandler.GetSessionHistory)

		// Schedule routes
		api.GET("/schedule/today", scheduleHandler.GetTodaySchedule)
		api.GET("/schedule/week", scheduleHandler.GetWeekSchedule)
		api.POST("/schedule/optimize", scheduleHandler.OptimizeSchedule)
		api.GET("/schedule/suggestions", scheduleHandler.GetTimeSlotSuggestions)

		// Stats routes
		api.GET("/stats/daily", statsHandler.GetDailyStats)
		api.GET("/stats/weekly", statsHandler.GetWeeklyStats)
		api.GET("/stats/insights", statsHandler.GetInsights)

		// Preferences routes
		api.GET("/preferences", preferencesHandler.GetPreferences)
		api.PUT("/preferences", preferencesHandler.UpdatePreferences)
	}

	return router
}
