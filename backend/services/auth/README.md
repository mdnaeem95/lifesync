# FlowTime Auth Service

## Overview
The Auth Service handles all authentication and authorization for the FlowTime application. It provides JWT-based authentication with refresh tokens, password reset functionality, and email verification.

## Features
- User registration and login
- JWT token generation and validation
- Refresh token rotation
- Password reset via email
- Email verification
- Rate limiting
- Comprehensive logging with correlation IDs

## API Endpoints

### Public Endpoints
- `POST /auth/signup` - Register a new user
- `POST /auth/signin` - Login with email/password
- `POST /auth/refresh` - Refresh access token
- `GET /auth/verify-email/:token` - Verify email address
- `POST /auth/reset-password` - Request password reset
- `POST /auth/reset-password/:token` - Reset password with token

### Protected Endpoints
- `POST /auth/signout` - Logout (requires auth)

## Running Locally

### Prerequisites
- Go 1.21+
- PostgreSQL 15+
- Docker (optional)

### Setup
1. Clone the repository
2. Copy `.env.example` to `.env` and configure
3. Install dependencies: `go mod download`
4. Run migrations: `go run cmd/migrate/main.go`
5. Start the service: `go run main.go`

### Using Docker
```bash
docker build -t flowtime-auth-service .
docker run -p 8080:8080 --env-file .env flowtime-auth-service
```

## Testing
```bash
# Run all tests
go test ./...

# Run with coverage
go test ./... -cover

# Run specific test
go test ./internal/services -run TestAuthService_SignUp
```

## Configuration
The service is configured via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| PORT | Server port | 8080 |
| DATABASE_URL | PostgreSQL connection string | - |
| JWT_SECRET | Secret for signing JWTs | - |
| LOG_LEVEL | Logging level (debug/info/warn/error) | info |
| RATE_LIMIT_PER_MINUTE | Auth endpoint rate limit | 5 |

## Logging
The service uses structured JSON logging with the following fields:
- `timestamp` - ISO 8601 timestamp
- `level` - Log level
- `message` - Log message
- `request_id` - Correlation ID for request tracing
- `user_id` - User ID (when authenticated)
- `service` - Always "auth-service"
- Additional context fields as needed

## Security Considerations
- Passwords are hashed using bcrypt with cost factor 12
- JWT access tokens expire after 1 hour
- Refresh tokens expire after 30 days
- Rate limiting on auth endpoints (5 requests/minute by default)
- CORS configuration for allowed origins
- Input validation on all endpoints
- SQL injection prevention via parameterized queries

## Database Schema
See `pkg/database/migrations.go` for the complete schema.

## Monitoring
The service exposes a health check endpoint at `GET /health` which returns:
```json
{
  "status": "healthy",
  "service": "auth-service",
  "version": "1.0.0"
}
```

## Future Improvements
- [ ] OAuth2 providers (Google, Apple)
- [ ] Two-factor authentication
- [ ] Account lockout after failed attempts
- [ ] Email service integration
- [ ] Metrics collection (Prometheus)
- [ ] Distributed tracing (OpenTelemetry)