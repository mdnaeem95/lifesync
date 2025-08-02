package config

import (
	"time"
)

// GatewayConfig represents the main gateway configuration
type GatewayConfig struct {
	Port           int                      `yaml:"port" json:"port"`
	Environment    string                   `yaml:"environment" json:"environment"`
	LogLevel       string                   `yaml:"log_level" json:"log_level"`
	Services       map[string]ServiceConfig `yaml:"services" json:"services"`
	RateLimit      RateLimitConfig          `yaml:"rate_limit" json:"rate_limit"`
	Auth           AuthGatewayConfig        `yaml:"auth" json:"auth"`
	Timeouts       TimeoutConfig            `yaml:"timeouts" json:"timeouts"`
	CORS           CORSConfig               `yaml:"cors" json:"cors"`
	CircuitBreaker CircuitBreakerConfig     `yaml:"circuit_breaker" json:"circuit_breaker"`
}

// ServiceConfig represents configuration for a single service
type ServiceConfig struct {
	Name            string            `yaml:"name" json:"name"`
	URL             string            `yaml:"url" json:"url"`
	HealthCheckPath string            `yaml:"health_check_path" json:"health_check_path"`
	Timeout         time.Duration     `yaml:"timeout" json:"timeout"`
	RetryCount      int               `yaml:"retry_count" json:"retry_count"`
	Routes          []RouteConfig     `yaml:"routes" json:"routes"`
	StripPrefix     bool              `yaml:"strip_prefix" json:"strip_prefix"`
	RequiresAuth    bool              `yaml:"requires_auth" json:"requires_auth"`
	RateLimit       *RateLimitRule    `yaml:"rate_limit,omitempty" json:"rate_limit,omitempty"`
	LoadBalancing   LoadBalanceConfig `yaml:"load_balancing" json:"load_balancing"`
}

// RouteConfig represents a route mapping
type RouteConfig struct {
	Method       string         `yaml:"method" json:"method"` // GET, POST, etc. or * for all
	PathPrefix   string         `yaml:"path_prefix" json:"path_prefix"`
	TargetPath   string         `yaml:"target_path" json:"target_path"`
	RequiresAuth bool           `yaml:"requires_auth" json:"requires_auth"`
	RateLimit    *RateLimitRule `yaml:"rate_limit,omitempty" json:"rate_limit,omitempty"`
	Timeout      time.Duration  `yaml:"timeout,omitempty" json:"timeout,omitempty"`
	CacheConfig  *CacheConfig   `yaml:"cache,omitempty" json:"cache,omitempty"`
}

// RateLimitConfig represents rate limiting configuration
type RateLimitConfig struct {
	Enabled         bool          `yaml:"enabled" json:"enabled"`
	RequestsPerMin  int           `yaml:"requests_per_min" json:"requests_per_min"`
	BurstSize       int           `yaml:"burst_size" json:"burst_size"`
	ByIP            bool          `yaml:"by_ip" json:"by_ip"`
	ByUser          bool          `yaml:"by_user" json:"by_user"`
	Storage         string        `yaml:"storage" json:"storage"` // memory, redis
	RedisURL        string        `yaml:"redis_url,omitempty" json:"redis_url,omitempty"`
	CleanupInterval time.Duration `yaml:"cleanup_interval" json:"cleanup_interval"`
}

// RateLimitRule represents a specific rate limit rule
type RateLimitRule struct {
	RequestsPerMin int `yaml:"requests_per_min" json:"requests_per_min"`
	BurstSize      int `yaml:"burst_size" json:"burst_size"`
}

// AuthConfig represents authentication configuration
type AuthGatewayConfig struct {
	JWTSecret      string        `yaml:"jwt_secret" json:"jwt_secret"`
	SkipPaths      []string      `yaml:"skip_paths" json:"skip_paths"`
	AuthServiceURL string        `yaml:"auth_service_url" json:"auth_service_url"`
	CacheTokens    bool          `yaml:"cache_tokens" json:"cache_tokens"`
	TokenCacheTTL  time.Duration `yaml:"token_cache_ttl" json:"token_cache_ttl"`
}

// TimeoutConfig represents timeout settings
type TimeoutConfig struct {
	Default     time.Duration `yaml:"default" json:"default"`
	Read        time.Duration `yaml:"read" json:"read"`
	Write       time.Duration `yaml:"write" json:"write"`
	Idle        time.Duration `yaml:"idle" json:"idle"`
	Shutdown    time.Duration `yaml:"shutdown" json:"shutdown"`
	HealthCheck time.Duration `yaml:"health_check" json:"health_check"`
}

// CORSConfig represents CORS settings
type CORSConfig struct {
	AllowedOrigins   []string `yaml:"allowed_origins" json:"allowed_origins"`
	AllowedMethods   []string `yaml:"allowed_methods" json:"allowed_methods"`
	AllowedHeaders   []string `yaml:"allowed_headers" json:"allowed_headers"`
	ExposedHeaders   []string `yaml:"exposed_headers" json:"exposed_headers"`
	AllowCredentials bool     `yaml:"allow_credentials" json:"allow_credentials"`
	MaxAge           int      `yaml:"max_age" json:"max_age"`
}

// CircuitBreakerConfig represents circuit breaker settings
type CircuitBreakerConfig struct {
	Enabled               bool          `yaml:"enabled" json:"enabled"`
	FailureThreshold      int           `yaml:"failure_threshold" json:"failure_threshold"`
	SuccessThreshold      int           `yaml:"success_threshold" json:"success_threshold"`
	Timeout               time.Duration `yaml:"timeout" json:"timeout"`
	MaxConcurrentRequests int           `yaml:"max_concurrent_requests" json:"max_concurrent_requests"`
}

// LoadBalanceConfig represents load balancing configuration
type LoadBalanceConfig struct {
	Strategy string   `yaml:"strategy" json:"strategy"` // round-robin, random, least-conn
	Backends []string `yaml:"backends" json:"backends"`
}

// CacheConfig represents caching configuration for routes
type CacheConfig struct {
	Enabled bool          `yaml:"enabled" json:"enabled"`
	TTL     time.Duration `yaml:"ttl" json:"ttl"`
	MaxSize int           `yaml:"max_size" json:"max_size"`
}

// ServiceHealth represents the health status of a service
type ServiceHealth struct {
	Name         string        `json:"name"`
	URL          string        `json:"url"`
	Status       string        `json:"status"` // healthy, unhealthy, degraded
	LastChecked  time.Time     `json:"last_checked"`
	ResponseTime time.Duration `json:"response_time"`
	Error        string        `json:"error,omitempty"`
}
