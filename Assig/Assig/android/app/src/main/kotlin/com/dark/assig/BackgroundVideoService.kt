package com.dark.assig

import android.Manifest
import android.annotation.SuppressLint
import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.camera.view.PreviewView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import android.util.Log // Added Log import for safety

class BackgroundVideoService : LifecycleService() {
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    companion object {
        var isServiceRunning = false
        var currentLensFacing = CameraSelector.LENS_FACING_FRONT
        var currentPreviewView: PreviewView? = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)

        when (intent?.action) {
            "ACTION_SWITCH_CAMERA" -> {
                currentLensFacing = if (currentLensFacing == CameraSelector.LENS_FACING_FRONT)
                    CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
                startCamera()
            }
            "ACTION_UPDATE_VISIBILITY" -> {
                val isVisible = intent.getBooleanExtra("isVisible", true)

                updateNotification(isVisible)
            }
            else -> if (!isServiceRunning) {
                isServiceRunning = true
                updateNotification(true)
                startCamera()
            }
        }
        return START_STICKY
    }

    private fun updateNotification(appVisible: Boolean) {
        val hasAudioPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val hasCameraPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

         if (!hasAudioPermission || !hasCameraPermission) {
            if (!appVisible) {
                isServiceRunning = false
                stopSelf()
                return
            }
        }

        val channelId = "dark_recorder"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
             val importance = if (appVisible) NotificationManager.IMPORTANCE_MIN else NotificationManager.IMPORTANCE_DEFAULT
            manager.createNotificationChannel(NotificationChannel(channelId, "Recorder", importance))
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(if (appVisible) "Monitor Active" else "🔴 Recording")
            .setContentText("System secure capture in progress...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true).build()

         if (hasAudioPermission && hasCameraPermission) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                 val type = ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                startForeground(101, notification, type)
            } else {
                startForeground(101, notification)
            }
        } else if (!appVisible) {
             isServiceRunning = false
            stopSelf()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startCamera() {
        val hasAudioPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val hasCameraPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

        if (!hasAudioPermission || !hasCameraPermission) {
            isServiceRunning = false
            stopSelf()
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            // Preview Use Case
            val preview = Preview.Builder().build()
            currentPreviewView?.let { preview.setSurfaceProvider(it.surfaceProvider) }

             val recorder = Recorder.Builder().setQualitySelector(QualitySelector.from(Quality.HD)).build()
            videoCapture = VideoCapture.withOutput(recorder)

            try {
                cameraProvider.unbindAll()
                val selector = CameraSelector.Builder().requireLensFacing(currentLensFacing).build()
                cameraProvider.bindToLifecycle(this, selector, preview, videoCapture)

                val opts = MediaStoreOutputOptions.Builder(contentResolver, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                    .setContentValues(ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, "REC_${System.currentTimeMillis()}")
                        put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                        put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Security-Recorder")
                    }).build()

                recording?.stop()
                recording = videoCapture?.output?.prepareRecording(this, opts)!!
                    .withAudioEnabled().start(ContextCompat.getMainExecutor(this)) {}
            } catch (e: Exception) {
                Log.e("BackgroundVideoService", "Camera binding failed", e)
                isServiceRunning = false
                stopSelf()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    override fun onDestroy() {
        recording?.stop()
        isServiceRunning = false
        super.onDestroy()
    }
}