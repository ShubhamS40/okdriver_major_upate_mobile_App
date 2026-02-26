import numpy as np
import tensorflow as tf
import mediapipe as mp
import cv2
import joblib
import os
import base64
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, UploadFile, File, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from typing import Dict, Any
from datetime import datetime
from pydantic import BaseModel
from api_key_middleware import verify_api_key, optional_api_key_auth, init_database, cleanup_database, db_manager
import api_key_middleware
import logging

logger = logging.getLogger(__name__)

app = FastAPI(title="Drowsiness Detection API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static files (alarm.wav, etc.)
try:
    app.mount("/static", StaticFiles(directory="."), name="static")
except Exception as e:
    logger.warning(f"Could not mount static files: {e}")

# Direct file serving for alarm.wav
@app.get("/alarm.wav")
async def get_alarm():
    """Serve alarm.wav file"""
    try:
        return FileResponse("alarm.wav", media_type="audio/wav")
    except FileNotFoundError:
        logger.warning("alarm.wav not found")
        from fastapi.responses import Response
        return Response(status_code=404)

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    await init_database()

@app.on_event("shutdown")
async def shutdown_event():
    await cleanup_database()

# Global variables for models
interpreter = None
rf_model = None
face_mesh = None

# Detection parameters
EAR_THRESHOLD = 0.25
MAR_THRESHOLD = 0.5
DROWSY_FRAME_THRESHOLD = 7
YAWNING_FRAME_THRESHOLD = 7

# MediaPipe landmark indices
LEFT_EYE_IDX = [33, 160, 158, 133, 153, 144]
RIGHT_EYE_IDX = [263, 387, 385, 362, 380, 373]
MOUTH_IDX = [61, 291, 81, 178, 13, 14, 17]

class ImageData(BaseModel):
    image: str  # base64 encoded image

class DrowsinessDetector:
    def __init__(self):
        self.drowsy_frames = 0
        self.yawning_frames = 0
        self.drowsy_events = 0
        self.drowsy_active = False
        self.load_models()
    
    def reset(self):
        self.drowsy_frames = 0
        self.yawning_frames = 0
        self.drowsy_events = 0
        self.drowsy_active = False
        
    def load_models(self):
        global interpreter, rf_model, face_mesh
        
        # Load TFLite model
        try:
            interpreter = tf.lite.Interpreter(model_path="final_drowsiness_model.tflite")
            interpreter.allocate_tensors()
            print("[INFO] TFLite model loaded successfully")
        except Exception as e:
            print(f"[WARNING] Failed to load TFLite model: {e}")
            interpreter = None

        # Load Random Forest model
        try:
            rf_model = joblib.load("drowsiness_ml_model.pkl")
            print("[INFO] Random Forest model loaded successfully")
        except Exception as e:
            print(f"[WARNING] Failed to load RF model: {e}")
            rf_model = None

        # Setup MediaPipe Face Mesh
        mp_face_mesh = mp.solutions.face_mesh
        face_mesh = mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5
        )
        print("[INFO] MediaPipe Face Mesh initialized")

    def extract_landmarks(self, landmarks, indices):
        return [(landmarks[i].x, landmarks[i].y) for i in indices]

    def euclidean(self, p1, p2):
        return np.linalg.norm(np.array(p1) - np.array(p2))

    def eye_aspect_ratio(self, eye):
        A = self.euclidean(eye[1], eye[5])
        B = self.euclidean(eye[2], eye[4])
        C = self.euclidean(eye[0], eye[3])
        return (A + B) / (2.0 * C)

    def mouth_aspect_ratio(self, mouth):
        A = self.euclidean(mouth[2], mouth[6])
        B = self.euclidean(mouth[3], mouth[5])
        C = self.euclidean(mouth[0], mouth[1])
        return (A + B) / (2.0 * C)

    def analyze_single_frame(self, frame_data: str) -> Dict[str, Any]:
        """Analyze a single frame without state tracking"""
        try:
            # Decode base64 image
            if ',' in frame_data:
                img_data = base64.b64decode(frame_data.split(',')[1])
            else:
                img_data = base64.b64decode(frame_data)
                
            nparr = np.frombuffer(img_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                return {"error": "Failed to decode frame"}

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb)

            if not results.multi_face_landmarks:
                return {
                    "success": True,
                    "face_detected": False,
                    "status": "NO_FACE",
                    "message": "No face detected in the image"
                }

            h, w, _ = frame.shape
            landmarks = results.multi_face_landmarks[0].landmark

            # Extract landmarks
            left_eye = self.extract_landmarks(landmarks, LEFT_EYE_IDX)
            right_eye = self.extract_landmarks(landmarks, RIGHT_EYE_IDX)
            mouth = self.extract_landmarks(landmarks, MOUTH_IDX)

            # Convert to pixel coordinates
            left_eye = [(int(x * w), int(y * h)) for x, y in left_eye]
            right_eye = [(int(x * w), int(y * h)) for x, y in right_eye]
            mouth = [(int(x * w), int(y * h)) for x, y in mouth]

            # Calculate ratios
            left_ear = self.eye_aspect_ratio(left_eye)
            right_ear = self.eye_aspect_ratio(right_eye)
            avg_ear = (left_ear + right_ear) / 2.0
            mar = self.mouth_aspect_ratio(mouth)

            # CNN Prediction
            cnn_label, cnn_conf = 0, 1.0
            if interpreter is not None:
                try:
                    face_img = cv2.resize(rgb, (64, 64)) / 255.0
                    face_input = np.expand_dims(face_img.astype(np.float32), axis=0)
                    
                    input_details = interpreter.get_input_details()
                    output_details = interpreter.get_output_details()
                    
                    interpreter.set_tensor(input_details[0]['index'], face_input)
                    interpreter.invoke()
                    cnn_output = interpreter.get_tensor(output_details[0]['index'])
                    
                    cnn_label = int(np.argmax(cnn_output))
                    cnn_conf = float(np.max(cnn_output))
                except Exception as e:
                    print(f"CNN prediction error: {e}")

            # RF Prediction
            rf_label = 0
            if rf_model is not None:
                try:
                    rf_input = np.array([[avg_ear, mar, 0, 2.5, 2.4, 2.6]])
                    rf_prediction = rf_model.predict(rf_input)[0]
                    rf_label = 1 if str(rf_prediction).lower() == 'drowsy' else 0
                except Exception as e:
                    print(f"RF prediction error: {e}")

            # Determine status based on single frame
            is_drowsy = cnn_label == 1 or rf_label == 1 or avg_ear < EAR_THRESHOLD
            is_yawning = mar > MAR_THRESHOLD

            status = "ALERT"
            alert_level = 0
            message = "User is alert"

            if is_drowsy:
                status = "DROWSY"
                alert_level = 3
                message = "Signs of drowsiness detected"
            elif is_yawning:
                status = "YAWNING"
                alert_level = 2
                message = "Yawning detected"

            return {
                "success": True,
                "face_detected": True,
                "status": status,
                "alert_level": int(alert_level),
                "message": message,
                "metrics": {
                    "ear": round(float(avg_ear), 3),
                    "mar": round(float(mar), 3),
                    "cnn_confidence": round(float(cnn_conf), 2),
                    "cnn_prediction": "drowsy" if cnn_label == 1 else "alert",
                    "rf_prediction": "drowsy" if rf_label == 1 else "alert"
                },
                "analysis": {
                    "eyes_closed": bool(avg_ear < EAR_THRESHOLD),
                    "mouth_open": bool(mar > MAR_THRESHOLD),
                    "ear_threshold": float(EAR_THRESHOLD),
                    "mar_threshold": float(MAR_THRESHOLD)
                },
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            return {
                "success": False,
                "error": f"Processing failed: {str(e)}"
            }

    def process_frame(self, frame_data: str) -> Dict[str, Any]:
        """Process frame with state tracking for continuous detection"""
        try:
            # Decode base64 image
            if ',' in frame_data:
                img_data = base64.b64decode(frame_data.split(',')[1])
            else:
                img_data = base64.b64decode(frame_data)
                
            nparr = np.frombuffer(img_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                return {"error": "Failed to decode frame"}

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb)

            if not results.multi_face_landmarks:
                return {
                    "face_detected": False,
                    "status": "NO_FACE",
                    "message": "No face detected"
                }

            h, w, _ = frame.shape
            landmarks = results.multi_face_landmarks[0].landmark

            # Extract landmarks
            left_eye = self.extract_landmarks(landmarks, LEFT_EYE_IDX)
            right_eye = self.extract_landmarks(landmarks, RIGHT_EYE_IDX)
            mouth = self.extract_landmarks(landmarks, MOUTH_IDX)

            # Convert to pixel coordinates
            left_eye = [(int(x * w), int(y * h)) for x, y in left_eye]
            right_eye = [(int(x * w), int(y * h)) for x, y in right_eye]
            mouth = [(int(x * w), int(y * h)) for x, y in mouth]

            # Calculate ratios
            left_ear = self.eye_aspect_ratio(left_eye)
            right_ear = self.eye_aspect_ratio(right_eye)
            avg_ear = (left_ear + right_ear) / 2.0
            mar = self.mouth_aspect_ratio(mouth)

            # CNN Prediction
            cnn_label, cnn_conf = 0, 1.0
            if interpreter is not None:
                try:
                    face_img = cv2.resize(rgb, (64, 64)) / 255.0
                    face_input = np.expand_dims(face_img.astype(np.float32), axis=0)
                    
                    input_details = interpreter.get_input_details()
                    output_details = interpreter.get_output_details()
                    
                    interpreter.set_tensor(input_details[0]['index'], face_input)
                    interpreter.invoke()
                    cnn_output = interpreter.get_tensor(output_details[0]['index'])
                    
                    cnn_label = int(np.argmax(cnn_output))
                    cnn_conf = float(np.max(cnn_output))
                except Exception as e:
                    print(f"CNN prediction error: {e}")

            # RF Prediction
            rf_label = 0
            if rf_model is not None:
                try:
                    rf_input = np.array([[avg_ear, mar, 0, 2.5, 2.4, 2.6]])
                    rf_prediction = rf_model.predict(rf_input)[0]
                    rf_label = 1 if str(rf_prediction).lower() == 'drowsy' else 0
                except Exception as e:
                    print(f"RF prediction error: {e}")

            # Raw detection
            raw_drowsy = cnn_label == 1 or rf_label == 1 or avg_ear < EAR_THRESHOLD

            # Update counters
            if raw_drowsy:
                self.drowsy_frames += 1
            else:
                self.drowsy_frames = 0
                self.drowsy_active = False

            if mar > MAR_THRESHOLD:
                self.yawning_frames += 1
            else:
                self.yawning_frames = 0

            # Final decision
            final_drowsy = self.drowsy_frames >= DROWSY_FRAME_THRESHOLD
            final_yawning = self.yawning_frames >= YAWNING_FRAME_THRESHOLD

            status = "ALERT"
            alert_level = 0
            message = "User is alert"

            # Event trigger flags
            should_alert = False

            if final_drowsy:
                status = "DROWSY"
                alert_level = 3
                message = "User is drowsy!"
                
                if not self.drowsy_active:
                    self.drowsy_events += 1
                    self.drowsy_active = True
                    should_alert = True
                    
                    if self.drowsy_events >= 3:
                        alert_level = 4
                        message = "⚠️ CRITICAL: Repeated drowsiness detected!"
                        
            elif final_yawning:
                status = "YAWNING"
                alert_level = 2
                message = "User is yawning"
                if self.yawning_frames == YAWNING_FRAME_THRESHOLD:
                    should_alert = True

            return {
                "face_detected": True,
                "status": status,
                "alert_level": int(alert_level),
                "message": message,
                "should_alert": bool(should_alert),
                "metrics": {
                    "ear": round(float(avg_ear), 3),
                    "mar": round(float(mar), 3),
                    "cnn_confidence": round(float(cnn_conf), 2),
                    "drowsy_frames": int(self.drowsy_frames),
                    "yawning_frames": int(self.yawning_frames),
                    "drowsy_events": int(self.drowsy_events)
                },
                "landmarks": {
                    "left_eye": left_eye,
                    "right_eye": right_eye,
                    "mouth": mouth
                },
                "frame_size": {"width": int(w), "height": int(h)},
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            return {"error": f"Processing failed: {str(e)}"}

# Initialize detector
detector = DrowsinessDetector()

# Store active connections
active_connections: list[WebSocket] = []

# API 1: Image Upload Endpoint
@app.post("/api/detect-image")
async def detect_image(file: UploadFile | bytes | str = File(...), user: dict = Depends(verify_api_key)):
    """
    Upload an image file to detect drowsiness or yawning
    """
    try:
        # Read uploaded content in a tolerant way (UploadFile, raw bytes, or base64 str)
        contents: bytes | None = None
        if hasattr(file, "read"):
            # UploadFile case
            maybe = file.read()
            contents = await maybe if asyncio.iscoroutine(maybe) else maybe
        elif isinstance(file, (bytes, bytearray)):
            contents = bytes(file)
        elif isinstance(file, str):
            # Treat as base64 data URL or base64 string
            b64 = file.split(',')[1] if ',' in file else file
            contents = base64.b64decode(b64)
        else:
            raise ValueError("Unsupported file payload type")
        
        # Convert to base64
        base64_image = base64.b64encode(contents).decode('utf-8')
        
        # Create a temporary detector instance for single image analysis
        result = detector.analyze_single_frame(base64_image)
        
        return JSONResponse(content=result)
        
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

@app.post("/api/detect-base64")
async def detect_base64(data: ImageData, user: dict = Depends(verify_api_key)):
    """
    Send base64 encoded image to detect drowsiness or yawning
    """
    try:
        result = detector.analyze_single_frame(data.image)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

# API 2: WebSocket Endpoint for Continuous Detection
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    # Get API key from query parameters or headers
    api_key = websocket.query_params.get("api_key") or websocket.headers.get("x-api-key")
    
    # Also check Authorization header (Bearer token)
    if not api_key:
        auth_header = websocket.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            api_key = auth_header.replace("Bearer ", "")
    
    # Verify API key before accepting connection
    if not api_key:
        await websocket.close(code=4001, reason="API key required. Provide it as query parameter 'api_key', header 'x-api-key', or 'Authorization: Bearer <key>'")
        print(f"WebSocket connection rejected: No API key provided")
        return
    
    # Verify the API key using the database
    try:
        query = """
        SELECT 
            uak."id"                AS id,
            uak."keyName"           AS key_name,
            uak."apiKey"            AS api_key,
            uak."isActive"          AS is_active,
            uak."revoked"           AS revoked,
            uak."expiresAt"         AS expires_at,
            u.id                     AS user_id,
            s.id                     AS subscription_id,
            s.status                 AS subscription_status,
            s."endAt"               AS subscription_expires_at
        FROM "UserApiKey" uak
        JOIN "User" u ON uak."userId" = u.id
        LEFT JOIN LATERAL (
            SELECT sus.*
            FROM "UserApiSubscription" sus
            WHERE sus."userId" = u.id 
              AND sus.status = 'ACTIVE'
              AND sus."endAt" >= NOW()
            ORDER BY sus."endAt" DESC
            LIMIT 1
        ) s ON TRUE
        WHERE uak."apiKey" = $1
        """
        
        result = await db_manager.execute_query(query, api_key)
        
        if not result:
            await websocket.close(code=4003, reason="Invalid API key")
            print(f"WebSocket connection rejected: Invalid API key")
            return
        
        # Check if API key is active and not revoked
        if not result['is_active'] or result['revoked']:
            await websocket.close(code=4003, reason="API key inactive or revoked")
            print(f"WebSocket connection rejected: API key inactive or revoked")
            return
        
        # Check if API key has expired
        from datetime import timezone
        expires_at_utc = api_key_middleware._to_aware_utc(result['expires_at']) if result['expires_at'] else None
        if expires_at_utc and expires_at_utc < datetime.now(timezone.utc):
            await websocket.close(code=4003, reason="API key expired")
            print(f"WebSocket connection rejected: API key expired")
            return
        
        # Check if user has an active subscription
        if not result['subscription_id']:
            await websocket.close(code=4002, reason="No active subscription")
            print(f"WebSocket connection rejected: No active subscription")
            return
        
        # Check if subscription is expired
        sub_expires_at = api_key_middleware._to_aware_utc(result['subscription_expires_at']) if result['subscription_expires_at'] else None
        if sub_expires_at and sub_expires_at < datetime.now(timezone.utc):
            await websocket.close(code=4002, reason="Subscription expired")
            print(f"WebSocket connection rejected: Subscription expired")
            return
        
        # Update last used timestamp
        update_query = """
        UPDATE "UserApiKey" 
        SET "lastUsedAt" = NOW() 
        WHERE id = $1
        """
        await db_manager.execute_query(update_query, result['id'])
        
        print(f"WebSocket authenticated for user: {result['user_id']}")
        
    except Exception as e:
        logger.error(f"WebSocket API key verification error: {e}")
        await websocket.close(code=4000, reason="Authentication error")
        print(f"WebSocket connection rejected: Authentication error: {e}")
        return
    
    # Accept the connection after successful authentication
    await websocket.accept()
    active_connections.append(websocket)
    print(f"Client connected. Total connections: {len(active_connections)}")
    
    # Create a separate detector instance for this WebSocket connection
    ws_detector = DrowsinessDetector()
    
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message["type"] == "frame":
                # Process the frame with state tracking
                result = ws_detector.process_frame(message["data"])
                
                # Send result back to client
                await websocket.send_text(json.dumps({
                    "type": "detection_result",
                    "data": result
                }))
                
            elif message["type"] == "ping":
                await websocket.send_text(json.dumps({
                    "type": "pong"
                }))
            
            elif message["type"] == "reset":
                ws_detector.reset()
                await websocket.send_text(json.dumps({
                    "type": "detection_result",
                    "data": {
                        "face_detected": False,
                        "status": "ALERT",
                        "alert_level": 0,
                        "message": "Detection reset",
                        "should_alert": False,
                        "metrics": {
                            "ear": 0.0,
                            "mar": 0.0,
                            "cnn_confidence": 0.0,
                            "drowsy_frames": 0,
                            "yawning_frames": 0,
                            "drowsy_events": 0
                        },
                        "landmarks": {},
                        "timestamp": datetime.now().isoformat()
                    }
                }))
                
    except WebSocketDisconnect:
        active_connections.remove(websocket)
        print(f"Client disconnected. Total connections: {len(active_connections)}")
    except Exception as e:
        print(f"WebSocket error: {e}")
        if websocket in active_connections:
            active_connections.remove(websocket)

@app.get("/")
async def get_index():
    """Serve the index.html file"""
    try:
        # Read the index.html file
        with open("index.html", "r", encoding="utf-8") as f:
            html_content = f.read()
        return HTMLResponse(content=html_content)
    except FileNotFoundError as e:
        logger.error(f"index.html not found: {e}")
        return HTMLResponse("""
        <html>
            <body>
                <h1>Error: index.html not found</h1>
                <p>Please ensure index.html exists in the same directory as index.py</p>
            </body>
        </html>
        """, status_code=404)

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "port": 8001,
        "apis": {
            "image_upload": "/api/detect-image (POST)",
            "base64_upload": "/api/detect-base64 (POST)",
            "websocket": "/ws (WebSocket)"
        },
        "models": {
            "tflite": interpreter is not None,
            "random_forest": rf_model is not None,
            "mediapipe": face_mesh is not None
        },
        "connections": len(active_connections)
    }

@app.get("/api/info")
async def api_info():
    return {
        "title": "Drowsiness Detection API",
        "version": "2.0",
        "port": 8001,
        "endpoints": {
            "image_upload": {
                "path": "/api/detect-image",
                "method": "POST",
                "description": "Upload an image file for drowsiness detection",
                "content_type": "multipart/form-data",
                "parameters": {
                    "file": "Image file (JPG, PNG, WebP)"
                }
            },
            "base64_upload": {
                "path": "/api/detect-base64",
                "method": "POST",
                "description": "Send base64 encoded image for detection",
                "content_type": "application/json",
                "body": {
                    "image": "base64 encoded image string"
                }
            },
            "websocket": {
                "path": "/ws",
                "protocol": "WebSocket",
                "description": "Real-time continuous frame detection",
                "message_types": {
                    "frame": "Send frame data for processing",
                    "ping": "Check connection",
                    "reset": "Reset detection counters"
                }
            },
            "health": {
                "path": "/health",
                "method": "GET",
                "description": "Check API health and model status"
            }
        },
        "detection_parameters": {
            "EAR_THRESHOLD": EAR_THRESHOLD,
            "MAR_THRESHOLD": MAR_THRESHOLD,
            "DROWSY_FRAME_THRESHOLD": DROWSY_FRAME_THRESHOLD,
            "YAWNING_FRAME_THRESHOLD": YAWNING_FRAME_THRESHOLD
        }
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)