# Quick Setup Guide

## Step 1: Copy Model File

Copy the TensorFlow Lite model to the assets folder:

```bash
# From the parent directory (DMS_mobile)
copy final_drowsiness_model.tflite dashcamApp\assets\models\final_drowsiness_model.tflite
```

Or manually:
- Copy `final_drowsiness_model.tflite` from `DMS_mobile/` 
- Paste it into `dashcamApp/assets/models/`

## Step 2: Copy Alarm Sound (Optional)

```bash
# From the parent directory
copy alarm.wav dashcamApp\assets\sounds\alarm.wav
```

## Step 3: Install Dependencies

```bash
cd dashcamApp
flutter pub get
```

## Step 4: Build APK

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Step 5: Install on Device

```bash
flutter install
```

Or manually install the APK file on your Android device.

## Troubleshooting

If you get errors about missing packages, run:
```bash
flutter clean
flutter pub get
```

If the model doesn't load, verify:
- File exists at `assets/models/final_drowsiness_model.tflite`
- File is listed in `pubspec.yaml` under `assets:`

