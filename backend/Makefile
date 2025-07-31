.PHONY: all build test clean run-auth docker-build docker-up docker-down

# Default target
all: build

# Build auth service
build:
	@echo "Building auth service..."
	go build -o bin/auth-service ./cmd/auth-service

# Run auth service
run-auth:
	go run cmd/auth-service/main.go

# Run all tests
test:
	go test ./... -v

# Run tests with coverage
test-coverage:
	go test ./... -cover -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	rm -rf bin/
	rm -f coverage.out coverage.html

# Docker commands
docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

# Development with hot reload (requires air)
dev:
	air -c .air.toml

# Database operations
db-up:
	docker-compose up -d postgres

db-down:
	docker-compose stop postgres

db-migrate:
	go run cmd/migrate/main.go up

db-rollback:
	go run cmd/migrate/main.go down

# Lint all code
lint:
	golangci-lint run ./...

# Format all code
fmt:
	go fmt ./...

# Update dependencies
deps:
	go mod download
	go mod tidy

# Generate mocks (requires mockery)
mocks:
	mockery --dir=services/auth/services --name=AuthService --output=mocks
	mockery --dir=services/auth/repository --name=UserRepository --output=mocks

# backend/.air.toml
root = "."
tmp_dir = "tmp"

[build]
  cmd = "go build -o ./tmp/main ./cmd/auth-service"
  bin = "tmp/main"
  full_bin = "./tmp/main"
  include_ext = ["go", "tpl", "tmpl", "html"]
  exclude_dir = ["assets", "tmp", "vendor", "node_modules"]
  include_dir = []
  exclude_file = []
  log = "air.log"
  delay = 1000
  stop_on_error = true
  send_interrupt = false
  kill_delay = 500

[log]
  time = false

[color]
  main = "magenta"
  watcher = "cyan"
  build = "yellow"
  runner = "green"

[misc]
  clean_on_exit = true