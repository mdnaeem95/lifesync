# File: test-flowtime-service.ps1
# PowerShell script to test all FlowTime endpoints

$baseAuthUrl = "http://localhost:8080"
$baseFlowUrl = "http://localhost:8081"

Write-Host "Testing FlowTime Service Endpoints" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Step 1: Authenticate
Write-Host "`n1. Authenticating..." -ForegroundColor Yellow
try {
    $authResponse = Invoke-RestMethod -Uri "$baseAuthUrl/auth/signin" `
        -Method POST `
        -Headers @{"Content-Type"="application/json"} `
        -Body '{"email":"test@example.com","password":"password123"}'
    
    $token = $authResponse.access_token
    Write-Host "[OK] Authentication successful" -ForegroundColor Green
} catch {
    Write-Host "[ERR] Authentication failed: $_" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Content-Type"="application/json"
    "Authorization"="Bearer $token"
}

# Step 2: Test Task Endpoints
Write-Host "`n2. Testing Task Endpoints..." -ForegroundColor Yellow

# Create a task
Write-Host "   - Creating task..."
try {
    $task = Invoke-RestMethod -Uri "$baseFlowUrl/api/tasks" `
        -Method POST `
        -Headers $headers `
        -Body '{
            "title":"Test Task",
            "duration":60,
            "task_type":"focus",
            "energy_required":3,
            "priority":4,
            "is_flexible":true
        }'
    Write-Host "   [OK] Task created: $($task.id)" -ForegroundColor Green
    $taskId = $task.id
} catch {
    Write-Host "   [ERR] Failed to create task: $_" -ForegroundColor Red
}

# Get all tasks
Write-Host "   - Getting all tasks..."
try {
    $tasks = Invoke-RestMethod -Uri "$baseFlowUrl/api/tasks" `
        -Method GET `
        -Headers $headers
    Write-Host "   [OK] Retrieved $($tasks.tasks.Count) tasks" -ForegroundColor Green
} catch {
    Write-Host "   [ERR] Failed to get tasks: $_" -ForegroundColor Red
}

# Step 3: Test Energy Endpoints
Write-Host "`n3. Testing Energy Endpoints..." -ForegroundColor Yellow

# Record energy level
Write-Host "   - Recording energy level..."
try {
    Invoke-RestMethod -Uri "$baseFlowUrl/api/energy" `
        -Method POST `
        -Headers $headers `
        -Body '{
            "level":75,
            "source":"manual"
        }'
    Write-Host "   [OK] Energy level recorded" -ForegroundColor Green
} catch {
    Write-Host "   [ERR] Failed to record energy: $_" -ForegroundColor Red
}

# Get current energy
Write-Host "   - Getting current energy..."
try {
    $energy = Invoke-RestMethod -Uri "$baseFlowUrl/api/energy/current" `
        -Method GET `
        -Headers $headers
    Write-Host "   [OK] Current energy: $($energy.energy.level)" -ForegroundColor Green
} catch {
    Write-Host "   [ERR] Failed to get current energy: $_" -ForegroundColor Red
}

# Step 4: Test Session Endpoints
Write-Host "`n4. Testing Session Endpoints..." -ForegroundColor Yellow

# Start a session
Write-Host "   - Starting focus session..."
try {
    $session = Invoke-RestMethod -Uri "$baseFlowUrl/api/sessions/start" `
        -Method POST `
        -Headers $headers `
        -Body '{
            "session_type":"pomodoro",
            "duration":25
        }'
    Write-Host "   [OK] Session started: $($session.id)" -ForegroundColor Green
    $sessionId = $session.id
} catch {
    Write-Host "   [ERR] Failed to start session: $_" -ForegroundColor Red
}

# Step 5: Test Schedule Endpoints
Write-Host "`n5. Testing Schedule Endpoints..." -ForegroundColor Yellow

# Get today's schedule
Write-Host "   - Getting today's schedule..."
try {
    $schedule = Invoke-RestMethod -Uri "$baseFlowUrl/api/schedule/today" `
        -Method GET `
        -Headers $headers
    Write-Host "   [OK] Today's schedule retrieved" -ForegroundColor Green
} catch {
    Write-Host "   [ERR] Failed to get schedule: $_" -ForegroundColor Red
}

# Step 6: Test Stats Endpoints
Write-Host "`n6. Testing Stats Endpoints..." -ForegroundColor Yellow

# Get daily stats
Write-Host "   - Getting daily stats..."
try {
    $stats = Invoke-RestMethod -Uri "$baseFlowUrl/api/stats/daily" `
        -Method GET `
        -Headers $headers
    Write-Host "   [OK] Daily stats retrieved" -ForegroundColor Green
} catch {
    Write-Host "   [ERR] Failed to get stats: $_" -ForegroundColor Red
}

# Step 7: Test Preferences
Write-Host "`n7. Testing Preferences..." -ForegroundColor Yellow

# Get preferences
Write-Host "   - Getting user preferences..."
try {
    $prefs = Invoke-RestMethod -Uri "$baseFlowUrl/api/preferences" `
        -Method GET `
        -Headers $headers
    Write-Host "   [OK] Preferences retrieved" -ForegroundColor Green
} catch {
    Write-Host "   [ERR] Failed to get preferences: $_" -ForegroundColor Red
}

Write-Host "`n=================================" -ForegroundColor Green
Write-Host "Test Summary Complete!" -ForegroundColor Green