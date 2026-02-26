# Implementation Notes

## Code Review of main.py

The `main.py` file implements a drowsiness detection system with the following key components:

### 1. **Model Loading**
- **TFLite Model**: `final_drowsiness_model.tflite` - CNN for drowsiness classification
- **Random Forest Model**: `drowsiness_ml_model.pkl` - Not used in Flutter (Python-only)
- **MediaPipe Face Mesh**: For face landmark detection

### 2. **Detection Logic**
- **Eye Aspect Ratio (EAR)**: Calculated from 6 eye landmarks per eye
- **Mouth Aspect Ratio (MAR)**: Calculated from 7 mouth landmarks
- **Thresholds**:
  - EAR < 0.25 → Drowsy
  - MAR > 0.5 → Yawning
- **Frame Smoothing**: 
  - 100 consecutive frames for drowsy detection
  - 20 consecutive frames for yawning detection

### 3. **CNN Prediction**
- Input: 64x64 RGB image, normalized (0-1)
- Output: Binary classification (Alert/Drowsy)

### 4. **Event Tracking**
- Counts drowsy events
- Triggers critical alert after 3 events
- Plays alarm sound when drowsy/yawning detected

## Flutter Implementation Mapping

### main.py → Flutter

| main.py Component | Flutter Equivalent | Location |
|-------------------|-------------------|----------|
| `tf.lite.Interpreter` | `tflite_flutter.Interpreter` | `lib/services/drowsiness_detector.dart` |
| `mediapipe.solutions.face_mesh` | `google_mlkit_face_detection.FaceDetector` | `lib/services/drowsiness_detector.dart` |
| `cv2.VideoCapture` | `camera.CameraController` | `lib/screens/camera_screen.dart` |
| `pygame.mixer` | `audioplayers.AudioPlayer` | `lib/screens/camera_screen.dart` |
| `eye_aspect_ratio()` | `_calculateEAR()` | `lib/services/drowsiness_detector.dart` |
| `mouth_aspect_ratio()` | `_calculateMAR()` | `lib/services/drowsiness_detector.dart` |
| Frame processing loop | `Timer.periodic()` | `lib/screens/camera_screen.dart` |

### Key Differences

1. **Face Detection**: 
   - Python: MediaPipe (468 landmarks)
   - Flutter: Google ML Kit (fewer landmarks, but sufficient for EAR/MAR)

2. **Image Processing**:
   - Python: OpenCV (cv2)
   - Flutter: `image` package

3. **Model Inference**:
   - Python: TensorFlow Lite Python API
   - Flutter: `tflite_flutter` package

4. **Random Forest Model**:
   - Not included in Flutter (requires Python/Scikit-learn)
   - Only CNN model is used

### Detection Flow

```
Camera Frame
    ↓
Face Detection (ML Kit)
    ↓
Extract Landmarks
    ↓
Calculate EAR & MAR
    ↓
Crop Face → 64x64 → Normalize
    ↓
TFLite Inference
    ↓
Combine: CNN + EAR + MAR
    ↓
Frame Counter Smoothing
    ↓
Decision: ALERT / YAWNING / DROWSY
    ↓
Trigger Alarm if needed
```

## Files Created

### Core Files
- `lib/main.dart` - App entry point
- `lib/screens/camera_screen.dart` - Main UI and camera handling
- `lib/services/drowsiness_detector.dart` - Detection logic
- `lib/utils/calculations.dart` - EAR/MAR utilities

### Configuration
- `pubspec.yaml` - Dependencies
- `android/app/build.gradle` - Android build config
- `android/app/src/main/AndroidManifest.xml` - Permissions
- `android/app/src/main/kotlin/.../MainActivity.kt` - Android entry

### Documentation
- `README.md` - Full documentation
- `SETUP.md` - Quick setup guide
- `IMPLEMENTATION_NOTES.md` - This file

## Next Steps

1. **Copy Model**: Place `final_drowsiness_model.tflite` in `assets/models/`
2. **Install Dependencies**: Run `flutter pub get`
3. **Test on Device**: Build and install APK
4. **Fine-tune**: Adjust thresholds if needed based on testing

## Notes

- The app works completely offline (no internet required)
- All processing happens on-device
- The Random Forest model from Python is not used (only TFLite CNN)
- Face landmark extraction may differ slightly from MediaPipe, but EAR/MAR calculations are adapted

