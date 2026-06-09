# WaterGuard Backend Endpoint Tests
$baseUrl = "http://localhost:4000"
$token = $null

Write-Host "=== WaterGuard Backend Endpoint Tests ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Register User
Write-Host "[1] Testing POST /api/auth/register" -ForegroundColor Yellow
$registerBody = @{
    fullName = "Test User"
    email = "testuser@example.com"
    password = "TestPassword123"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-WebRequest -Uri "$baseUrl/api/auth/register" -Method Post -ContentType "application/json" -Body $registerBody -UseBasicParsing
    $registerData = $registerResponse.Content | ConvertFrom-Json
    Write-Host "✓ Registration successful (Status: $($registerResponse.StatusCode))" -ForegroundColor Green
    Write-Host "  User: $($registerData.user.fullName) <$($registerData.user.email)>"
}
catch {
    Write-Host "✗ Registration failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Login User
Write-Host "[2] Testing POST /api/auth/login" -ForegroundColor Yellow
$loginBody = @{
    email = "testuser@example.com"
    password = "TestPassword123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-WebRequest -Uri "$baseUrl/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody -UseBasicParsing
    $loginData = $loginResponse.Content | ConvertFrom-Json
    $token = $loginData.token
    Write-Host "✓ Login successful (Status: $($loginResponse.StatusCode))" -ForegroundColor Green
    Write-Host "  Token: $($token.Substring(0, 20))..."
}
catch {
    Write-Host "✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Get Current User
Write-Host "[3] Testing GET /api/auth/me" -ForegroundColor Yellow
if ($token) {
    try {
        $meResponse = Invoke-WebRequest -Uri "$baseUrl/api/auth/me" -Method Get -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing
        $meData = $meResponse.Content | ConvertFrom-Json
        Write-Host "✓ Get user successful (Status: $($meResponse.StatusCode))" -ForegroundColor Green
        Write-Host "  Authenticated as: $($meData.fullName) <$($meData.email)>"
    }
    catch {
        Write-Host "✗ Get user failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "⊘ Skipped: No authentication token available" -ForegroundColor Gray
}

Write-Host ""

# Test 4: Get Sensors
Write-Host "[4] Testing GET /api/sensors" -ForegroundColor Yellow
if ($token) {
    try {
        $sensorsResponse = Invoke-WebRequest -Uri "$baseUrl/api/sensors" -Method Get -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing
        $sensorsData = $sensorsResponse.Content | ConvertFrom-Json
        Write-Host "✓ Get sensors successful (Status: $($sensorsResponse.StatusCode))" -ForegroundColor Green
        Write-Host "  Sensors available: $($sensorsData.Count)"
        foreach ($sensor in $sensorsData | Select-Object -First 3) {
            Write-Host "    • $($sensor.name): $($sensor.value) $($sensor.unit) [$($sensor.status)]"
        }
    }
    catch {
        Write-Host "✗ Get sensors failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "⊘ Skipped: No authentication token available" -ForegroundColor Gray
}

Write-Host ""

# Test 5: Get Dashboard
Write-Host "[5] Testing GET /api/sensors/dashboard" -ForegroundColor Yellow
if ($token) {
    try {
        $dashboardResponse = Invoke-WebRequest -Uri "$baseUrl/api/sensors/dashboard" -Method Get -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing
        $dashboardData = $dashboardResponse.Content | ConvertFrom-Json
        Write-Host "✓ Get dashboard successful (Status: $($dashboardResponse.StatusCode))" -ForegroundColor Green
        Write-Host "  Quality Score: $($dashboardData.qualityScore)/100"
        Write-Host "  Quality Status: $($dashboardData.qualityStatus)"
        Write-Host "  Alerts: $($dashboardData.alertCount)"
    }
    catch {
        Write-Host "✗ Get dashboard failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "⊘ Skipped: No authentication token available" -ForegroundColor Gray
}

Write-Host ""

# Test 6: Update Sensor Value
Write-Host "[6] Testing PATCH /api/sensors/{id}/value" -ForegroundColor Yellow
if ($token) {
    $updateBody = @{
        value = 7.5
    } | ConvertTo-Json
    
    try {
        $updateResponse = Invoke-WebRequest -Uri "$baseUrl/api/sensors/ph-level/value" -Method Patch -ContentType "application/json" -Body $updateBody -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing
        $updateData = $updateResponse.Content | ConvertFrom-Json
        Write-Host "✓ Update sensor successful (Status: $($updateResponse.StatusCode))" -ForegroundColor Green
        Write-Host "  Updated: $($updateData.name) = $($updateData.value) $($updateData.unit)"
        Write-Host "  Status: $($updateData.status) | Trend: $($updateData.trend)"
    }
    catch {
        Write-Host "✗ Update sensor failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "⊘ Skipped: No authentication token available" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== All Tests Complete ===" -ForegroundColor Cyan
