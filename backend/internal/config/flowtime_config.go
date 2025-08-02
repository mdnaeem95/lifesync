package config

type FlowTimeConfig struct {
	Environment    string
	Version        string
	Port           int
	DatabaseURL    string
	JWTSecret      string
	LogLevel       string
	AllowedOrigins []string
}

func LoadFlowTimeConfig() *FlowTimeConfig {
	cfg := &FlowTimeConfig{
		Environment:    getEnv("ENVIRONMENT", "development"),
		Version:        getEnv("SERVICE_VERSION", "1.0.0"),
		Port:           getEnvAsInt("FLOWTIME_SERVICE_PORT", 8081),
		DatabaseURL:    getEnv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/lifesync?sslmode=disable"),
		JWTSecret:      getEnv("JWT_SECRET", "development-secret-key"),
		LogLevel:       getEnv("LOG_LEVEL", "info"),
		AllowedOrigins: getEnvAsSlice("ALLOWED_ORIGINS", []string{"http://localhost:3000"}),
	}

	return cfg
}

// GetSafeConfig returns config with sensitive values redacted
func (c *FlowTimeConfig) GetSafeConfig() map[string]interface{} {
	return map[string]interface{}{
		"environment":     c.Environment,
		"version":         c.Version,
		"port":            c.Port,
		"database_url":    redactConnectionString(c.DatabaseURL),
		"jwt_secret":      redact(c.JWTSecret),
		"log_level":       c.LogLevel,
		"allowed_origins": c.AllowedOrigins,
	}
}
