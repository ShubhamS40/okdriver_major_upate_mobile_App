import numpy as np
import tensorflow as tf
import mediapipe as mp
import cv2
import joblib
import os
import base64
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from typing import Dict, Any
from datetime import datetime

app = FastAPI(title="Drowsiness Detection API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for models
interpreter = None
rf_model = None
face_mesh = None

# Detection parameters
EAR_THRESHOLD = 0.25
MAR_THRESHOLD = 0.5
DROWSY_FRAME_THRESHOLD = 7  # Reduced for web demo
YAWNING_FRAME_THRESHOLD = 7  # Reduced for web demo

# MediaPipe landmark indices
LEFT_EYE_IDX = [33, 160, 158, 133, 153, 144]
RIGHT_EYE_IDX = [263, 387, 385, 362, 380, 373]
MOUTH_IDX = [61, 291, 81, 178, 13, 14, 17]

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

    def process_frame(self, frame_data: str) -> Dict[str, Any]:
        try:
            # Decode base64 image
            img_data = base64.b64decode(frame_data.split(',')[1])
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
                # Trigger only once when crossing threshold
                if self.yawning_frames == YAWNING_FRAME_THRESHOLD:
                    should_alert = True

            return {
                "face_detected": True,
                "status": status,
                "alert_level": alert_level,
                "message": message,
                "should_alert": should_alert,
                "metrics": {
                    "ear": round(avg_ear, 3),
                    "mar": round(mar, 3),
                    "cnn_confidence": round(cnn_conf, 2),
                    "drowsy_frames": self.drowsy_frames,
                    "yawning_frames": self.yawning_frames,
                    "drowsy_events": self.drowsy_events
                },
                "landmarks": {
                    "left_eye": left_eye,
                    "right_eye": right_eye,
                    "mouth": mouth
                },
                "frame_size": {"width": w, "height": h},
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            return {"error": f"Processing failed: {str(e)}"}

# Initialize detector
detector = DrowsinessDetector()

# Store active connections
active_connections: list[WebSocket] = []

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    print(f"Client connected. Total connections: {len(active_connections)}")
    
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message["type"] == "frame":
                # Process the frame
                result = detector.process_frame(message["data"])
                
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
                detector.reset()
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
    return HTMLResponse("""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Drowsiness Detection System</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                min-height: 100vh;
            }
            
            .container {
                max-width: 1200px;
                margin: 0 auto;
                display: grid;
                grid-template-columns: 1fr 300px;
                gap: 20px;
            }
            
            .video-section {
                background: rgba(255, 255, 255, 0.1);
                padding: 20px;
                border-radius: 15px;
                backdrop-filter: blur(10px);
            }
            
            .controls-section {
                background: rgba(255, 255, 255, 0.1);
                padding: 20px;
                border-radius: 15px;
                backdrop-filter: blur(10px);
                height: fit-content;
            }
            
            h1 {
                text-align: center;
                margin-bottom: 30px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            
            video, canvas {
                width: 100%;
                max-width: 640px;
                border-radius: 10px;
                box-shadow: 0 8px 32px rgba(0,0,0,0.3);
            }
            
            .status-card {
                background: rgba(255, 255, 255, 0.2);
                padding: 15px;
                margin: 10px 0;
                border-radius: 10px;
                border-left: 4px solid;
            }
            
            .status-alert { border-left-color: #4ade80; }
            .status-yawning { border-left-color: #fbbf24; }
            .status-drowsy { border-left-color: #ef4444; }
            .status-critical { border-left-color: #dc2626; animation: pulse 1s infinite; }
            
            @keyframes pulse {
                0%, 100% { transform: scale(1); }
                50% { transform: scale(1.02); }
            }
            
            .metrics {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 10px;
                margin-top: 15px;
            }
            
            .metric {
                background: rgba(255, 255, 255, 0.1);
                padding: 10px;
                border-radius: 8px;
                text-align: center;
            }
            
            .metric-label {
                font-size: 12px;
                opacity: 0.8;
            }
            
            .metric-value {
                font-size: 18px;
                font-weight: bold;
                margin-top: 5px;
            }
            
            button {
                background: linear-gradient(45deg, #667eea, #764ba2);
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 25px;
                cursor: pointer;
                font-size: 16px;
                margin: 5px;
                transition: transform 0.2s;
            }
            
            button:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 15px rgba(0,0,0,0.3);
            }
            
            button:disabled {
                opacity: 0.6;
                cursor: not-allowed;
                transform: none;
            }
            
            .connection-status {
                text-align: center;
                padding: 10px;
                border-radius: 8px;
                margin-bottom: 15px;
            }
            
            .connected {
                background: rgba(74, 222, 128, 0.2);
                color: #4ade80;
            }
            
            .disconnected {
                background: rgba(239, 68, 68, 0.2);
                color: #ef4444;
            }
            
            .log {
                max-height: 200px;
                overflow-y: auto;
                background: rgba(0, 0, 0, 0.3);
                padding: 10px;
                border-radius: 8px;
                font-family: monospace;
                font-size: 12px;
                margin-top: 15px;
            }
            
            .log-entry {
                margin-bottom: 5px;
                padding: 2px 0;
                border-bottom: 1px solid rgba(255,255,255,0.1);
            }
            
            @media (max-width: 768px) {
                .container {
                    grid-template-columns: 1fr;
                }
            }
        </style>
    </head>
    <body>
        <h1>🔍 Real-time Drowsiness Detection System</h1>
        
        <div class="container">
            <div class="video-section">
                <video id="video" autoplay muted playsinline></video>
                <canvas id="canvas" style="display: none;"></canvas>
                <div style="text-align: center; margin-top: 15px;">
                    <button id="startBtn">Start Detection</button>
                    <button id="stopBtn" disabled>Stop Detection</button>
                </div>
            </div>
            
            <div class="controls-section">
                <div id="connectionStatus" class="connection-status disconnected">
                    📡 Disconnected
                </div>
                
                <div id="statusCard" class="status-card status-alert">
                    <div style="font-size: 18px; font-weight: bold;">Status: WAITING</div>
                    <div style="font-size: 14px; margin-top: 5px;">Click Start Detection to begin</div>
                </div>
                
                <div class="metrics">
                    <div class="metric">
                        <div class="metric-label">EAR</div>
                        <div class="metric-value" id="earValue">0.000</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">MAR</div>
                        <div class="metric-value" id="marValue">0.000</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">CNN Conf</div>
                        <div class="metric-value" id="cnnValue">0.00</div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">Events</div>
                        <div class="metric-value" id="eventsValue">0</div>
                    </div>
                </div>
                
                <div class="log" id="logContainer">
                    <div class="log-entry">System initialized</div>
                </div>
            </div>
        </div>
        
        <script>
            let video, canvas, ctx, ws, isDetecting = false;
            let detectionInterval;
            
            const statusCard = document.getElementById('statusCard');
            const connectionStatus = document.getElementById('connectionStatus');
            const startBtn = document.getElementById('startBtn');
            const stopBtn = document.getElementById('stopBtn');
            const logContainer = document.getElementById('logContainer');
            
            function log(message) {
                const entry = document.createElement('div');
                entry.className = 'log-entry';
                entry.textContent = `${new Date().toLocaleTimeString()}: ${message}`;
                logContainer.appendChild(entry);
                logContainer.scrollTop = logContainer.scrollHeight;
            }
            
            function connectWebSocket() {
                const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = `${protocol}//${location.host}/ws`;
                
                ws = new WebSocket(wsUrl);
                
                ws.onopen = function() {
                    connectionStatus.textContent = '📡 Connected';
                    connectionStatus.className = 'connection-status connected';
                    log('WebSocket connected');
                };
                
                ws.onmessage = function(event) {
                    const message = JSON.parse(event.data);
                    
                    if (message.type === 'detection_result') {
                        handleDetectionResult(message.data);
                    }
                };
                
                ws.onclose = function() {
                    connectionStatus.textContent = '📡 Disconnected';
                    connectionStatus.className = 'connection-status disconnected';
                    log('WebSocket disconnected');
                    
                    // Auto-reconnect after 3 seconds
                    setTimeout(connectWebSocket, 3000);
                };
                
                ws.onerror = function(error) {
                    log('WebSocket error: ' + error);
                };
            }
            
            function handleDetectionResult(data) {
                if (data.error) {
                    log('Error: ' + data.error);
                    return;
                }
                
                // Update status card
                let statusClass = 'status-alert';
                let statusText = data.status;
                
                if (data.alert_level >= 4) statusClass = 'status-critical';
                else if (data.alert_level >= 3) statusClass = 'status-drowsy';
                else if (data.alert_level >= 2) statusClass = 'status-yawning';
                
                statusCard.className = `status-card ${statusClass}`;
                statusCard.innerHTML = `
                    <div style="font-size: 18px; font-weight: bold;">Status: ${statusText}</div>
                    <div style="font-size: 14px; margin-top: 5px;">${data.message}</div>
                `;
                
                // Update metrics
                if (data.metrics) {
                    document.getElementById('earValue').textContent = data.metrics.ear;
                    document.getElementById('marValue').textContent = data.metrics.mar;
                    document.getElementById('cnnValue').textContent = data.metrics.cnn_confidence;
                    document.getElementById('eventsValue').textContent = data.metrics.drowsy_events;
                }
                
                // Log important events
                if (data.alert_level >= 3) {
                    log(`ALERT: ${data.message}`);
                }
            }
            
            async function initCamera() {
                video = document.getElementById('video');
                canvas = document.getElementById('canvas');
                ctx = canvas.getContext('2d');
                
                try {
                    const stream = await navigator.mediaDevices.getUserMedia({
                        video: { 
                            width: 640, 
                            height: 480,
                            facingMode: 'user'
                        }
                    });
                    
                    video.srcObject = stream;
                    video.onloadedmetadata = function() {
                        canvas.width = video.videoWidth;
                        canvas.height = video.videoHeight;
                        log('Camera initialized');
                    };
                } catch (err) {
                    log('Camera access denied: ' + err.message);
                    alert('Please allow camera access to use this application');
                }
            }
            
            function captureFrame() {
                if (!video.videoWidth || !video.videoHeight) return null;
                
                ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
                return canvas.toDataURL('image/jpeg', 0.8);
            }
            
            function startDetection() {
                if (!ws || ws.readyState !== WebSocket.OPEN) {
                    alert('WebSocket not connected. Please wait and try again.');
                    return;
                }
                
                isDetecting = true;
                startBtn.disabled = true;
                stopBtn.disabled = false;
                log('Detection started');
                
                detectionInterval = setInterval(() => {
                    if (isDetecting && ws.readyState === WebSocket.OPEN) {
                        const frameData = captureFrame();
                        if (frameData) {
                            ws.send(JSON.stringify({
                                type: 'frame',
                                data: frameData
                            }));
                        }
                    }
                }, 200); // Send frame every 200ms (5 FPS)
            }
            
            function stopDetection() {
                isDetecting = false;
                startBtn.disabled = false;
                stopBtn.disabled = true;
                
                if (detectionInterval) {
                    clearInterval(detectionInterval);
                }
                
                statusCard.className = 'status-card status-alert';
                statusCard.innerHTML = `
                    <div style="font-size: 18px; font-weight: bold;">Status: STOPPED</div>
                    <div style="font-size: 14px; margin-top: 5px;">Detection stopped</div>
                `;
                
                log('Detection stopped');
            }
            
            // Event listeners
            startBtn.addEventListener('click', startDetection);
            stopBtn.addEventListener('click', stopDetection);
            
            // Initialize
            window.onload = function() {
                connectWebSocket();
                initCamera();
            };
        </script>
    </body>
    </html>
    """)

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "models": {
            "tflite": interpreter is not None,
            "random_forest": rf_model is not None,
            "mediapipe": face_mesh is not None
        },
        "connections": len(active_connections)
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)