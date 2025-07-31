package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/lifesync/flowtime/auth-service/config"
	"github.com/lifesync/flowtime/auth-service/internal/handlers"
	"github.com/lifesync/flowtime/auth-service/internal/middleware"
	"github.com/lifesync/flowtime/auth-service/internal/repository"
	"github.com/lifesync/flowtime/auth-service/internal/services"
	"github.com/lifesync/flowtime/auth-service/pkg/database"
	"github.com/lifesync/flowtime/auth-service/pkg/logger"

	"github.com/gin-gonic/gin"
)

func main() {
	// Initialize logger
	log := logger.New()
	log.Info("Starting FlowTime Auth Service")

	// Load configuration
	cfg := config.Load()
	log.WithField("config", cfg.GetSafeConfig()).Info("Configuration loaded")

	// Initialize database
	db, err := database.New(cfg.DatabaseURL)
	if err != nil {
		log.WithError(err).Fatal("Failed to connect to database")
	}
	defer db.Close()

	// Run migrations
	if err := database.Migrate(db); err != nil {
		log.WithError(err).Fatal("Failed to run migrations")
	}

	// Initialize repositories
	userRepo := repository.NewUserRepository(db, log)

	// Initialize services
	jwtService := services.NewJWTService(cfg.JWTSecret, log)
	authService := services.NewAuthService(userRepo, jwtService, log)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(authService, log)

	// Setup router
	router := setupRouter(cfg, authHandler, jwtService, log)

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

func setupRouter(cfg *config.Config, authHandler *handlers.AuthHandler, jwtService services.JWTService, log logger.Logger) *gin.Engine {
	// Set Gin mode
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Global middleware
	router.Use(middleware.Logger(log))
	router.Use(middleware.Recovery(log))
	router.Use(middleware.CORS(cfg))
	router.Use(middleware.RequestID())
	router.Use(middleware.RateLimit(cfg))

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "auth-service",
			"version": cfg.Version,
		})
	})

	// Auth routes
	auth := router.Group("/auth")
	{
		auth.POST("/signup", authHandler.SignUp)
		auth.POST("/signin", authHandler.SignIn)
		auth.POST("/refresh", authHandler.RefreshToken)
		auth.POST("/signout", middleware.AuthRequired(jwtService), authHandler.SignOut)
		auth.GET("/verify-email/:token", authHandler.VerifyEmail)
		auth.POST("/reset-password", authHandler.RequestPasswordReset)
		auth.POST("/reset-password/:token", authHandler.ResetPassword)
	}

	return router
}
