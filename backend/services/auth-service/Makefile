.PHONY: build run test clean docker-build docker-run

# Build the application
build:
	go build -o bin/auth-service .

# Run the application
run:
	go run main.go

# Run tests
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

# Build Docker image
docker-build:
	docker build -t flowtime-auth-service:latest .

# Run Docker container
docker-run:
	docker run -p 8080:8080 --env-file .env flowtime-auth-service:latest

# Run linter
lint:
	golangci-lint run

# Format code
fmt:
	go fmt ./...

# Download dependencies
deps:
	go mod download
	go mod tidy

# Generate mocks
mocks:
	mockery --all --output=mocks

# Run database migrations
migrate:
	go run cmd/migrate/main.go

# Development with hot reload
dev:
	air