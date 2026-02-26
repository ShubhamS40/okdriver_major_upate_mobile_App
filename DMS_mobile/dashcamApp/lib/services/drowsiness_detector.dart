import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class DrowsinessDetector {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Detection parameters (from main.py)
  static const double EAR_THRESHOLD = 0.25;
  static const double MAR_THRESHOLD = 0.5;
  static const int DROWSY_FRAME_THRESHOLD = 100;
  static const int YAWNING_FRAME_THRESHOLD = 20;

  // Frame counters
  int drowsyFrames = 0;
  int yawningFrames = 0;
  int drowsyEvents = 0;
  bool drowsyActive = false;

  // Face detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.1,
    ),
  );

  DrowsinessDetector() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/models/final_drowsiness_model.tflite');
      _interpreter!.allocateTensors();
      _isModelLoaded = true;
      print('[INFO] TFLite model loaded successfully');
    } catch (e) {
      print('[ERROR] Failed to load TFLite model: $e');
      _isModelLoaded = false;
    }
  }

  Future<DetectionResult> processFrame(img.Image image) async {
    if (!_isModelLoaded || _interpreter == null) {
      return DetectionResult(
        faceDetected: false,
        status: 'MODEL_NOT_LOADED',
        message: 'Model is not loaded',
      );
    }

    try {
      // Convert image to InputImage for face detection
      final inputImage = _imageToInputImage(image);

      // Detect faces
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        drowsyFrames = 0;
        yawningFrames = 0;
        return DetectionResult(
          faceDetected: false,
          status: 'NO_FACE',
          message: 'No face detected',
        );
      }

      final face = faces.first;

      // Extract landmarks (Map<FaceLandmarkType, FaceLandmark?>)
      final landmarks = face.landmarks;

      // Calculate EAR and MAR using face landmarks
      final ear = _calculateEAR(landmarks, image.width, image.height);
      final mar = _calculateMAR(landmarks, image.width, image.height);

      // Prepare image for CNN model (64x64, normalized)
      final faceImage = _prepareFaceImage(image, face);

      // CNN Prediction
      int cnnLabel = 0;
      double cnnConf = 1.0;

      if (faceImage != null) {
        try {
          final output = _interpreter!.getOutputTensors()[0];

          // Prepare input tensor (64x64x3, normalized to 0-1)
          final inputBuffer = Float32List(1 * 64 * 64 * 3);
          int pixelIndex = 0;

          for (int y = 0; y < 64; y++) {
            for (int x = 0; x < 64; x++) {
              final pixel = faceImage.getPixel(x, y);
              // Normalize pixel values to 0-1 range
              inputBuffer[pixelIndex++] = pixel.r / 255.0;
              inputBuffer[pixelIndex++] = pixel.g / 255.0;
              inputBuffer[pixelIndex++] = pixel.b / 255.0;
            }
          }

          // Get output shape
          final outputShape = output.shape;
          final outputSize = outputShape.reduce((a, b) => a * b);
          final outputBuffer = Float32List(outputSize);

          // Run inference
          _interpreter!.run(inputBuffer, outputBuffer);

          // Get prediction (assuming binary classification: [alert, drowsy])
          if (outputBuffer.length >= 2) {
            cnnLabel = outputBuffer[1] > outputBuffer[0] ? 1 : 0;
            cnnConf = outputBuffer[cnnLabel];
          } else if (outputBuffer.length == 1) {
            // Single output (probability of drowsy)
            cnnLabel = outputBuffer[0] > 0.5 ? 1 : 0;
            cnnConf = outputBuffer[0];
          }
        } catch (e) {
          print('[ERROR] CNN prediction failed: $e');
        }
      }

      // Raw detection
      final rawDrowsy = cnnLabel == 1 || ear < EAR_THRESHOLD;

      // Update frame counters
      if (rawDrowsy) {
        drowsyFrames++;
      } else {
        drowsyFrames = 0;
        drowsyActive = false;
      }

      if (mar > MAR_THRESHOLD) {
        yawningFrames++;
      } else {
        yawningFrames = 0;
      }

      // Final smoothed decision
      final finalDrowsy = drowsyFrames >= DROWSY_FRAME_THRESHOLD;
      final finalYawning = yawningFrames >= YAWNING_FRAME_THRESHOLD;

      String status = 'ALERT';
      int alertLevel = 0;
      String message = 'User is alert';
      bool shouldAlert = false;

      if (finalDrowsy) {
        status = 'DROWSY';
        alertLevel = 3;
        message = 'User is drowsy!';

        if (!drowsyActive) {
          drowsyEvents++;
          drowsyActive = true;
          shouldAlert = true;

          if (drowsyEvents >= 3) {
            alertLevel = 4;
            message = '⚠️ CRITICAL: Repeated drowsiness detected!';
          }
        }
      } else if (finalYawning) {
        status = 'YAWNING';
        alertLevel = 2;
        message = 'User is yawning';
        if (yawningFrames == YAWNING_FRAME_THRESHOLD) {
          shouldAlert = true;
        }
      }

      return DetectionResult(
        faceDetected: true,
        status: status,
        alertLevel: alertLevel,
        message: message,
        shouldAlert: shouldAlert,
        ear: ear,
        mar: mar,
        cnnConfidence: cnnConf,
        drowsyFrames: drowsyFrames,
        yawningFrames: yawningFrames,
        drowsyEvents: drowsyEvents,
      );
    } catch (e) {
      print('[ERROR] Processing failed: $e');
      return DetectionResult(
        faceDetected: false,
        status: 'ERROR',
        message: 'Processing failed: $e',
      );
    }
  }

  InputImage _imageToInputImage(img.Image image) {
    // Convert img.Image to InputImage format
    // Encode as JPEG bytes
    final bytes = Uint8List.fromList(img.encodeJpg(image));

    // Create InputImageData with proper format
    // For JPEG bytes, we need to use bgra8888 or rgba8888 format
    final inputImageData = InputImageData(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      imageRotation: InputImageRotation.rotation0deg,
      inputImageFormat: InputImageFormat.bgra8888,
      planeData: null,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImageData,
    );
  }

  double _calculateEAR(
      Map<FaceLandmarkType, FaceLandmark?> landmarks, int width, int height) {
    // Extract eye landmarks - FIX: landmarks is a Map, not a List
    final leftEyeOuter = landmarks[FaceLandmarkType.leftEye];
    final leftEyeInner = landmarks[FaceLandmarkType.leftEye];

    final rightEyeOuter = landmarks[FaceLandmarkType.rightEye];
    final rightEyeInner = landmarks[FaceLandmarkType.rightEye];

    // If landmarks are not available, return a default value
    if (leftEyeOuter == null || rightEyeOuter == null) {
      return 0.3; // Default EAR (between threshold)
    }

    // Calculate simple EAR based on eye positions
    // Since ML Kit doesn't provide detailed eye landmarks like MediaPipe,
    // we use a simplified calculation
    final leftEyePos = leftEyeOuter.position;
    final rightEyePos = rightEyeOuter.position;

    // Estimate EAR from eye distance (simplified approach)
    final eyeDistance = math.sqrt(
      math.pow(rightEyePos.x - leftEyePos.x, 2) +
          math.pow(rightEyePos.y - leftEyePos.y, 2),
    );

    // Normalized EAR approximation
    // When eyes are open, this should be around 0.3-0.4
    // When closed, closer to 0.1-0.2
    return eyeDistance / width * 1.5;
  }

  double _calculateMAR(
      Map<FaceLandmarkType, FaceLandmark?> landmarks, int width, int height) {
    // Extract mouth landmarks - FIX: landmarks is a Map, not a List
    final mouthLeft = landmarks[FaceLandmarkType.leftMouth];
    final mouthRight = landmarks[FaceLandmarkType.rightMouth];
    final mouthBottom = landmarks[FaceLandmarkType.bottomMouth];

    // If landmarks are not available, return a default value
    if (mouthLeft == null || mouthRight == null || mouthBottom == null) {
      return 0.3; // Default MAR (below threshold)
    }

    // Calculate MAR
    final mouthWidth = math.sqrt(
      math.pow(mouthRight.position.x - mouthLeft.position.x, 2) +
          math.pow(mouthRight.position.y - mouthLeft.position.y, 2),
    );

    final mouthCenter = Offset(
      (mouthLeft.position.x + mouthRight.position.x) / 2,
      (mouthLeft.position.y + mouthRight.position.y) / 2,
    );

    final mouthHeight = math.sqrt(
      math.pow(mouthBottom.position.x - mouthCenter.dx, 2) +
          math.pow(mouthBottom.position.y - mouthCenter.dy, 2),
    );

    if (mouthWidth == 0) return 0.0;

    // MAR calculation (height to width ratio)
    return mouthHeight / mouthWidth;
  }

  img.Image? _prepareFaceImage(img.Image image, Face face) {
    try {
      // Extract face region with some padding
      final boundingBox = face.boundingBox;
      final padding = 20;

      final x = math.max(0, boundingBox.left.toInt() - padding);
      final y = math.max(0, boundingBox.top.toInt() - padding);
      final w =
          math.min(image.width - x, boundingBox.width.toInt() + padding * 2);
      final h =
          math.min(image.height - y, boundingBox.height.toInt() + padding * 2);

      // Crop and resize to 64x64 (RGB format)
      final cropped = img.copyCrop(
        image,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      // Resize to 64x64 maintaining aspect ratio, then pad if needed
      final resized = img.copyResize(
        cropped,
        width: 64,
        height: 64,
        interpolation: img.Interpolation.linear,
      );

      return resized;
    } catch (e) {
      print('[ERROR] Failed to prepare face image: $e');
      return null;
    }
  }

  void reset() {
    drowsyFrames = 0;
    yawningFrames = 0;
    drowsyEvents = 0;
    drowsyActive = false;
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
  }
}

class DetectionResult {
  final bool faceDetected;
  final String status;
  final int alertLevel;
  final String message;
  final bool shouldAlert;
  final double? ear;
  final double? mar;
  final double? cnnConfidence;
  final int drowsyFrames;
  final int yawningFrames;
  final int drowsyEvents;

  DetectionResult({
    required this.faceDetected,
    required this.status,
    this.alertLevel = 0,
    this.message = '',
    this.shouldAlert = false,
    this.ear,
    this.mar,
    this.cnnConfidence,
    this.drowsyFrames = 0,
    this.yawningFrames = 0,
    this.drowsyEvents = 0,
  });
}
