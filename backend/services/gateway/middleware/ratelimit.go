package middleware

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/gateway/ratelimit"
)

func RateLimitMiddleware(limiter ratelimit.RateLimiter, cfg config.RateLimitConfig, log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !cfg.Enabled {
			c.Next()
			return
		}

		// Generate rate limit key
		var key string
		if cfg.ByUser && c.GetBool("authenticated") {
			// Rate limit by user ID if authenticated
			userID := c.GetString("user_id")
			key = fmt.Sprintf("user:%s:%s", userID, c.Request.URL.Path)
		} else if cfg.ByIP {
			// Rate limit by IP
			clientIP := c.ClientIP()
			key = fmt.Sprintf("ip:%s:%s", clientIP, c.Request.URL.Path)
		} else {
			// Global rate limit
			key = fmt.Sprintf("global:%s", c.Request.URL.Path)
		}

		// Check rate limit
		if !limiter.AllowDefault(key) {
			log.WithFields(map[string]interface{}{
				"key":        key,
				"path":       c.Request.URL.Path,
				"request_id": c.GetString("request_id"),
			}).Warn("Rate limit exceeded")

			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "Rate limit exceeded",
				"retry_after": "60",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
