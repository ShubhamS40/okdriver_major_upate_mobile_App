# Automated Build and Install Script
Write-Host "🚀 Building Kotlin Drowsiness Detector APK..." -ForegroundColor Cyan

# Step 1: Copy model file
Write-Host "`n[1/4] Copying model file..." -ForegroundColor Yellow
$modelSource = "..\final_drowsiness_model.tflite"
$modelDest = "app\src\main\assets\models\final_drowsiness_model.tflite"

if (Test-Path $modelSource) {
    Copy-Item $modelSource $modelDest -Force
    Write-Host "✅ Model file copied" -ForegroundColor Green
} else {
    Write-Host "⚠️  Model file not found at $modelSource" -ForegroundColor Yellow
    Write-Host "   Please copy final_drowsiness_model.tflite manually" -ForegroundColor Yellow
}

# Step 2: Copy alarm file
Write-Host "`n[2/4] Copying alarm file..." -ForegroundColor Yellow
$alarmSource = "..\alarm.wav"
$alarmDest = "app\src\main\res\raw\alarm.wav"

if (-not (Test-Path "app\src\main\res\raw")) {
    New-Item -ItemType Directory -Path "app\src\main\res\raw" -Force | Out-Null
}

if (Test-Path $alarmSource) {
    Copy-Item $alarmSource $alarmDest -Force
    Write-Host "✅ Alarm file copied" -ForegroundColor Green
} else {
    Write-Host "⚠️  Alarm file not found (optional)" -ForegroundColor Yellow
}

# Step 3: Build APK
Write-Host "`n[3/4] Building APK..." -ForegroundColor Yellow
if (Test-Path "gradlew.bat") {
    .\gradlew.bat assembleDebug
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build successful!" -ForegroundColor Green
    } else {
        Write-Host "❌ Build failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ gradlew.bat not found. Please run from Android Studio or install Gradle wrapper" -ForegroundColor Red
    exit 1
}

# Step 4: Install APK
Write-Host "`n[4/4] Installing APK..." -ForegroundColor Yellow
$apkPath = "app\build\outputs\apk\debug\app-debug.apk"

if (Test-Path $apkPath) {
    Write-Host "✅ APK found: $apkPath" -ForegroundColor Green
    Write-Host "   Size: $([math]::Round((Get-Item $apkPath).Length / 1MB, 2)) MB" -ForegroundColor Green
    
    # Try to install via ADB
    $adbResult = adb devices 2>&1
    if ($adbResult -match "device") {
        Write-Host "`n📱 Device detected. Installing..." -ForegroundColor Cyan
        adb install -r $apkPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅✅✅ APK INSTALLED SUCCESSFULLY! ✅✅✅" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️  Installation failed. You can install manually:" -ForegroundColor Yellow
            Write-Host "   Copy $apkPath to your phone and install" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n⚠️  No device connected. APK ready for manual install:" -ForegroundColor Yellow
        Write-Host "   Location: $((Get-Item $apkPath).FullName)" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ APK not found at $apkPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Process completed!" -ForegroundColor Green

