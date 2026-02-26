# Drowsiness Detector - Kotlin Android App

Complete Kotlin/Android implementation of the drowsiness detection system from `main.py`.

## ✅ Features

- **Pure Kotlin/Android** - No Flutter, works directly on Android
- **TensorFlow Lite** - Runs `final_drowsiness_model.tflite` offline
- **ML Kit Face Detection** - Google's face detection API
- **CameraX** - Modern Android camera API
- **Same Logic as main.py**:
  - EAR (Eye Aspect Ratio) calculation
  - MAR (Mouth Aspect Ratio) calculation  
  - Frame smoothing (100 frames for drowsy, 20 for yawning)
  - Event tracking and critical alerts
  - Alarm sound playback

## 🚀 Quick Start

### Option 1: Automated Build Script
```powershell
cd DrowsinessDetectorKotlin
.\build_and_install.ps1
```

### Option 2: Manual Build

1. **Copy Model File:**
   ```powershell
   Copy-Item ..\final_drowsiness_model.tflite app\src\main\assets\models\
   ```

2. **Copy Alarm (Optional):**
   ```powershell
   Copy-Item ..\alarm.wav app\src\main\res\raw\
   ```

3. **Build APK:**
   ```powershell
   .\gradlew.bat assembleDebug
   ```

4. **Install:**
   ```powershell
   adb install app\build\outputs\apk\debug\app-debug.apk
   ```

## 📁 Project Structure

```
DrowsinessDetectorKotlin/
├── app/
│   ├── src/main/
│   │   ├── java/com/drowsiness/detector/
│   │   │   └── MainActivity.kt          # Main app logic
│   │   ├── res/
│   │   │   ├── layout/
│   │   │   │   └── activity_main.xml     # UI layout
│   │   │   ├── values/
│   │   │   │   ├── strings.xml
│   │   │   │   ├── colors.xml
│   │   │   │   └── themes.xml
│   │   │   └── raw/
│   │   │       └── alarm.wav            # Alarm sound
│   │   └── assets/models/
│   │       └── final_drowsiness_model.tflite
│   └── build.gradle
├── build.gradle
├── settings.gradle
└── build_and_install.ps1
```

## 🔧 Requirements

- Android SDK (API 24+)
- JDK 8 or higher
- Gradle 8.4
- Android device/emulator

## 📱 Usage

1. Launch the app
2. Grant camera permission
3. Click "Start Detection"
4. App will detect drowsiness in real-time
5. Alarm sounds when drowsy detected
6. Status shows: ALERT / YAWNING / DROWSY

## 🎯 Detection Parameters

- **EAR Threshold**: 0.25
- **MAR Threshold**: 0.5
- **Drowsy Frames**: 100 consecutive frames
- **Yawning Frames**: 20 consecutive frames
- **Critical Alert**: After 3 drowsy events

## 📝 Notes

- Works completely offline
- No internet connection required
- Same detection logic as Python version
- Optimized for mobile performance

