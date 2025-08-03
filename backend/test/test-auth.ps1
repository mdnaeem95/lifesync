$endpoints = @(
    "/signin",
    "/auth", 
    "/login",
    "/api/signin",
    "/api/auth/signin",
    "/api/v1/auth/signin",
    "/v1/auth/signin",
    "/auth/signin",
    "/users/signin",
    "/api/login",
    "/api/v1/login"
)

Write-Host "Testing Auth Service Endpoints..." -ForegroundColor Green

foreach ($endpoint in $endpoints) {
    Write-Host "`nTesting: $endpoint" -ForegroundColor Yellow
    docker exec backend-auth-service-1 curl -s -X POST "http://localhost:8080$endpoint" -H "Content-Type: application/json" -d '{\"username\":\"test\",\"password\":\"test\"}' -w "\nHTTP Status: %{http_code}"
}