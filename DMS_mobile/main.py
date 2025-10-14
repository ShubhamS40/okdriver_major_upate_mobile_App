import numpy as np
import tensorflow as tf
import mediapipe as mp
import cv2  # Missing import
import pygame
import joblib
import os
from scipy.spatial import distance
 
# === Load TFLite model ===
try:
    interpreter = tf.lite.Interpreter(model_path="final_drowsiness_model.tflite")
    interpreter.allocate_tensors()
    
    # Get input and output tensor details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print("[INFO] TFLite model loaded successfully")
except Exception as e:
    print(f"[ERROR] Failed to load TFLite model: {e}")
    interpreter = None

# === Load Random Forest model ===
try:
    rf_model = joblib.load("drowsiness_ml_model.pkl")
    print("[INFO] Random Forest model loaded successfully")
except Exception as e:
    print(f"[ERROR] Failed to load RF model: {e}")
    rf_model = None

# === Setup MediaPipe Face Mesh ===
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False, 
    max_num_faces=1,
    refine_landmarks=True, 
    min_detection_confidence=0.5
)

# === Setup Sound ===
pygame.mixer.init()
alarm_sound = "alarm.wav"

# Check if alarm file exists
if not os.path.exists(alarm_sound):
    print(f"[WARNING] Alarm sound file '{alarm_sound}' not found. Alarm will be disabled.")
    alarm_sound = None

# EAR/MAR thresholds
EAR_THRESHOLD = 0.25
MAR_THRESHOLD = 0.5

# Frame counters
drowsy_frames = 0
yawning_frames = 0

# Event counters
drowsy_events = 0
drowsy_active = False  # flag to avoid double counting

# Threshold for continuous detection
DROWSY_FRAME_THRESHOLD = 100   # Drowsy only if 100 continuous frames
YAWNING_FRAME_THRESHOLD = 20   # Yawn if 20 continuous frames

# MediaPipe landmark indices for face mesh (468 landmarks)
LEFT_EYE_IDX = [33, 160, 158, 133, 153, 144]
RIGHT_EYE_IDX = [263, 387, 385, 362, 380, 373]
MOUTH_IDX = [61, 291, 81, 178, 13, 14, 17]

def extract_landmarks(landmarks, indices):
    """Extract landmark coordinates for given indices"""
    return [(landmarks[i].x, landmarks[i].y) for i in indices]

def euclidean(p1, p2):
    """Calculate euclidean distance between two points"""
    return np.linalg.norm(np.array(p1) - np.array(p2))

def eye_aspect_ratio(eye):
    """Calculate Eye Aspect Ratio (EAR)"""
    # Vertical eye landmarks
    A = euclidean(eye[1], eye[5])
    B = euclidean(eye[2], eye[4])
    # Horizontal eye landmark
    C = euclidean(eye[0], eye[3])
    return (A + B) / (2.0 * C)

def mouth_aspect_ratio(mouth):
    """Calculate Mouth Aspect Ratio (MAR)"""
    # Vertical mouth landmarks
    A = euclidean(mouth[2], mouth[6])
    B = euclidean(mouth[3], mouth[5])
    # Horizontal mouth landmark
    C = euclidean(mouth[0], mouth[1])
    return (A + B) / (2.0 * C)

def play_alarm():
    """Play alarm sound if available"""
    if alarm_sound and os.path.exists(alarm_sound):
        try:
            if not pygame.mixer.get_busy():  # Check if any sound is playing
                pygame.mixer.Sound(alarm_sound).play()
        except Exception as e:
            print(f"[ERROR] Failed to play alarm: {e}")

def stop_alarm():
    """Stop alarm sound"""
    try:
        pygame.mixer.stop()
    except Exception as e:
        print(f"[ERROR] Failed to stop alarm: {e}")

# === Webcam Feed ===
cap = cv2.VideoCapture(0)

# Check if camera opened successfully
if not cap.isOpened():
    print("[ERROR] Cannot open camera")
    exit()

print("[INFO] Starting drowsiness detection...")
print("[INFO] Press 'q' to quit")

try:
    while True:
        success, frame = cap.read()
        if not success:
            print("[ERROR] Failed to read from camera")
            break

        # Flip frame horizontally for mirror effect
        frame = cv2.flip(frame, 1)
        
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb)

        if results.multi_face_landmarks:
            for face_landmarks in results.multi_face_landmarks:
                h, w, _ = frame.shape
                landmarks = face_landmarks.landmark

                # Extract eye and mouth landmarks
                left_eye = extract_landmarks(landmarks, LEFT_EYE_IDX)
                right_eye = extract_landmarks(landmarks, RIGHT_EYE_IDX)
                mouth = extract_landmarks(landmarks, MOUTH_IDX)

                # Convert normalized coordinates to pixel coordinates
                left_eye = [(int(x * w), int(y * h)) for x, y in left_eye]
                right_eye = [(int(x * w), int(y * h)) for x, y in right_eye]
                mouth = [(int(x * w), int(y * h)) for x, y in mouth]

                # Calculate ratios
                left_ear = eye_aspect_ratio(left_eye)
                right_ear = eye_aspect_ratio(right_eye)
                avg_EAR = (left_ear + right_ear) / 2.0
                mar = mouth_aspect_ratio(mouth)

                # === TFLite CNN Prediction ===
                cnn_label, cnn_conf = 0, 1.0
                if interpreter is not None:
                    try:
                        face_img = cv2.resize(rgb, (64, 64)) / 255.0
                        face_input = np.expand_dims(face_img.astype(np.float32), axis=0)

                        interpreter.set_tensor(input_details[0]['index'], face_input)
                        interpreter.invoke()
                        cnn_output = interpreter.get_tensor(output_details[0]['index'])

                        cnn_label = int(np.argmax(cnn_output))
                        cnn_conf = float(np.max(cnn_output))
                    except Exception as e:
                        print(f"[ERROR] CNN prediction failed: {e}")

                # === Random Forest Prediction ===
                rf_label = 0
                if rf_model is not None:
                    try:
                        # Create feature vector (adjust based on your model's requirements)
                        rf_input = np.array([[avg_EAR, mar, 0, 2.5, 2.4, 2.6]])
                        rf_prediction = rf_model.predict(rf_input)[0]
                        rf_label = 1 if str(rf_prediction).lower() == 'drowsy' else 0
                    except Exception as e:
                        print(f"[ERROR] RF prediction failed: {e}")

                # === Raw Detection (before smoothing) ===
                raw_drowsy = cnn_label == 1 or rf_label == 1 or avg_EAR < EAR_THRESHOLD
                raw_label = "DROWSY" if raw_drowsy else "ALERT"

                # === Update frame counters ===
                if raw_drowsy:
                    drowsy_frames += 1
                else:
                    drowsy_frames = 0
                    drowsy_active = False  # reset active flag when alert

                if mar > MAR_THRESHOLD:
                    yawning_frames += 1
                else:
                    yawning_frames = 0

                # === Final Smoothed Decision ===
                final_drowsy = drowsy_frames >= DROWSY_FRAME_THRESHOLD
                final_yawning = yawning_frames >= YAWNING_FRAME_THRESHOLD
                
                if final_drowsy:
                    final_label = "DROWSY"
                    
                    # Count new drowsy event
                    if not drowsy_active:
                        drowsy_events += 1
                        drowsy_active = True
                        print(f"[INFO] Drowsy event #{drowsy_events}")

                        # Trigger voice bot after 3 times
                        if drowsy_events >= 3:
                            print("⚠️ ALERT: User is repeatedly drowsy! Triggering voice bot...")
                            # TODO: Add your voice bot function call here
                            # trigger_voice_bot()
                elif final_yawning:
                    final_label = "YAWNING"
                else:
                    final_label = "ALERT"

                # === Display Output ===
                if final_drowsy or final_yawning:
                    color = (0, 0, 255)  # Red
                    status_text = final_label
                else:
                    color = (0, 255, 0)  # Green
                    status_text = "ALERT"

                cv2.putText(frame, f"{status_text} (CNN: {cnn_conf:.2f})", (30, 30),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
                cv2.putText(frame, f"EAR: {avg_EAR:.3f}  MAR: {mar:.3f}", (30, 60),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(frame, f"Drowsy Events: {drowsy_events}", (30, 90),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(frame, f"Frames: D={drowsy_frames} Y={yawning_frames}", (30, 120),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

                # Draw eye and mouth landmarks for debugging
                for point in left_eye + right_eye:
                    cv2.circle(frame, point, 2, (0, 255, 0), -1)
                for point in mouth:
                    cv2.circle(frame, point, 2, (255, 0, 0), -1)

                # === Alarm Logic ===
                if final_drowsy or final_yawning:
                    play_alarm()
                else:
                    stop_alarm()

        else:
            # No face detected
            cv2.putText(frame, "No Face Detected", (30, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
            stop_alarm()

        cv2.imshow("Drowsiness Detection - TFLite + RF + MediaPipe", frame)
        
        # Break loop on 'q' key press
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

except KeyboardInterrupt:
    print("\n[INFO] Interrupted by user")
except Exception as e:
    print(f"[ERROR] An error occurred: {e}")
finally:
    # Cleanup
    print("[INFO] Cleaning up...")
    cap.release()
    cv2.destroyAllWindows()
    pygame.mixer.quit()
    print("[INFO] Cleanup complete")