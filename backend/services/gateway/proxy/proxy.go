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

		// Add custom headers (defensive)
		req.Header.Set("X-Forwarded-Service", name)

		// Safely inject request_id
		if v := req.Context().Value("request_id"); v != nil {
			if reqID, ok := v.(string); ok && reqID != "" {
				req.Header.Set("X-Gateway-Request-ID", reqID)
			}
		}

		// Forward user information if available (defensive)
		if userID := req.Context().Value("user_id"); userID != nil {
			if s, ok := userID.(string); ok && s != "" {
				req.Header.Set("X-User-ID", s)
			}
		}
		if userEmail := req.Context().Value("user_email"); userEmail != nil {
			if s, ok := userEmail.(string); ok && s != "" {
				req.Header.Set("X-User-Email", s)
			}
		}
	}

	// Custom error handler
	proxy.ErrorHandler = func(rw http.ResponseWriter, req *http.Request, err error) {
		ph.log.WithError(err).WithFields(map[string]interface{}{
			"service":    name,
			"path":       req.URL.Path,
			"request_id": req.Context().Value("request_id"),
		}).Error("Proxy error")

		rw.WriteHeader(http.StatusBadGateway)
		rw.Write([]byte(`{"error": "Service temporarily unavailable"}`))
	}

	// Modify response
	proxy.ModifyResponse = func(resp *http.Response) error {
		// Add response headers
		resp.Header.Set("X-Gateway-Response", "true")
		resp.Header.Set("X-Service-Name", name)

		// Log response
		ph.log.WithFields(map[string]interface{}{
			"service":     name,
			"status_code": resp.StatusCode,
			"request_id":  resp.Request.Context().Value("request_id"),
		}).Debug("Proxied response")

		return nil
	}

	ph.proxies[name] = proxy
	return nil
}

func (ph *ProxyHandler) HandleProxy(serviceName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get healthy service instance
		service, err := ph.serviceDiscovery.GetHealthyService(serviceName)
		if err != nil {
			ph.log.WithError(err).WithField("service", serviceName).Error("No healthy service available")
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error":   "Service unavailable",
				"service": serviceName,
			})
			return
		}

		// Get the reverse proxy
		proxy, exists := ph.proxies[serviceName]
		if !exists {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Proxy not configured for service",
			})
			return
		}

		// Debug: Print what is being matched
		fmt.Printf("[DEBUG] HandleProxy: service=%s, method=%s, path=%s\n", serviceName, c.Request.Method, c.Request.URL.Path)

		// Find matching route in config
		route := ph.findMatchingRoute(service, c.Request.Method, c.Request.URL.Path)
		if route == nil {
			fmt.Printf("[DEBUG] No matching route for service=%s, method=%s, path=%s\n", serviceName, c.Request.Method, c.Request.URL.Path)
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Route not found",
			})
			return
		}

		fmt.Printf("[DEBUG] Matched route: %+v\n", *route)

		// Manipulate the request path if needed
		originalPath := c.Request.URL.Path
		if route.TargetPath != "" {
			// Swap the matching PathPrefix with TargetPath (only the prefix)
			c.Request.URL.Path = strings.Replace(c.Request.URL.Path, route.PathPrefix, route.TargetPath, 1)
		} else if service.StripPrefix {
			// Remove the PathPrefix from the request path
			c.Request.URL.Path = strings.TrimPrefix(c.Request.URL.Path, route.PathPrefix)
		}
		fmt.Printf("[DEBUG] Path rewrite: %s => %s\n", originalPath, c.Request.URL.Path)

		// Set timeout for this request (if configured)
		timeout := route.Timeout
		if timeout == 0 {
			timeout = service.Timeout
		}
		if timeout > 0 {
			ctx, cancel := context.WithTimeout(c.Request.Context(), timeout)
			defer cancel()
			c.Request = c.Request.WithContext(ctx)
		}

		// Add retry logic (if configured)
		retryCount := service.RetryCount
		if retryCount <= 0 {
			retryCount = 1
		}
		var lastErr error
		for i := 0; i < retryCount; i++ {
			if i > 0 {
				time.Sleep(time.Duration(i) * 100 * time.Millisecond)
				ph.log.WithFields(map[string]interface{}{
					"service": serviceName,
					"attempt": i + 1,
				}).Debug("Retrying request")
			}

			writer := &responseWriter{
				ResponseWriter: c.Writer,
				statusCode:     http.StatusOK,
			}

			// Actually proxy the request!
			proxy.ServeHTTP(writer, c.Request)

			// If we didn't get a 5xx, stop retrying
			if writer.statusCode < 500 {
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
	// Always strip the /api/v1 prefix if present
	const apiPrefix = "/api/v1"
	if strings.HasPrefix(path, apiPrefix) {
		path = strings.TrimPrefix(path, apiPrefix)
		// Make sure path still starts with '/' after trim
		if !strings.HasPrefix(path, "/") && len(path) > 0 {
			path = "/" + path
		}
	}
	for _, route := range service.Routes {
		// Check method
		if route.Method != "*" && route.Method != method {
			continue
		}
		// Check path prefix
		if strings.HasPrefix(path, route.PathPrefix) {
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
