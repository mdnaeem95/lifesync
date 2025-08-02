package discovery

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/mdnaeem95/lifesync/backend/internal/config"
	"github.com/mdnaeem95/lifesync/backend/pkg/logger"
)

type ServiceDiscovery interface {
	GetHealthyService(name string) (*config.ServiceConfig, error)
	GetServiceHealth(name string) (*config.ServiceHealth, error)
	GetAllServicesHealth() map[string]*config.ServiceHealth
	RegisterService(name string, config config.ServiceConfig)
	DeregisterService(name string)
	Start(ctx context.Context)
	Stop()
}

type serviceDiscovery struct {
	services       map[string]config.ServiceConfig
	health         map[string]*config.ServiceHealth
	mu             sync.RWMutex
	log            logger.Logger
	checkInterval  time.Duration
	httpClient     *http.Client
	stopChan       chan struct{}
	circuitBreaker map[string]*CircuitBreaker
}

func NewServiceDiscovery(log logger.Logger, checkInterval time.Duration) ServiceDiscovery {
	return &serviceDiscovery{
		services:      make(map[string]config.ServiceConfig),
		health:        make(map[string]*config.ServiceHealth),
		log:           log,
		checkInterval: checkInterval,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
		stopChan:       make(chan struct{}),
		circuitBreaker: make(map[string]*CircuitBreaker),
	}
}

func (sd *serviceDiscovery) GetHealthyService(name string) (*config.ServiceConfig, error) {
	sd.mu.RLock()
	defer sd.mu.RUnlock()

	service, exists := sd.services[name]
	if !exists {
		return nil, fmt.Errorf("service %s not found", name)
	}

	health, exists := sd.health[name]
	if !exists || health.Status != "healthy" {
		return nil, fmt.Errorf("service %s is not healthy", name)
	}

	// Check circuit breaker
	if cb, exists := sd.circuitBreaker[name]; exists && !cb.CanRequest() {
		return nil, fmt.Errorf("service %s circuit breaker is open", name)
	}

	return &service, nil
}

func (sd *serviceDiscovery) GetServiceHealth(name string) (*config.ServiceHealth, error) {
	sd.mu.RLock()
	defer sd.mu.RUnlock()

	health, exists := sd.health[name]
	if !exists {
		return nil, fmt.Errorf("health status for service %s not found", name)
	}

	return health, nil
}

func (sd *serviceDiscovery) GetAllServicesHealth() map[string]*config.ServiceHealth {
	sd.mu.RLock()
	defer sd.mu.RUnlock()

	healthCopy := make(map[string]*config.ServiceHealth)
	for k, v := range sd.health {
		healthCopy[k] = v
	}

	return healthCopy
}

func (sd *serviceDiscovery) RegisterService(name string, cfg config.ServiceConfig) {
	sd.mu.Lock()
	defer sd.mu.Unlock()

	sd.services[name] = cfg
	sd.circuitBreaker[name] = NewCircuitBreaker(3, 2, 30*time.Second)

	// Initialize health status
	sd.health[name] = &config.ServiceHealth{
		Name:        name,
		URL:         cfg.URL,
		Status:      "unknown",
		LastChecked: time.Now(),
	}

	sd.log.WithFields(map[string]interface{}{
		"service": name,
		"url":     cfg.URL,
	}).Info("Service registered")
}

func (sd *serviceDiscovery) DeregisterService(name string) {
	sd.mu.Lock()
	defer sd.mu.Unlock()

	delete(sd.services, name)
	delete(sd.health, name)
	delete(sd.circuitBreaker, name)

	sd.log.WithField("service", name).Info("Service deregistered")
}

func (sd *serviceDiscovery) Start(ctx context.Context) {
	ticker := time.NewTicker(sd.checkInterval)
	defer ticker.Stop()

	// Initial health check
	sd.checkAllServices()

	for {
		select {
		case <-ticker.C:
			sd.checkAllServices()
		case <-sd.stopChan:
			return
		case <-ctx.Done():
			return
		}
	}
}

func (sd *serviceDiscovery) Stop() {
	close(sd.stopChan)
}

func (sd *serviceDiscovery) checkAllServices() {
	sd.mu.RLock()
	services := make(map[string]config.ServiceConfig)
	for k, v := range sd.services {
		services[k] = v
	}
	sd.mu.RUnlock()

	var wg sync.WaitGroup
	for name, svc := range services {
		wg.Add(1)
		go func(n string, s config.ServiceConfig) {
			defer wg.Done()
			sd.checkServiceHealth(n, s)
		}(name, svc)
	}
	wg.Wait()
}

func (sd *serviceDiscovery) checkServiceHealth(name string, svc config.ServiceConfig) {
	start := time.Now()
	healthCheckURL := svc.URL + svc.HealthCheckPath

	resp, err := sd.httpClient.Get(healthCheckURL)
	responseTime := time.Since(start)

	health := &config.ServiceHealth{
		Name:         name,
		URL:          svc.URL,
		LastChecked:  time.Now(),
		ResponseTime: responseTime,
	}

	if err != nil {
		health.Status = "unhealthy"
		health.Error = err.Error()

		// Record failure in circuit breaker
		if cb, exists := sd.circuitBreaker[name]; exists {
			cb.RecordFailure()
		}
	} else {
		defer resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			health.Status = "healthy"

			// Record success in circuit breaker
			if cb, exists := sd.circuitBreaker[name]; exists {
				cb.RecordSuccess()
			}
		} else {
			health.Status = "unhealthy"
			health.Error = fmt.Sprintf("HTTP status %d", resp.StatusCode)

			// Record failure in circuit breaker
			if cb, exists := sd.circuitBreaker[name]; exists {
				cb.RecordFailure()
			}
		}
	}

	sd.mu.Lock()
	sd.health[name] = health
	sd.mu.Unlock()

	if health.Status != "healthy" {
		sd.log.WithFields(map[string]interface{}{
			"service": name,
			"status":  health.Status,
			"error":   health.Error,
		}).Warn("Service health check failed")
	}
}

// CircuitBreaker implementation
type CircuitBreaker struct {
	failureThreshold int
	successThreshold int
	timeout          time.Duration
	failures         int
	successes        int
	lastFailureTime  time.Time
	state            string // closed, open, half-open
	mu               sync.Mutex
}

func NewCircuitBreaker(failureThreshold, successThreshold int, timeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		failureThreshold: failureThreshold,
		successThreshold: successThreshold,
		timeout:          timeout,
		state:            "closed",
	}
}

func (cb *CircuitBreaker) CanRequest() bool {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case "closed":
		return true
	case "open":
		if time.Since(cb.lastFailureTime) > cb.timeout {
			cb.state = "half-open"
			cb.failures = 0
			cb.successes = 0
			return true
		}
		return false
	case "half-open":
		return true
	}
	return false
}

func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures = 0

	if cb.state == "half-open" {
		cb.successes++
		if cb.successes >= cb.successThreshold {
			cb.state = "closed"
		}
	}
}

func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures++
	cb.lastFailureTime = time.Now()

	if cb.failures >= cb.failureThreshold {
		cb.state = "open"
		cb.successes = 0
	}
}
