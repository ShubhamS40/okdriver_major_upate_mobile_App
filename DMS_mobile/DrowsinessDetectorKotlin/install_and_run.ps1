# Install and Run Script
Write-Host "`n🚀 Installing and Running Drowsiness Detector App" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$apk = "app\build\outputs\apk\debug\app-debug.apk"

# Check if APK exists
if (-not (Test-Path $apk)) {
    Write-Host "`n❌ APK not found. Building first..." -ForegroundColor Red
    Write-Host "This may take a few minutes..." -ForegroundColor Yellow
    .\gradlew.bat assembleDebug --no-daemon
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Build failed!" -ForegroundColor Red
        exit 1
    }
}

if (Test-Path $apk) {
    $apkSize = [math]::Round((Get-Item $apk).Length/1MB, 2)
    Write-Host "`n✅ APK Found!" -ForegroundColor Green
    Write-Host "   Size: $apkSize MB" -ForegroundColor Cyan
    Write-Host "   Location: $((Get-Item $apk).FullName)" -ForegroundColor Cyan
    
    # Check device
    Write-Host "`n📱 Checking device connection..." -ForegroundColor Yellow
    $devices = adb devices
    if ($devices -match "device$") {
        Write-Host "✅ Device connected" -ForegroundColor Green
        
        # Install APK
        Write-Host "`n📦 Installing APK..." -ForegroundColor Yellow
        adb install -r $apk
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅✅✅ APK INSTALLED SUCCESSFULLY! ✅✅✅" -ForegroundColor Green
            
            # Launch app
            Write-Host "`n🚀 Launching app..." -ForegroundColor Cyan
            adb shell am start -n com.drowsiness.detector/.MainActivity
            
            Write-Host "`n✅✅✅ APP IS NOW RUNNING ON YOUR DEVICE! ✅✅✅" -ForegroundColor Green
            Write-Host "`nThe app should open automatically on your phone." -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️  Installation failed. Trying to uninstall old version first..." -ForegroundColor Yellow
            adb uninstall com.drowsiness.detector 2>&1 | Out-Null
            adb install $apk
            if ($LASTEXITCODE -eq 0) {
                adb shell am start -n com.drowsiness.detector/.MainActivity
                Write-Host "`n✅ App installed and launched!" -ForegroundColor Green
            } else {
                Write-Host "`n❌ Installation failed. Please check device connection." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n❌ No device connected. Please connect your device via USB and enable USB debugging." -ForegroundColor Red
        Write-Host "   Run 'adb devices' to verify connection." -ForegroundColor Yellow
    }
} else {
    Write-Host "`n❌ APK not found after build. Build may have failed." -ForegroundColor Red
    exit 1
}

