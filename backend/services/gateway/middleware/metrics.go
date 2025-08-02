package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// Simple in-memory metrics (in production, use Prometheus)
type Metrics struct {
	RequestCount   map[string]int64
	ResponseTime   map[string][]time.Duration
	ErrorCount     map[string]int64
	ActiveRequests int64
}

var globalMetrics = &Metrics{
	RequestCount: make(map[string]int64),
	ResponseTime: make(map[string][]time.Duration),
	ErrorCount:   make(map[string]int64),
}

func MetricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		service := c.GetString("target_service")

		// Increment active requests
		globalMetrics.ActiveRequests++

		// Process request
		c.Next()

		// Record metrics
		latency := time.Since(start)
		statusCode := c.Writer.Status()

		key := service + ":" + c.Request.Method + ":" + c.Request.URL.Path

		globalMetrics.RequestCount[key]++
		globalMetrics.ResponseTime[key] = append(globalMetrics.ResponseTime[key], latency)

		if statusCode >= 400 {
			globalMetrics.ErrorCount[key]++
		}

		// Decrement active requests
		globalMetrics.ActiveRequests--

		// Add metrics headers
		c.Header("X-Response-Time", strconv.FormatInt(latency.Milliseconds(), 10)+"ms")
	}
}

func GetMetrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(200, globalMetrics)
	}
}
