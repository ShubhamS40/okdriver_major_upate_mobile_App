# Check Build Status and Install
$apk = "app\build\outputs\apk\debug\app-debug.apk"

Write-Host "`n🔍 Checking for APK..." -ForegroundColor Cyan

if (Test-Path $apk) {
    $apkInfo = Get-Item $apk
    Write-Host "`n✅ APK Found!" -ForegroundColor Green
    Write-Host "   Size: $([math]::Round($apkInfo.Length/1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "   Location: $($apkInfo.FullName)" -ForegroundColor Cyan
    
    Write-Host "`n📱 Installing on device..." -ForegroundColor Yellow
    adb install -r $apk
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅✅✅ INSTALLED! ✅✅✅" -ForegroundColor Green
        Write-Host "`n🚀 Launching app..." -ForegroundColor Cyan
        adb shell am start -n com.drowsiness.detector/.MainActivity
        Write-Host "`n✅✅✅ APP IS NOW RUNNING ON YOUR DEVICE! ✅✅✅" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Install failed. Uninstalling old version..." -ForegroundColor Yellow
        adb uninstall com.drowsiness.detector 2>&1 | Out-Null
        adb install $apk
        if ($LASTEXITCODE -eq 0) {
            adb shell am start -n com.drowsiness.detector/.MainActivity
            Write-Host "`n✅ App installed and launched!" -ForegroundColor Green
        }
    }
} else {
    Write-Host "`n❌ APK not found. Building now..." -ForegroundColor Yellow
    Write-Host "This will take 3-5 minutes. Please wait..." -ForegroundColor Cyan
    .\gradlew.bat assembleDebug --no-daemon
    
    if (Test-Path $apk) {
        Write-Host "`n✅ Build successful! Installing..." -ForegroundColor Green
        adb install -r $apk
        adb shell am start -n com.drowsiness.detector/.MainActivity
        Write-Host "`n✅ App is running!" -ForegroundColor Green
    } else {
        Write-Host "`n❌ Build failed. Please check errors above." -ForegroundColor Red
    }
}

