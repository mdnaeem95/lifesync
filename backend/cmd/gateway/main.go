// File: services/gateway/cmd/main.go
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/internal/middleware"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/auth/services"
	"github.com/mdnaeem95/lifesync/backend/services/gateway/discovery"
	gatewayMiddleware "github.com/mdnaeem95/lifesync/backend/services/gateway/middleware"
	"github.com/mdnaeem95/lifesync/backend/services/gateway/proxy"
	"github.com/mdnaeem95/lifesync/backend/services/gateway/ratelimit"
)

func main() {
	// Initialize logger
	log := logger.New()
	log.Info("Starting API Gateway")

	// Load configuration
	cfg := loadConfig()
	log.WithField("config", cfg).Info("Configuration loaded")

	// Initialize service discovery
	serviceDiscovery := discovery.NewServiceDiscovery(log, 30*time.Second)

	// Register services
	for name, svc := range cfg.Services {
		serviceDiscovery.RegisterService(name, svc)
	}

	// Start service discovery
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go serviceDiscovery.Start(ctx)

	// Initialize rate limiter
	rateLimiter, err := ratelimit.NewRateLimiter(cfg.RateLimit, log)
	if err != nil {
		log.WithError(err).Fatal("Failed to create rate limiter")
	}

	// Initialize JWT service for auth validation
	jwtService := services.NewJWTService(cfg.Auth.JWTSecret, log)

	// Initialize proxy handler
	proxyHandler := proxy.NewProxyHandler(serviceDiscovery, cfg.Services, log)

	// Setup router
	router := setupRouter(cfg, serviceDiscovery, proxyHandler, rateLimiter, jwtService, log)

	// Create server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      router,
		ReadTimeout:  cfg.Timeouts.Read,
		WriteTimeout: cfg.Timeouts.Write,
		IdleTimeout:  cfg.Timeouts.Idle,
	}

	// Start server in goroutine
	go func() {
		log.WithField("port", cfg.Port).Info("Starting API Gateway server")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.WithError(err).Fatal("Failed to start server")
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down server...")

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), cfg.Timeouts.Shutdown)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.WithError(err).Error("Server forced to shutdown")
	}

	log.Info("Server exited")
}

func setupRouter(
	cfg config.GatewayConfig,
	sd discovery.ServiceDiscovery,
	proxyHandler *proxy.ProxyHandler,
	rateLimiter ratelimit.RateLimiter,
	jwtService services.JWTService,
	log logger.Logger,
) *gin.Engine {
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Global middleware
	router.Use(middleware.Recovery(log))
	router.Use(middleware.RequestID())
	router.Use(gatewayMiddleware.LoggingMiddleware(log))
	router.Use(middleware.CORS(cfg.CORS.AllowedOrigins))
	router.Use(gatewayMiddleware.MetricsMiddleware())
	router.Use(gatewayMiddleware.RateLimitMiddleware(rateLimiter, cfg.RateLimit, log))

	// Health check endpoint
	router.GET("/health", handleHealth(sd))

	// Metrics endpoint
	router.GET("/metrics", gatewayMiddleware.GetMetrics())

	// API routes
	api := router.Group("/api/v1")

	// Apply auth middleware to API routes
	api.Use(gatewayMiddleware.AuthMiddleware(cfg.Auth, jwtService, log))

	// Setup service routes
	setupServiceRoutes(api, cfg.Services, proxyHandler, rateLimiter, log)

	return router
}

func setupServiceRoutes(
	group *gin.RouterGroup,
	services map[string]config.ServiceConfig,
	proxyHandler *proxy.ProxyHandler,
	rateLimiter ratelimit.RateLimiter,
	log logger.Logger,
) {
	// Create a catch-all handler that determines the service from the path
	group.Any("/*path", func(c *gin.Context) {
		path := c.Param("path")
		fullPath := "/api/v1" + path

		// Find which service should handle this request
		var targetService string
		var targetRoute *config.RouteConfig

		for name, svc := range services {
			for _, route := range svc.Routes {
				// Check if this route matches
				pathForMatching := strings.TrimPrefix(fullPath, "/api/v1")
				if strings.HasPrefix(pathForMatching, route.PathPrefix) {
					if route.Method == "*" || route.Method == c.Request.Method {
						targetService = name
						targetRoute = &route
						break
					}
				}
			}
			if targetService != "" {
				break
			}
		}

		if targetService == "" {
			c.JSON(http.StatusNotFound, gin.H{"error": "No service found for path"})
			return
		}

		// Set target service
		c.Set("target_service", targetService)

		// Apply route-specific rate limit if configured
		if targetRoute.RateLimit != nil {
			key := fmt.Sprintf("%s:%s:%s", c.ClientIP(), targetService, fullPath)
			if !rateLimiter.Allow(key, targetRoute.RateLimit) {
				c.JSON(http.StatusTooManyRequests, gin.H{
					"error": "Rate limit exceeded",
				})
				return
			}
		}

		// Fix the request path to include the full path
		c.Request.URL.Path = fullPath

		// Proxy the request
		proxyHandler.HandleProxy(targetService)(c)
	})
}

func handleHealth(sd discovery.ServiceDiscovery) gin.HandlerFunc {
	return func(c *gin.Context) {
		health := sd.GetAllServicesHealth()

		overallStatus := "healthy"
		unhealthyCount := 0

		for _, h := range health {
			if h.Status != "healthy" {
				unhealthyCount++
			}
		}

		if unhealthyCount > 0 {
			overallStatus = "degraded"
		}
		if unhealthyCount == len(health) {
			overallStatus = "unhealthy"
		}

		statusCode := http.StatusOK
		if overallStatus == "unhealthy" {
			statusCode = http.StatusServiceUnavailable
		}

		c.JSON(statusCode, gin.H{
			"status":    overallStatus,
			"services":  health,
			"timestamp": time.Now(),
		})
	}
}

func loadConfig() config.GatewayConfig {
	// In production, load from file or environment
	// For now, return hardcoded config
	return config.GatewayConfig{
		Port:        8000,
		Environment: getEnv("ENVIRONMENT", "development"),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
		Services: map[string]config.ServiceConfig{
			"auth": {
				Name:            "auth",
				URL:             getEnv("AUTH_SERVICE_URL", "http://auth-service:8080"),
				HealthCheckPath: "/health",
				Timeout:         5 * time.Second,
				RetryCount:      2,
				StripPrefix:     false,
				RequiresAuth:    false,
				Routes: []config.RouteConfig{
					{
						Method:       "*",
						PathPrefix:   "/auth",
						TargetPath:   "",
						RequiresAuth: false,
					},
				},
			},
			"flowtime": {
				Name:            "flowtime",
				URL:             getEnv("FLOWTIME_SERVICE_URL", "http://flowtime-service:8081"),
				HealthCheckPath: "/health",
				Timeout:         5 * time.Second,
				RetryCount:      2,
				StripPrefix:     false,
				RequiresAuth:    true,
				Routes: []config.RouteConfig{
					{Method: "*", PathPrefix: "/tasks", RequiresAuth: true},
					{Method: "*", PathPrefix: "/energy", RequiresAuth: true},
					{Method: "*", PathPrefix: "/sessions", RequiresAuth: true},
					{Method: "*", PathPrefix: "/schedule", RequiresAuth: true},
					{Method: "*", PathPrefix: "/stats", RequiresAuth: true},
					{Method: "*", PathPrefix: "/preferences", RequiresAuth: true},
				},
			},
		},
		RateLimit: config.RateLimitConfig{
			Enabled:         true,
			RequestsPerMin:  60,
			BurstSize:       10,
			ByIP:            true,
			ByUser:          true,
			Storage:         "memory",
			CleanupInterval: 5 * time.Minute,
		},
		Auth: config.AuthGatewayConfig{
			JWTSecret: getEnv("JWT_SECRET", "development-secret-key"),
			SkipPaths: []string{
				"/health",
				"/metrics",
				"/api/v1/auth/signin",
				"/api/v1/auth/signup",
				"/api/v1/auth/refresh",
			},
		},
		Timeouts: config.TimeoutConfig{
			Default:     30 * time.Second,
			Read:        15 * time.Second,
			Write:       15 * time.Second,
			Idle:        60 * time.Second,
			Shutdown:    30 * time.Second,
			HealthCheck: 5 * time.Second,
		},
		CORS: config.CORSConfig{
			AllowedOrigins:   []string{"http://localhost:3000", "http://localhost:8080"},
			AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
			AllowedHeaders:   []string{"Origin", "Content-Type", "Accept", "Authorization"},
			ExposedHeaders:   []string{"Content-Length", "X-Request-ID"},
			AllowCredentials: true,
			MaxAge:           12 * 3600,
		},
		CircuitBreaker: config.CircuitBreakerConfig{
			Enabled:               true,
			FailureThreshold:      3,
			SuccessThreshold:      2,
			Timeout:               30 * time.Second,
			MaxConcurrentRequests: 100,
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
