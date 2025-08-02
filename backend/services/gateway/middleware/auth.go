package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/auth/services"
)

func AuthMiddleware(cfg config.AuthGatewayConfig, jwtService services.JWTService, log logger.Logger) gin.HandlerFunc {
	// Build skip paths map for O(1) lookup
	skipPaths := make(map[string]bool)
	for _, path := range cfg.SkipPaths {
		skipPaths[path] = true
	}

	return func(c *gin.Context) {
		// Check if path should skip auth
		if shouldSkipAuth(c.Request.URL.Path, skipPaths) {
			c.Next()
			return
		}

		// Get token from header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		// Extract token
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization header format"})
			c.Abort()
			return
		}

		token := parts[1]

		// Validate token
		claims, err := jwtService.ValidateAccessToken(token)
		if err != nil {
			log.WithError(err).Debug("Token validation failed")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		// Store user info in context
		c.Set("user_id", claims.UserID)
		c.Set("user_email", claims.Email)
		c.Set("authenticated", true)

		c.Next()
	}
}

func shouldSkipAuth(path string, skipPaths map[string]bool) bool {
	// Exact match
	if skipPaths[path] {
		return true
	}

	// Prefix match for paths ending with /*
	for skipPath := range skipPaths {
		if strings.HasSuffix(skipPath, "/*") {
			prefix := strings.TrimSuffix(skipPath, "/*")
			if strings.HasPrefix(path, prefix) {
				return true
			}
		}
	}

	return false
}
