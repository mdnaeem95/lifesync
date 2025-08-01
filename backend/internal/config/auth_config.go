package config

import (
	"os"
	"strconv"
	"strings"
)

type AuthConfig struct {
	Environment        string
	Version            string
	Port               int
	DatabaseURL        string
	JWTSecret          string
	LogLevel           string
	RateLimitPerMinute int
	AllowedOrigins     []string

	// Email configuration (optional)
	SMTPHost     string
	SMTPPort     int
	SMTPUser     string
	SMTPPassword string
	FromEmail    string
}

func LoadAuthConfig() *AuthConfig {
	cfg := &AuthConfig{
		Environment:        getEnv("ENVIRONMENT", "development"),
		Version:            getEnv("SERVICE_VERSION", "1.0.0"),
		Port:               getEnvAsInt("AUTH_SERVICE_PORT", 8080),
		DatabaseURL:        getEnv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/lifesync?sslmode=disable"),
		JWTSecret:          getEnv("JWT_SECRET", "development-secret-key"),
		LogLevel:           getEnv("LOG_LEVEL", "info"),
		RateLimitPerMinute: getEnvAsInt("RATE_LIMIT_PER_MINUTE", 5),
		AllowedOrigins:     getEnvAsSlice("ALLOWED_ORIGINS", []string{"http://localhost:3000"}),

		// Email configuration
		SMTPHost:     getEnv("SMTP_HOST", ""),
		SMTPPort:     getEnvAsInt("SMTP_PORT", 587),
		SMTPUser:     getEnv("SMTP_USER", ""),
		SMTPPassword: getEnv("SMTP_PASSWORD", ""),
		FromEmail:    getEnv("FROM_EMAIL", "noreply@flowtime.app"),
	}

	return cfg
}

// GetSafeConfig returns config with sensitive values redacted
func (c *AuthConfig) GetSafeConfig() map[string]interface{} {
	return map[string]interface{}{
		"environment":     c.Environment,
		"version":         c.Version,
		"port":            c.Port,
		"database_url":    redactConnectionString(c.DatabaseURL),
		"jwt_secret":      redact(c.JWTSecret),
		"log_level":       c.LogLevel,
		"rate_limit":      c.RateLimitPerMinute,
		"allowed_origins": c.AllowedOrigins,
		"smtp_configured": c.SMTPHost != "",
	}
}

// Helper functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := getEnv(key, "")
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsSlice(key string, defaultValue []string) []string {
	valueStr := getEnv(key, "")
	if valueStr == "" {
		return defaultValue
	}
	return strings.Split(valueStr, ",")
}

func redact(value string) string {
	if len(value) == 0 {
		return ""
	}
	return "***"
}

func redactConnectionString(connStr string) string {
	// Simple redaction - in production, use more sophisticated parsing
	if strings.Contains(connStr, "@") {
		parts := strings.Split(connStr, "@")
		return "***@" + parts[len(parts)-1]
	}
	return redact(connStr)
}
