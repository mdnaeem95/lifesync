# LifeSync Backend Services

This is the backend for the LifeSync ecosystem, currently containing the auth service for FlowTime.

## Structure

```
backend/
├── cmd/                    # Application entry points
│   └── auth-service/      # Auth service main
├── internal/              # Private application code
│   ├── config/           # Configuration
│   └── middleware/       # HTTP middleware
├── pkg/                   # Public packages
│   ├── database/         # Database utilities
│   └── logger/           # Logging package
├── services/              # Service implementations
│   └── auth/             # Auth service
│       ├── handlers/     # HTTP handlers
│       ├── services/     # Business logic
│       ├── repository/   # Data access
│       └── models/       # Data models
└── docker-compose.yaml    # Local development setup
```

## Getting Started

### Prerequisites
- Go 1.21+
- PostgreSQL 15+
- Docker & Docker Compose (optional)

### Local Development

1. Clone the repository
2. Copy `.env.example` to `.env` and configure
3. Start PostgreSQL (using Docker):
   ```bash
   make db-up
   ```
4. Run the auth service:
   ```bash
   make run-auth
   ```

### Using Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f auth-service

# Stop services
docker-compose down
```

### Testing

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Run specific service tests
go test ./services/auth/...
```

## API Documentation

See the individual service README files:
- [Auth Service](./services/auth/README.md)

## Development

### Adding a New Service

1. Create entry point in `cmd/<service-name>/`
2. Add service implementation in `services/<service-name>/`
3. Update docker-compose.yaml if needed
4. Add Makefile targets

### Code Style

- Follow standard Go conventions
- Use structured logging
- Add tests for new functionality
- Keep handlers thin, business logic in services

## Deployment

The services are designed to run in containers. Each service has its own Dockerfile.

### Building Images

```bash
# Build auth service
docker build -f services/auth/Dockerfile -t lifesync-auth-service .
```

### Environment Variables

See `.env.example` for all configuration options.

## License

[Your License]