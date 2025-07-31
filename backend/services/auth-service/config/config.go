package config

import (
	"os"
	"strconv"
)

type Config struct {
	// Server
	Port        int
	Environment string
	Version     string

	// Database
	DatabaseURL string

	// JWT
	JWTSecret string

	// CORS
	AllowedOrigins []string

	// Rate Limiting
	RateLimitPerMinute int

	// Email (for future use)
	SMTPHost     string
	SMTPPort     int
	SMTPUser     string
	SMTPPassword string
	FromEmail    string
}

func Load() *Config {
	return &Config{
		Port:        getEnvAsInt("PORT", 8080),
		Environment: getEnv("ENVIRONMENT", "development"),
		Version:     getEnv("SERVICE_VERSION", "1.0.0"),

		DatabaseURL: getEnv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/lifesync?sslmode=disable"),
		JWTSecret:   getEnv("JWT_SECRET", "your-secret-key-change-in-production"),

		AllowedOrigins: []string{
			"http://localhost:3000",
			"http://localhost:8080",
			"http://localhost:50000",
			"http://localhost:50001",
			"http://localhost:50002",
			"http://localhost:50003",
			"http://localhost:50004",
			"http://localhost:50005",
		},

		RateLimitPerMinute: getEnvAsInt("RATE_LIMIT_PER_MINUTE", 5),

		SMTPHost:     getEnv("SMTP_HOST", ""),
		SMTPPort:     getEnvAsInt("SMTP_PORT", 587),
		SMTPUser:     getEnv("SMTP_USER", ""),
		SMTPPassword: getEnv("SMTP_PASSWORD", ""),
		FromEmail:    getEnv("FROM_EMAIL", "noreply@flowtime.app"),
	}
}

func (c *Config) GetSafeConfig() map[string]interface{} {
	return map[string]interface{}{
		"port":            c.Port,
		"environment":     c.Environment,
		"version":         c.Version,
		"allowed_origins": c.AllowedOrigins,
		"rate_limit":      c.RateLimitPerMinute,
		"smtp_configured": c.SMTPHost != "",
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
