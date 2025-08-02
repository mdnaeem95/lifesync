package middleware

import (
	"bytes"
	"io"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
)

type bodyLogWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w bodyLogWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

func LoggingMiddleware(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		// Log request body for debugging (be careful with sensitive data)
		var requestBody []byte
		if c.Request.Body != nil {
			requestBody, _ = io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(requestBody))
		}

		// Create custom response writer to capture response
		blw := &bodyLogWriter{body: bytes.NewBufferString(""), ResponseWriter: c.Writer}
		c.Writer = blw

		// Process request
		c.Next()

		// Log details
		latency := time.Since(start)
		clientIP := c.ClientIP()
		method := c.Request.Method
		statusCode := c.Writer.Status()

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
			"request_id":  c.GetString("request_id"),
			"service":     c.GetString("target_service"),
		}

		// Add user info if authenticated
		if userID := c.GetString("user_id"); userID != "" {
			fields["user_id"] = userID
		}

		// Log based on status code
		logEntry := log.WithFields(fields)

		switch {
		case statusCode >= 500:
			logEntry.Error("Gateway request failed")
		case statusCode >= 400:
			logEntry.Warn("Gateway request client error")
		default:
			logEntry.Info("Gateway request completed")
		}
	}
}
