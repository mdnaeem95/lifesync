$gatewayUrl = "http://localhost:8000"

Write-Host "Testing API Gateway" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

# Test 1: Health Check
Write-Host "`n1. Testing Health Check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$gatewayUrl/health" -Method GET
    Write-Host "[OK] Gateway Status: $($health.status)" -ForegroundColor Green
    
    foreach ($service in $health.services.PSObject.Properties) {
        $status = $service.Value.status
        $color = if ($status -eq "healthy") { "Green" } else { "Red" }
        Write-Host "  - $($service.Name): $status" -ForegroundColor $color
    }
} catch {
    Write-Host "[ERR] Health check failed: $_" -ForegroundColor Red
}

# Test 2: Auth Service through Gateway (No Auth Required)
Write-Host "`n2. Testing Auth Service (Sign Up)..." -ForegroundColor Yellow
try {
    $signupBody = @{
        email = "gateway-test-$(Get-Random)@example.com"
        password = "password123"
        name = "Gateway Test User"
    } | ConvertTo-Json

    $signup = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/auth/signup" `
        -Method POST `
        -ContentType "application/json" `
        -Body $signupBody
    
    Write-Host "[OK] Sign up successful" -ForegroundColor Green
    $token = $signup.access_token
} catch {
    Write-Host "[ERR] Sign up failed: $_" -ForegroundColor Red
}

# Test 3: Sign In through Gateway
Write-Host "`n3. Testing Sign In..." -ForegroundColor Yellow
try {
    $signinBody = @{
        email = "test@example.com"
        password = "password123"
    } | ConvertTo-Json

    $signin = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/auth/signin" `
        -Method POST `
        -ContentType "application/json" `
        -Body $signinBody
    
    Write-Host "[OK] Sign in successful" -ForegroundColor Green
    $token = $signin.access_token
} catch {
    Write-Host "[ERR] Sign in failed: $_" -ForegroundColor Red
}

# Test 4: Protected Endpoint (Tasks) - Should Require Auth
Write-Host "`n4. Testing Protected Endpoint without Auth..." -ForegroundColor Yellow
try {
    $tasks = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/tasks" -Method GET
    Write-Host "✗ Should have been rejected!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "[OK] Correctly rejected unauthorized request" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Unexpected error: $_" -ForegroundColor Red
    }
}

# Test 5: Protected Endpoint with Auth
Write-Host "`n5. Testing Protected Endpoint with Auth..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $token"
    }
    
    $tasks = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/tasks" `
        -Method GET `
        -Headers $headers
    
    Write-Host "[OK] Successfully accessed protected endpoint" -ForegroundColor Green
    Write-Host "  Tasks count: $($tasks.tasks.Count)" -ForegroundColor Gray
} catch {
    Write-Host "[ERR] Failed to access protected endpoint: $_" -ForegroundColor Red
}

# Test 6: Create Task through Gateway
Write-Host "`n6. Testing Task Creation through Gateway..." -ForegroundColor Yellow
try {
    $taskBody = @{
        title = "Gateway Test Task"
        duration = 30
        task_type = "focus"
        energy_required = 3
        priority = 3
        is_flexible = $true
    } | ConvertTo-Json

    $task = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/tasks" `
        -Method POST `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $taskBody
    
    Write-Host "[OK] Task created successfully" -ForegroundColor Green
    Write-Host "  Task ID: $($task.id)" -ForegroundColor Gray
} catch {
    Write-Host "[ERR] Failed to create task: $_" -ForegroundColor Red
}

# Test 7: Rate Limiting
Write-Host "`n7. Testing Rate Limiting..." -ForegroundColor Yellow
try {
    # Make multiple rapid requests
    $rateLimitHit = $false
    for ($i = 1; $i -le 15; $i++) {
        try {
            $response = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/tasks" `
                -Method GET `
                -Headers $headers
            Write-Host "  Request ${i}: OK" -ForegroundColor Gray -NoNewline
            Write-Host ""
        } catch {
            if ($_.Exception.Response.StatusCode -eq 429) {
                Write-Host "  Request ${i}: Rate limited" -ForegroundColor Yellow
                $rateLimitHit = $true
            } else {
                throw $_
            }
        }
        Start-Sleep -Milliseconds 100
    }
    
    if ($rateLimitHit) {
        Write-Host "[OK] Rate limiting is working" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Rate limit not hit (might have high limit)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERR] Rate limit test failed: $_" -ForegroundColor Red
}

# Test 8: Service Routing
Write-Host "`n8. Testing Service Routing..." -ForegroundColor Yellow
$endpoints = @(
    @{Path="/api/v1/energy/current"; Method="GET"},
    @{Path="/api/v1/sessions/active"; Method="GET"},
    @{Path="/api/v1/schedule/today"; Method="GET"},
    @{Path="/api/v1/stats/daily"; Method="GET"},
    @{Path="/api/v1/preferences"; Method="GET"}
)

$successCount = 0
foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-RestMethod -Uri "$gatewayUrl$($endpoint.Path)" `
            -Method $endpoint.Method `
            -Headers $headers
        Write-Host "  [OK] $($endpoint.Path)" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  [ERR] $($endpoint.Path): $_" -ForegroundColor Red
    }
}

Write-Host "Routed successfully: $successCount/$($endpoints.Count) endpoints" -ForegroundColor $(if ($successCount -eq $endpoints.Count) { "Green" } else { "Yellow" })

# Test 9: Metrics Endpoint
Write-Host "`n9. Testing Metrics..." -ForegroundColor Yellow
try {
    $metrics = Invoke-RestMethod -Uri "$gatewayUrl/metrics" -Method GET
    Write-Host "[OK] Metrics endpoint accessible" -ForegroundColor Green
    Write-Host "  Active requests: $($metrics.ActiveRequests)" -ForegroundColor Gray
    Write-Host "  Total endpoints tracked: $($metrics.RequestCount.Count)" -ForegroundColor Gray
} catch {
    Write-Host "[ERR] Metrics test failed: $($_ | Out-String)" -ForegroundColor Red
}

# Test 10: Invalid Service Request
Write-Host "`n10. Testing Invalid Service Request..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$gatewayUrl/api/v1/nonexistent/endpoint" `
        -Method GET `
        -Headers $headers
    Write-Host "[ERR] Should have returned 404!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "[OK] Correctly returned 404 for invalid route" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Unexpected error: $_" -ForegroundColor Red
    }
}

Write-Host "`n==================" -ForegroundColor Green
Write-Host "Gateway Test Complete!" -ForegroundColor Green