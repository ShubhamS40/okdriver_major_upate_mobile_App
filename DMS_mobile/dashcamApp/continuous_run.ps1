# Continuous Flutter Run Script - Runs until APK installs successfully
$attempt = 0
$maxAttempts = 200
$success = $false

Write-Host "🚀 Starting continuous build and install process..." -ForegroundColor Cyan
Write-Host "Will retry until APK installs successfully (max $maxAttempts attempts)`n" -ForegroundColor Yellow

while (-not $success -and $attempt -lt $maxAttempts) {
    $attempt++
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] Attempt $attempt of $maxAttempts..." -ForegroundColor Yellow
    
    # Run flutter run and capture exit code
    flutter run --debug 2>&1 | Tee-Object -Variable output
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "`n✅✅✅ SUCCESS! APK installed and app is running! ✅✅✅" -ForegroundColor Green
        Write-Host "Build completed successfully after $attempt attempts" -ForegroundColor Green
        $success = $true
        break
    } else {
        Write-Host "`n❌ Build failed (Exit code: $exitCode)" -ForegroundColor Red
        
        # Check for specific errors
        $outputString = $output | Out-String
        if ($outputString -match "No file or variants found for asset") {
            Write-Host "⚠️  Missing asset file detected. Checking assets..." -ForegroundColor Yellow
            # Verify assets exist
            if (-not (Test-Path "assets/models/final_drowsiness_model.tflite")) {
                Write-Host "   Missing: assets/models/final_drowsiness_model.tflite" -ForegroundColor Red
            }
            if (-not (Test-Path "assets/sounds/alarm.wav")) {
                Write-Host "   Missing: assets/sounds/alarm.wav" -ForegroundColor Red
            }
        }
        
        Write-Host "Retrying in 5 seconds...`n" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

if (-not $success) {
    Write-Host "`n❌ Failed after $maxAttempts attempts" -ForegroundColor Red
    Write-Host "Please check the errors above and fix them manually." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n🎉 Process completed successfully!" -ForegroundColor Green
    exit 0
}

