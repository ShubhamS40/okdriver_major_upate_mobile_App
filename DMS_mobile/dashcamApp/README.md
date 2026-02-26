# DashCam - Drowsiness Detection App

A Flutter mobile application for real-time drowsiness detection using TensorFlow Lite. This app works completely offline without any internet connection or backend server.

## Features

- ✅ **Offline Operation**: Runs entirely on-device, no internet required
- ✅ **Real-time Detection**: Uses camera feed for continuous monitoring
- ✅ **TensorFlow Lite Model**: Uses `final_drowsiness_model.tflite` for CNN-based predictions
- ✅ **Face Detection**: Google ML Kit for face and landmark detection
- ✅ **EAR/MAR Calculations**: Eye Aspect Ratio and Mouth Aspect Ratio for drowsiness detection
- ✅ **Alarm System**: Audio alerts when drowsiness is detected
- ✅ **Event Tracking**: Counts drowsy events and triggers critical alerts after 3 events

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Install Flutter (version 3.0.0 or higher)
   ```bash
   flutter --version
   ```

2. **Android Studio** or **VS Code** with Flutter extensions

3. **Android SDK**: For Android development (API level 21+)

### Installation Steps

1. **Copy Model File**:
   - Copy `final_drowsiness_model.tflite` from the parent directory to `dashcamApp/assets/models/`
   - Ensure the file is named exactly `final_drowsiness_model.tflite`

2. **Copy Alarm Sound** (Optional):
   - Copy `alarm.wav` from the parent directory to `dashcamApp/assets/sounds/`
   - If you don't have an alarm file, the app will work but won't play sounds

3. **Install Dependencies**:
   ```bash
   cd dashcamApp
   flutter pub get
   ```

4. **Build APK**:
   ```bash
   flutter build apk --release
   ```
   
   The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

5. **Install on Device**:
   ```bash
   flutter install
   ```
   Or manually install the APK file on your Android device.

## Project Structure

```
dashcamApp/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── screens/
│   │   └── camera_screen.dart    # Main camera and UI screen
│   ├── services/
│   │   └── drowsiness_detector.dart  # Core detection logic
│   └── utils/
│       └── calculations.dart     # EAR/MAR calculation utilities
├── assets/
│   ├── models/
│   │   └── final_drowsiness_model.tflite  # TFLite model (copy from parent)
│   └── sounds/
│       └── alarm.wav             # Alarm sound (optional)
├── android/                      # Android configuration
└── pubspec.yaml                  # Dependencies
```

## How It Works

The app replicates the logic from `main.py`:

1. **Camera Feed**: Captures frames from the front camera
2. **Face Detection**: Uses Google ML Kit to detect faces and extract landmarks
3. **Feature Extraction**: 
   - Calculates Eye Aspect Ratio (EAR) from eye landmarks
   - Calculates Mouth Aspect Ratio (MAR) from mouth landmarks
4. **CNN Prediction**: 
   - Crops and resizes face region to 64x64 pixels
   - Normalizes pixel values (0-1 range)
   - Runs inference using TensorFlow Lite model
5. **Decision Logic**:
   - Combines CNN predictions with EAR/MAR thresholds
   - Uses frame counters to smooth predictions (100 frames for drowsy, 20 for yawning)
   - Tracks drowsy events and triggers critical alert after 3 events
6. **Alerts**: Plays alarm sound when drowsiness is detected

## Detection Parameters

- **EAR Threshold**: 0.25 (Eye Aspect Ratio)
- **MAR Threshold**: 0.5 (Mouth Aspect Ratio)
- **Drowsy Frame Threshold**: 100 consecutive frames
- **Yawning Frame Threshold**: 20 consecutive frames
- **Critical Alert**: After 3 drowsy events

## Permissions Required

- **Camera**: For video feed
- **Storage** (optional): For saving detection logs

## Troubleshooting

### Model Not Loading
- Ensure `final_drowsiness_model.tflite` is in `assets/models/`
- Check that the file path in `pubspec.yaml` matches
- Run `flutter clean` and `flutter pub get`

### Camera Not Working
- Check camera permissions in device settings
- Ensure device has a front-facing camera
- Try restarting the app

### Build Errors
- Run `flutter clean`
- Delete `pubspec.lock` and run `flutter pub get`
- Ensure Flutter SDK is up to date

## Notes

- The app uses Google ML Kit for face detection instead of MediaPipe (which is Python-only)
- The Random Forest model (`drowsiness_ml_model.pkl`) is not included as it requires Python/Scikit-learn
- The app focuses on the TensorFlow Lite CNN model for predictions
- Face landmark extraction may differ slightly from MediaPipe, but EAR/MAR calculations are adapted accordingly

## License

This project is part of the DMS (Driver Monitoring System) mobile application.

