package com.drowsiness.detector

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.sqrt
import kotlin.math.pow

class MainActivity : AppCompatActivity() {
    private lateinit var previewView: PreviewView
    private lateinit var statusText: TextView
    private lateinit var metricsText: TextView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var resetButton: Button
    
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var camera: Camera? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    
    private var tfliteInterpreter: Interpreter? = null
    private val faceDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .enableLandmarks()
            .build()
    )
    
    private var mediaPlayer: MediaPlayer? = null
    
    // Detection parameters (from main.py)
    private val EAR_THRESHOLD = 0.25f
    private val MAR_THRESHOLD = 0.5f
    private val DROWSY_FRAME_THRESHOLD = 100
    private val YAWNING_FRAME_THRESHOLD = 20
    
    // Frame counters
    private var drowsyFrames = 0
    private var yawningFrames = 0
    private var drowsyEvents = 0
    private var drowsyActive = false
    private var isDetecting = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        previewView = findViewById(R.id.previewView)
        statusText = findViewById(R.id.statusText)
        metricsText = findViewById(R.id.metricsText)
        startButton = findViewById(R.id.startButton)
        stopButton = findViewById(R.id.stopButton)
        resetButton = findViewById(R.id.resetButton)
        
        // Load TFLite model
        loadTFLiteModel()
        
        // Request camera permission
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(
                this,
                REQUIRED_PERMISSIONS,
                REQUEST_CODE_PERMISSIONS
            )
        }
        
        startButton.setOnClickListener {
            isDetecting = true
            startButton.isEnabled = false
            stopButton.isEnabled = true
            statusText.text = "Detection Started"
        }
        
        stopButton.setOnClickListener {
            isDetecting = false
            startButton.isEnabled = true
            stopButton.isEnabled = false
            stopAlarm()
            statusText.text = "Detection Stopped"
        }
        
        resetButton.setOnClickListener {
            resetCounters()
        }
    }
    
    private fun loadTFLiteModel() {
        try {
            val modelBuffer = loadModelFile("final_drowsiness_model.tflite")
            tfliteInterpreter = Interpreter(modelBuffer)
            Toast.makeText(this, "Model loaded successfully", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(this, "Failed to load model: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }
    
    private fun loadModelFile(filename: String): MappedByteBuffer {
        val fileDescriptor = assets.openFd(filename)
        val inputStream = FileInputStream(fileDescriptor.createInputStream())
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }
    
    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            
            imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor) { imageProxy ->
                        if (isDetecting) {
                            processImage(imageProxy)
                        }
                        imageProxy.close()
                    }
                }
            
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
            
            val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA
            
            try {
                cameraProvider?.unbindAll()
                camera = cameraProvider?.bindToLifecycle(
                    this as LifecycleOwner,
                    cameraSelector,
                    preview,
                    imageAnalysis
                )
            } catch (e: Exception) {
                Toast.makeText(this, "Camera error: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }, ContextCompat.getMainExecutor(this))
    }
    
    private fun processImage(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(
                mediaImage,
                imageProxy.imageInfo.rotationDegrees
            )
            
            faceDetector.process(image)
                .addOnSuccessListener { faces ->
                    if (faces.isNotEmpty()) {
                        val face = faces[0]
                        detectDrowsiness(face, image)
                    } else {
                        runOnUiThread {
                            statusText.text = "No Face Detected"
                            drowsyFrames = 0
                            yawningFrames = 0
                        }
                    }
                }
                .addOnFailureListener { e ->
                    // Handle error
                }
        }
    }
    
    private fun detectDrowsiness(face: com.google.mlkit.vision.face.Face, image: InputImage) {
        // Calculate EAR and MAR from face landmarks
        val ear = calculateEAR(face)
        val mar = calculateMAR(face)
        
        // CNN Prediction using TFLite
        var cnnLabel = 0
        var cnnConf = 1.0f
        
        tfliteInterpreter?.let { interpreter ->
            try {
                // Prepare face image (64x64, normalized)
                val faceImage = prepareFaceImage(image, face)
                if (faceImage != null) {
                    val inputBuffer = FloatArray(1 * 64 * 64 * 3)
                    var pixelIndex = 0
                    
                    for (y in 0 until 64) {
                        for (x in 0 until 64) {
                            val pixel = faceImage[y * 64 + x]
                            inputBuffer[pixelIndex++] = (pixel and 0xFF) / 255.0f
                            inputBuffer[pixelIndex++] = ((pixel shr 8) and 0xFF) / 255.0f
                            inputBuffer[pixelIndex++] = ((pixel shr 16) and 0xFF) / 255.0f
                        }
                    }
                    
                    val outputBuffer = Array(1) { FloatArray(2) }
                    interpreter.run(inputBuffer, outputBuffer)
                    
                    cnnLabel = if (outputBuffer[0][1] > outputBuffer[0][0]) 1 else 0
                    cnnConf = outputBuffer[0][cnnLabel]
                }
            } catch (e: Exception) {
                // Handle error
            }
        }
        
        // Raw detection
        val rawDrowsy = cnnLabel == 1 || ear < EAR_THRESHOLD
        
        // Update frame counters
        if (rawDrowsy) {
            drowsyFrames++
        } else {
            drowsyFrames = 0
            drowsyActive = false
        }
        
        if (mar > MAR_THRESHOLD) {
            yawningFrames++
        } else {
            yawningFrames = 0
        }
        
        // Final decision
        val finalDrowsy = drowsyFrames >= DROWSY_FRAME_THRESHOLD
        val finalYawning = yawningFrames >= YAWNING_FRAME_THRESHOLD
        
        runOnUiThread {
            when {
                finalDrowsy -> {
                    statusText.text = "DROWSY - Alert!"
                    statusText.setTextColor(getColor(R.color.red))
                    
                    if (!drowsyActive) {
                        drowsyEvents++
                        drowsyActive = true
                        playAlarm()
                        
                        if (drowsyEvents >= 3) {
                            statusText.text = "CRITICAL: Repeated Drowsiness!"
                        }
                    }
                }
                finalYawning -> {
                    statusText.text = "YAWNING"
                    statusText.setTextColor(getColor(R.color.orange))
                }
                else -> {
                    statusText.text = "ALERT"
                    statusText.setTextColor(getColor(R.color.green))
                    stopAlarm()
                }
            }
            
            metricsText.text = """
                EAR: ${String.format("%.3f", ear)}
                MAR: ${String.format("%.3f", mar)}
                CNN: ${String.format("%.2f", cnnConf)}
                Events: $drowsyEvents
                Drowsy Frames: $drowsyFrames
                Yawning Frames: $yawningFrames
            """.trimIndent()
        }
    }
    
    private fun calculateEAR(face: com.google.mlkit.vision.face.Face): Float {
        // Simplified EAR calculation using available landmarks
        val leftEye = face.getLandmark(com.google.mlkit.vision.face.FaceLandmark.LEFT_EYE)
        val rightEye = face.getLandmark(com.google.mlkit.vision.face.FaceLandmark.RIGHT_EYE)
        
        if (leftEye == null || rightEye == null) return 0.3f
        
        // Simplified calculation - in real implementation, use multiple eye points
        return 0.3f // Placeholder
    }
    
    private fun calculateMAR(face: com.google.mlkit.vision.face.Face): Float {
        val mouthBottom = face.getLandmark(com.google.mlkit.vision.face.FaceLandmark.MOUTH_BOTTOM)
        val mouthLeft = face.getLandmark(com.google.mlkit.vision.face.FaceLandmark.MOUTH_LEFT)
        val mouthRight = face.getLandmark(com.google.mlkit.vision.face.FaceLandmark.MOUTH_RIGHT)
        
        if (mouthBottom == null || mouthLeft == null || mouthRight == null) return 0.3f
        
        // Simplified MAR calculation
        return 0.3f // Placeholder
    }
    
    private fun prepareFaceImage(image: InputImage, face: com.google.mlkit.vision.face.Face): IntArray? {
        // This would require image processing - simplified for now
        return null
    }
    
    private fun playAlarm() {
        try {
            if (mediaPlayer == null) {
                mediaPlayer = MediaPlayer.create(this, R.raw.alarm)
            }
            mediaPlayer?.start()
        } catch (e: Exception) {
            // Handle error
        }
    }
    
    private fun stopAlarm() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }
    
    private fun resetCounters() {
        drowsyFrames = 0
        yawningFrames = 0
        drowsyEvents = 0
        drowsyActive = false
        statusText.text = "ALERT"
        metricsText.text = "Metrics will appear here"
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                startCamera()
            } else {
                Toast.makeText(this, "Camera permission required", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
        faceDetector.close()
        tfliteInterpreter?.close()
        stopAlarm()
    }
    
    companion object {
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }
}

