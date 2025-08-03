package proxy

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
	"github.com/mdnaeem95/lifesync/backend/services/gateway/discovery"
)

type ProxyHandler struct {
	serviceDiscovery discovery.ServiceDiscovery
	proxies          map[string]*httputil.ReverseProxy
	config           map[string]config.ServiceConfig
	log              logger.Logger
}

func NewProxyHandler(sd discovery.ServiceDiscovery, services map[string]config.ServiceConfig, log logger.Logger) *ProxyHandler {
	ph := &ProxyHandler{
		serviceDiscovery: sd,
		proxies:          make(map[string]*httputil.ReverseProxy),
		config:           services,
		log:              log,
	}

	// Initialize reverse proxies for each service
	for name, svc := range services {
		if err := ph.createProxy(name, svc); err != nil {
			log.WithError(err).WithField("service", name).Error("Failed to create proxy")
		}
	}

	return ph
}

func (ph *ProxyHandler) createProxy(name string, svc config.ServiceConfig) error {
	targetURL, err := url.Parse(svc.URL)
	if err != nil {
		return fmt.Errorf("invalid service URL: %w", err)
	}

	proxy := httputil.NewSingleHostReverseProxy(targetURL)

	// Customize the proxy
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)

		// Add custom headers
		req.Header.Set("X-Forwarded-Service", name)

		// Add request ID if present
		if requestID := req.Context().Value("request_id"); requestID != nil {
			req.Header.Set("X-Gateway-Request-ID", requestID.(string))
		}

		// Forward user information if available
		if userID := req.Context().Value("user_id"); userID != nil {
			req.Header.Set("X-User-ID", userID.(string))
		}
		if userEmail := req.Context().Value("user_email"); userEmail != nil {
			req.Header.Set("X-User-Email", userEmail.(string))
		}
	}

	// Custom error handler
	proxy.ErrorHandler = func(rw http.ResponseWriter, req *http.Request, err error) {
		logFields := map[string]interface{}{
			"service": name,
			"path":    req.URL.Path,
		}

		// Add request ID if present
		if requestID := req.Context().Value("request_id"); requestID != nil {
			logFields["request_id"] = requestID
		}

		ph.log.WithError(err).WithFields(logFields).Error("Proxy error")

		rw.WriteHeader(http.StatusBadGateway)
		rw.Write([]byte(`{"error": "Service temporarily unavailable"}`))
	}

	// Modify response
	proxy.ModifyResponse = func(resp *http.Response) error {
		// Add response headers
		resp.Header.Set("X-Gateway-Response", "true")
		resp.Header.Set("X-Service-Name", name)

		// Log response
		logFields := map[string]interface{}{
			"service":     name,
			"status_code": resp.StatusCode,
		}

		// Add request ID if present
		if requestID := resp.Request.Context().Value("request_id"); requestID != nil {
			logFields["request_id"] = requestID
		}

		ph.log.WithFields(logFields).Debug("Proxied response")

		return nil
	}

	ph.proxies[name] = proxy
	return nil
}

func (ph *ProxyHandler) HandleProxy(serviceName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		ph.log.WithFields(map[string]interface{}{
			"service": serviceName,
			"method":  c.Request.Method,
			"path":    c.Request.URL.Path,
		}).Debug("HandleProxy called")

		// Get healthy service
		service, err := ph.serviceDiscovery.GetHealthyService(serviceName)
		if err != nil {
			ph.log.WithError(err).WithField("service", serviceName).Error("No healthy service available")
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error":   "Service unavailable",
				"service": serviceName,
			})
			return
		}

		// Get the proxy
		proxy, exists := ph.proxies[serviceName]
		if !exists {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Proxy not configured for service",
			})
			return
		}

		// Find matching route
		route := ph.findMatchingRoute(service, c.Request.Method, c.Request.URL.Path)
		if route == nil {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Route not found",
			})
			return
		}

		// Store original path for logging
		originalPath := c.Request.URL.Path

		// Modify request path based on configuration
		if route.TargetPath != "" {
			// Use specific target path
			c.Request.URL.Path = route.TargetPath
		} else {
			// For flowtime service, don't strip the /api/v1 prefix since it expects it
			if serviceName == "flowtime" {
				// FlowTime expects /api/v1/* paths, so keep them as is
				c.Request.URL.Path = originalPath
			} else {
				// For other services (like auth), remove /api/v1 prefix
				pathWithoutPrefix := strings.TrimPrefix(originalPath, "/api/v1")

				if service.StripPrefix && route.PathPrefix != "" {
					c.Request.URL.Path = strings.TrimPrefix(pathWithoutPrefix, route.PathPrefix)
				} else {
					c.Request.URL.Path = pathWithoutPrefix
				}
			}
		}

		ph.log.WithFields(map[string]interface{}{
			"service":        serviceName,
			"original_path":  originalPath,
			"rewritten_path": c.Request.URL.Path,
		}).Debug("Path rewrite")

		// Set timeout for this specific request
		timeout := route.Timeout
		if timeout == 0 {
			timeout = service.Timeout
		}

		// Create new request with Gin context values
		ctx := c.Request.Context()

		// Copy Gin context values to request context
		if requestID, exists := c.Get("request_id"); exists {
			ctx = context.WithValue(ctx, "request_id", requestID)
		}
		if userID, exists := c.Get("user_id"); exists {
			ctx = context.WithValue(ctx, "user_id", userID)
		}
		if userEmail, exists := c.Get("user_email"); exists {
			ctx = context.WithValue(ctx, "user_email", userEmail)
		}

		// Apply timeout if configured
		if timeout > 0 {
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(ctx, timeout)
			defer cancel()
		}

		c.Request = c.Request.WithContext(ctx)

		// Add retry logic
		var lastErr error
		retryCount := service.RetryCount
		if retryCount == 0 {
			retryCount = 1
		}

		for i := 0; i < retryCount; i++ {
			if i > 0 {
				// Wait before retry
				time.Sleep(time.Duration(i) * 100 * time.Millisecond)
				ph.log.WithFields(map[string]interface{}{
					"service": serviceName,
					"attempt": i + 1,
				}).Debug("Retrying request")
			}

			// Create a response writer wrapper to capture the response
			writer := &responseWriter{
				ResponseWriter: c.Writer,
				statusCode:     http.StatusOK,
			}

			// Proxy the request
			proxy.ServeHTTP(writer, c.Request)

			// Check if we need to retry
			if writer.statusCode < 500 {
				// Success or client error, don't retry
				return
			}

			lastErr = fmt.Errorf("received status code %d", writer.statusCode)
		}

		// All retries failed
		ph.log.WithError(lastErr).WithField("service", serviceName).Error("All retries failed")
		c.JSON(http.StatusBadGateway, gin.H{
			"error": "Service request failed after retries",
		})
	}
}

func (ph *ProxyHandler) findMatchingRoute(service *config.ServiceConfig, method, path string) *config.RouteConfig {
	// Remove /api/v1 prefix for matching
	pathForMatching := strings.TrimPrefix(path, "/api/v1")

	for _, route := range service.Routes {
		// Check method
		if route.Method != "*" && route.Method != method {
			continue
		}

		// Check path prefix
		if strings.HasPrefix(pathForMatching, route.PathPrefix) {
			return &route
		}
	}
	return nil
}

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
