# Kotlin Drowsiness Detector - Build Instructions

## Quick Build & Install

### Step 1: Copy Model File
```powershell
# From the parent DMS_mobile directory:
Copy-Item .\final_drowsiness_model.tflite .\DrowsinessDetectorKotlin\app\src\main\assets\models\final_drowsiness_model.tflite
```

### Step 2: Copy Alarm Sound (Optional)
```powershell
# Create raw directory if it doesn't exist
New-Item -ItemType Directory -Path .\DrowsinessDetectorKotlin\app\src\main\res\raw -Force

# Copy alarm file
Copy-Item .\alarm.wav .\DrowsinessDetectorKotlin\app\src\main\res\raw\alarm.wav
```

### Step 3: Build APK
```powershell
cd DrowsinessDetectorKotlin
.\gradlew.bat assembleDebug
```

### Step 4: Install APK
```powershell
# APK will be at:
# app\build\outputs\apk\debug\app-debug.apk

# Install via ADB:
adb install app\build\outputs\apk\debug\app-debug.apk

# Or install manually by copying APK to phone
```

## Features

✅ **Pure Kotlin/Android** - No Flutter dependencies
✅ **TensorFlow Lite** - Runs final_drowsiness_model.tflite
✅ **ML Kit Face Detection** - Google's face detection
✅ **CameraX** - Modern camera API
✅ **Offline Operation** - No internet required
✅ **Same Logic as main.py** - EAR/MAR calculations, frame smoothing

## Project Structure

```
DrowsinessDetectorKotlin/
├── app/
│   ├── src/main/
│   │   ├── java/com/drowsiness/detector/
│   │   │   └── MainActivity.kt (Main app code)
│   │   ├── res/
│   │   │   ├── layout/activity_main.xml
│   │   │   ├── values/ (strings, colors, themes)
│   │   │   └── raw/alarm.wav (alarm sound)
│   │   └── assets/models/
│   │       └── final_drowsiness_model.tflite
│   └── build.gradle
├── build.gradle
└── settings.gradle
```

## Requirements

- Android Studio or Android SDK
- JDK 8 or higher
- Android device/emulator with API 24+

## Troubleshooting

If gradlew.bat doesn't exist, download Gradle wrapper:
```powershell
# Download gradle wrapper jar
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.4/gradle/wrapper/gradle-wrapper.jar" -OutFile "gradle\wrapper\gradle-wrapper.jar"
```

Then run:
```powershell
.\gradlew.bat assembleDebug
```

