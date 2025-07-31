package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
)

func Logger(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		// Process request
		c.Next()

		// Log request details
		latency := time.Since(start)
		clientIP := c.ClientIP()
		method := c.Request.Method
		statusCode := c.Writer.Status()
		errorMessage := c.Errors.ByType(gin.ErrorTypePrivate).String()

		if raw != "" {
			path = path + "?" + raw
		}

		fields := map[string]interface{}{
			"client_ip":   clientIP,
			"method":      method,
			"path":        path,
			"status_code": statusCode,
			"latency_ms":  latency.Milliseconds(),
			"user_agent":  c.Request.UserAgent(),
		}

		// Add request ID if available
		if requestID := c.GetString("request_id"); requestID != "" {
			fields["request_id"] = requestID
		}

		// Add user ID if authenticated
		if userID, exists := c.Get("user_id"); exists {
			fields["user_id"] = userID
		}

		// Log based on status code
		logEntry := log.WithFields(fields)

		if errorMessage != "" {
			logEntry = logEntry.WithField("error", errorMessage)
		}

		switch {
		case statusCode >= 500:
			logEntry.Error("Server error")
		case statusCode >= 400:
			logEntry.Warn("Client error")
		case statusCode >= 300:
			logEntry.Info("Redirection")
		default:
			logEntry.Info("Request completed")
		}
	}
}
