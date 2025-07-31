package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/lifesync/flowtime/auth-service/pkg/logger"
)

func Recovery(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				log.WithContext(c.Request.Context()).
					WithField("error", err).
					WithField("path", c.Request.URL.Path).
					Error("Panic recovered")

				c.JSON(http.StatusInternalServerError, gin.H{
					"error": "Internal server error",
				})
				c.Abort()
			}
		}()
		c.Next()
	}
}
