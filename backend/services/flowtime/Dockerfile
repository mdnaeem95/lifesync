FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/flowtime-service

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates curl bash postgresql-client

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/main .

# Copy wait-for-it.sh
COPY wait-for-it.sh /usr/local/bin/wait-for-it.sh
RUN chmod +x /usr/local/bin/wait-for-it.sh

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8081/health || exit 1

CMD ["sh", "-c", "wait-for-it.sh postgres:5432 --timeout=30 -- && until pg_isready -h postgres -p 5432; do echo waiting for postgres; sleep 2; done; ./main"]