package ratelimit

import (
	"fmt"
	"sync"
	"time"

	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
)

type RateLimiter interface {
	Allow(key string, rule *config.RateLimitRule) bool
	AllowDefault(key string) bool
	Cleanup()
}

type TokenBucket struct {
	tokens         float64
	maxTokens      float64
	refillRate     float64
	lastRefillTime time.Time
}

type memoryRateLimiter struct {
	buckets         map[string]*TokenBucket
	mu              sync.Mutex
	defaultRule     config.RateLimitRule
	cleanupInterval time.Duration
	log             logger.Logger
	stopChan        chan struct{}
}

func NewMemoryRateLimiter(cfg config.RateLimitConfig, log logger.Logger) RateLimiter {
	rl := &memoryRateLimiter{
		buckets: make(map[string]*TokenBucket),
		defaultRule: config.RateLimitRule{
			RequestsPerMin: cfg.RequestsPerMin,
			BurstSize:      cfg.BurstSize,
		},
		cleanupInterval: cfg.CleanupInterval,
		log:             log,
		stopChan:        make(chan struct{}),
	}

	// Start cleanup goroutine
	go rl.cleanupRoutine()

	return rl
}

func (rl *memoryRateLimiter) Allow(key string, rule *config.RateLimitRule) bool {
	if rule == nil {
		return rl.AllowDefault(key)
	}

	rl.mu.Lock()
	defer rl.mu.Unlock()

	bucket, exists := rl.buckets[key]
	now := time.Now()

	if !exists {
		// Create new bucket
		bucket = &TokenBucket{
			tokens:         float64(rule.BurstSize),
			maxTokens:      float64(rule.BurstSize),
			refillRate:     float64(rule.RequestsPerMin) / 60.0,
			lastRefillTime: now,
		}
		rl.buckets[key] = bucket
	} else {
		// Refill tokens based on time elapsed
		elapsed := now.Sub(bucket.lastRefillTime).Seconds()
		tokensToAdd := elapsed * bucket.refillRate
		bucket.tokens = min(bucket.tokens+tokensToAdd, bucket.maxTokens)
		bucket.lastRefillTime = now
	}

	// Check if request is allowed
	if bucket.tokens >= 1 {
		bucket.tokens--
		return true
	}

	rl.log.WithFields(map[string]interface{}{
		"key":   key,
		"limit": rule.RequestsPerMin,
	}).Debug("Rate limit exceeded")

	return false
}

func (rl *memoryRateLimiter) AllowDefault(key string) bool {
	return rl.Allow(key, &rl.defaultRule)
}

func (rl *memoryRateLimiter) Cleanup() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	for key, bucket := range rl.buckets {
		// Remove buckets that haven't been used in 10 minutes
		if now.Sub(bucket.lastRefillTime) > 10*time.Minute {
			delete(rl.buckets, key)
		}
	}
}

func (rl *memoryRateLimiter) cleanupRoutine() {
	ticker := time.NewTicker(rl.cleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			rl.Cleanup()
		case <-rl.stopChan:
			return
		}
	}
}

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

// RedisRateLimiter for distributed rate limiting (optional)
type redisRateLimiter struct {
	// Redis implementation would go here
	// Using Lua scripts for atomic operations
}

// Factory function to create appropriate rate limiter
func NewRateLimiter(cfg config.RateLimitConfig, log logger.Logger) (RateLimiter, error) {
	switch cfg.Storage {
	case "memory":
		return NewMemoryRateLimiter(cfg, log), nil
	case "redis":
		// TODO: Implement Redis rate limiter
		return nil, fmt.Errorf("redis rate limiter not implemented yet")
	default:
		return NewMemoryRateLimiter(cfg, log), nil
	}
}
