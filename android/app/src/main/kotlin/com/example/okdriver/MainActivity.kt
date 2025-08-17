package com.example.okdriver

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.okdriver/background_recording"
    private var methodChannel: MethodChannel? = null
    
    // Recording state
    private var isRecording = false
    private var currentVideoFile: File? = null
    private var recordingStartTime: Long = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeBackgroundRecording" -> {
                    initializeBackgroundRecording(result)
                }
                "startBackgroundRecording" -> {
                    startBackgroundRecording(result)
                }
                "stopBackgroundRecording" -> {
                    stopBackgroundRecording(result)
                }
                "isRecording" -> {
                    result.success(isRecording)
                }
                "getRecordingDuration" -> {
                    val duration = if (isRecording) {
                        (System.currentTimeMillis() - recordingStartTime) / 1000
                    } else 0
                    result.success(duration)
                }
                "getCurrentVideoPath" -> {
                    result.success(currentVideoFile?.absolutePath)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeBackgroundRecording(result: MethodChannel.Result) {
        try {
            // Check permissions
            if (!hasRequiredPermissions()) {
                result.error("PERMISSION_DENIED", "Camera and storage permissions required", null)
                return
            }

            // Create notification channel for Android 8+
            createNotificationChannel()

            result.success(true)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error in initializeBackgroundRecording", e)
            result.error("INIT_ERROR", "Failed to initialize background recording", e.message)
        }
    }

    private fun startBackgroundRecording(result: MethodChannel.Result) {
        if (isRecording) {
            result.success(mapOf("success" to true, "message" to "Already recording"))
            return
        }

        try {
            // Create video file
            val videoDir = File(getExternalFilesDir(null), "dashcam_videos")
            if (!videoDir.exists()) {
                videoDir.mkdirs()
            }

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            currentVideoFile = File(videoDir, "dashcam_$timestamp.mp4")

            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            
            // Start foreground service for continuous recording
            startForegroundService()
            
            Log.d("MainActivity", "Background recording started: ${currentVideoFile?.absolutePath}")
            result.success(mapOf(
                "success" to true,
                "filePath" to currentVideoFile?.absolutePath,
                "message" to "Recording started"
            ))
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting background recording", e)
            result.error("RECORDING_ERROR", "Failed to start recording", e.message)
        }
    }

    private fun stopBackgroundRecording(result: MethodChannel.Result) {
        if (!isRecording) {
            result.success(mapOf("success" to true, "message" to "Not recording"))
            return
        }

        try {
            isRecording = false
            
            // Stop foreground service
            stopForegroundService()
            
            Log.d("MainActivity", "Background recording stopped")
            result.success(mapOf(
                "success" to true,
                "filePath" to currentVideoFile?.absolutePath,
                "message" to "Recording stopped"
            ))
        } catch (e: Exception) {
            Log.e("MainActivity", "Error stopping background recording", e)
            result.error("STOP_ERROR", "Failed to stop recording", e.message)
        }
    }

    private fun startForegroundService() {
        val intent = Intent(this, BackgroundRecordingService::class.java)
        intent.putExtra("videoPath", currentVideoFile?.absolutePath)
        intent.putExtra("startTime", recordingStartTime)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundService() {
        val intent = Intent(this, BackgroundRecordingService::class.java)
        stopService(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Dashcam Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows dashcam recording status"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isRecording) {
            stopBackgroundRecording(object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })
        }
    }

    companion object {
        const val CHANNEL_ID = "dashcam_recording_channel"
        const val NOTIFICATION_ID = 1001
    }
}

class BackgroundRecordingService : android.app.Service() {
    private var isRecording = false
    private var recordingStartTime: Long = 0
    private var currentVideoPath: String? = null

    override fun onCreate() {
        super.onCreate()
        Log.d("BackgroundRecordingService", "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("BackgroundRecordingService", "Service started")
        
        currentVideoPath = intent?.getStringExtra("videoPath")
        recordingStartTime = intent?.getLongExtra("startTime", 0) ?: 0
        isRecording = true

        // Create notification
        val notification = createNotification()
        startForeground(MainActivity.NOTIFICATION_ID, notification)

        return START_STICKY
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, MainActivity.CHANNEL_ID)
            .setContentTitle("Dashcam Recording")
            .setContentText("Recording in background...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    override fun onBind(intent: Intent?): android.os.IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("BackgroundRecordingService", "Service destroyed")
        isRecording = false
    }
}
