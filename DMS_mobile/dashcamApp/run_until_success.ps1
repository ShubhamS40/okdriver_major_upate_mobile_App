# Script to run flutter run until it succeeds
$maxAttempts = 100
$attempt = 0
$success = $false

while (-not $success -and $attempt -lt $maxAttempts) {
    $attempt++
    Write-Host "Attempt $attempt of $maxAttempts..." -ForegroundColor Yellow
    
    # Run flutter run and capture output
    $output = flutter run 2>&1 | Out-String
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ BUILD SUCCESSFUL! APK installed!" -ForegroundColor Green
        $success = $true
        break
    } else {
        Write-Host "❌ Build failed. Error code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Retrying in 10 seconds...`n" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
}

if (-not $success) {
    Write-Host "`n❌ Failed after $maxAttempts attempts" -ForegroundColor Red
    exit 1
}

exit 0

