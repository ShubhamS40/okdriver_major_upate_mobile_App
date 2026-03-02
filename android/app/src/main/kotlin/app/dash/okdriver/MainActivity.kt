package app.dash.okDriver

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import android.annotation.SuppressLint
import android.provider.MediaStore

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.okdriver/background_recording"
    private val RECORDER_CHANNEL = "com.example.okdriver/recorder"
    private var methodChannel: MethodChannel? = null

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
                "initializeBackgroundRecording" -> initializeBackgroundRecording(result)
                "startBackgroundRecording" -> startBackgroundRecording(result)
                "stopBackgroundRecording" -> stopBackgroundRecording(result)
                "isRecording" -> result.success(isRecording)
                "getRecordingDuration" -> {
                    val duration = if (isRecording) {
                        (System.currentTimeMillis() - recordingStartTime) / 1000
                    } else 0
                    result.success(duration)
                }
                "getCurrentVideoPath" -> result.success(currentVideoFile?.absolutePath)
                else -> result.notImplemented()
            }
        }

        // ✅ Dashcam camera preview factory (existing)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("camera_preview_view", CameraPreviewFactory())

        // ✅ DMS camera preview factory
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("dms_camera_preview_view", DmsCameraPreviewFactory(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDER_CHANNEL)
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, BackgroundRecordingService::class.java)
                when (call.method) {
                    "startService" -> {
                        val cameraType = call.argument<String>("cameraType")
                        val segmentMinutes = call.argument<Int>("segmentMinutes") ?: 10
                        val recordAudio = call.argument<Boolean>("recordAudio") ?: true

                        BackgroundRecordingService.currentLensFacing =
                            if (cameraType == "back") CameraSelector.LENS_FACING_BACK
                            else CameraSelector.LENS_FACING_FRONT

                        BackgroundRecordingService.recordAudioEnabled = recordAudio

                        val serviceIntent = intentWithNewVideoPath(intent).apply {
                            putExtra("segmentMinutes", segmentMinutes)
                            putExtra("recordAudio", recordAudio)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "stopService" -> {
                        stopService(intent)
                        result.success(true)
                    }
                    "switchCamera" -> {
                        intent.action = "ACTION_SWITCH_CAMERA"
                        startService(intent)
                        result.success(true)
                    }
                    "updateVisibility" -> {
                        val isVisible = call.argument<Boolean>("visible") ?: true
                        intent.action = "ACTION_UPDATE_VISIBILITY"
                        intent.putExtra("isVisible", isVisible)
                        startService(intent)
                        result.success(isVisible)
                    }
                    "isRunning" -> result.success(BackgroundRecordingService.isServiceRunning)
                    else -> result.notImplemented()
                }
            }

        // =====================================================================
        // ✅ DMS MethodChannel
        // =====================================================================
        val dmsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.okdriver/drowsiness"
        )
        dmsChannel.setMethodCallHandler { call, result ->
            val intent = Intent(this, DrowsinessMonitoringService::class.java)
            when (call.method) {

                "startService" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopService" -> {
                    stopService(intent)
                    DrowsinessMonitoringService.isServiceRunning = false
                    result.success(true)
                }

                "isRunning" -> result.success(DrowsinessMonitoringService.isServiceRunning)

                "updateVisibility" -> {
                    val isVisible = call.argument<Boolean>("visible") ?: true
                    if (DrowsinessMonitoringService.isServiceRunning) {
                        intent.action = "ACTION_UPDATE_VISIBILITY"
                        intent.putExtra("isVisible", isVisible)
                        startService(intent)
                    }
                    result.success(true)
                }

                "rebindPreview" -> {
                    if (DrowsinessMonitoringService.isServiceRunning) {
                        intent.action = "ACTION_REBIND_PREVIEW"
                        startService(intent)
                    }
                    result.success(true)
                }

                "playAlarm" -> {
                    if (DrowsinessMonitoringService.isServiceRunning) {
                        intent.action = "ACTION_PLAY_ALARM"
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopAlarm" -> {
                    if (DrowsinessMonitoringService.isServiceRunning) {
                        intent.action = "ACTION_STOP_ALARM"
                        startService(intent)
                    }
                    result.success(true)
                }

                "checkOverlayPermission" -> {
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        android.provider.Settings.canDrawOverlays(this)
                    } else true
                    result.success(canDraw)
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                        !android.provider.Settings.canDrawOverlays(this)
                    ) {
                        val permIntent = Intent(
                            android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        )
                        startActivity(permIntent)
                    }
                    result.success(true)
                }

                "assistantClosed" -> {
                    if (DrowsinessMonitoringService.isServiceRunning) {
                        intent.action = "ACTION_ASSISTANT_CLOSED"
                        startService(intent)
                    }
                    result.success(true)
                }

                // ✅ NEW: Flutter dialog band hone par native drowsy counter reset
                "resetDrowsyCounter" -> {
                    if (DrowsinessMonitoringService.isServiceRunning) {
                        intent.action = "ACTION_RESET_DROWSY_COUNTER"
                        startService(intent)
                        Log.d("MainActivity", "✅ resetDrowsyCounter → ACTION_RESET_DROWSY_COUNTER sent")
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // =====================================================================
        // ✅ DMS EventChannel — streams detection results to Flutter
        // =====================================================================
        val dmsEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.okdriver/drowsiness_frames"
        )
        dmsEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                DrowsinessMonitoringService.eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                DrowsinessMonitoringService.eventSink = null
            }
        })
    }

    private fun intentWithNewVideoPath(intent: Intent): Intent {
        val videoDir = File(getExternalFilesDir(null), "dashcam_videos")
        if (!videoDir.exists()) videoDir.mkdirs()
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        currentVideoFile = File(videoDir, "dashcam_$timestamp.mp4")
        isRecording = true
        recordingStartTime = System.currentTimeMillis()
        intent.putExtra("videoPath", currentVideoFile?.absolutePath)
        intent.putExtra("startTime", recordingStartTime)
        return intent
    }

    private fun initializeBackgroundRecording(result: MethodChannel.Result) {
        try {
            if (!hasRequiredPermissions()) {
                result.error("PERMISSION_DENIED", "Camera and storage permissions required", null)
                return
            }
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
            val videoDir = File(getExternalFilesDir(null), "dashcam_videos")
            if (!videoDir.exists()) videoDir.mkdirs()
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            currentVideoFile = File(videoDir, "dashcam_$timestamp.mp4")
            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            val intent = Intent(this, BackgroundRecordingService::class.java).apply {
                putExtra("videoPath", currentVideoFile?.absolutePath)
                putExtra("startTime", recordingStartTime)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
            else startService(intent)
            result.success(
                mapOf(
                    "success" to true,
                    "filePath" to currentVideoFile?.absolutePath,
                    "message" to "Recording started"
                )
            )
        } catch (e: Exception) {
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
            stopService(Intent(this, BackgroundRecordingService::class.java))
            result.success(
                mapOf(
                    "success" to true,
                    "filePath" to currentVideoFile?.absolutePath,
                    "message" to "Recording stopped"
                )
            )
        } catch (e: Exception) {
            result.error("STOP_ERROR", "Failed to stop recording", e.message)
        }
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
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(
                    this, Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(
                    this, Manifest.permission.WRITE_EXTERNAL_STORAGE
                ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val CHANNEL_ID = "dashcam_recording_channel"
        const val NOTIFICATION_ID = 1001
    }
}

// =============================================================================
// BackgroundRecordingService — dashcam recording (unchanged)
// =============================================================================
class BackgroundRecordingService : LifecycleService() {
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null
    private var cameraProvider: ProcessCameraProvider? = null

    private var segmentDurationMs: Long = 10 * 60_000L
    private var segmentTimer: java.util.Timer? = null
    private val segmentUris: java.util.ArrayDeque<android.net.Uri> = java.util.ArrayDeque()

    companion object {
        var isServiceRunning = false
        var currentLensFacing = CameraSelector.LENS_FACING_FRONT
        var currentPreviewView: PreviewView? = null
        @JvmStatic var recordAudioEnabled: Boolean = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            "ACTION_SWITCH_CAMERA" -> {
                currentLensFacing =
                    if (currentLensFacing == CameraSelector.LENS_FACING_FRONT)
                        CameraSelector.LENS_FACING_BACK
                    else CameraSelector.LENS_FACING_FRONT
                recording?.stop()
                recording = null
                startCamera()
            }
            "ACTION_UPDATE_VISIBILITY" -> {
                val isVisible = intent.getBooleanExtra("isVisible", true)
                updateNotification(isVisible)
            }
            else -> if (!isServiceRunning) {
                val minutes = intent?.getIntExtra("segmentMinutes", 10) ?: 10
                segmentDurationMs = minutes.coerceAtLeast(1) * 60_000L
                recordAudioEnabled = intent?.getBooleanExtra("recordAudio", true) ?: true

                isServiceRunning = true
                updateNotification(true)
                startCamera()
            }
        }
        return START_STICKY
    }

    private fun updateNotification(appVisible: Boolean) {
        val hasAudio = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        val hasCamera = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        val channelId = "dark_recorder"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance =
                if (appVisible) NotificationManager.IMPORTANCE_MIN
                else NotificationManager.IMPORTANCE_DEFAULT
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Recorder", importance)
            )
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(if (appVisible) "Monitor Active" else "🔴 Recording")
            .setContentText("System secure capture in progress...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true).build()

        if (hasAudio && hasCamera) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val type =
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                startForeground(MainActivity.NOTIFICATION_ID, notification, type)
            } else {
                startForeground(MainActivity.NOTIFICATION_ID, notification)
            }
        } else {
            isServiceRunning = false
            stopSelf()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startCamera() {
        val hasAudio = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        val hasCamera = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasAudio || !hasCamera) {
            isServiceRunning = false
            stopSelf()
            return
        }

        ProcessCameraProvider.getInstance(this).addListener({
            cameraProvider = ProcessCameraProvider.getInstance(this).get()

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            imageAnalysis.setAnalyzer(
                ContextCompat.getMainExecutor(this)
            ) { imageProxy -> imageProxy.close() }

            val recorder = Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.HD))
                .build()
            videoCapture = VideoCapture.withOutput(recorder)

            try {
                cameraProvider?.unbindAll()
                val selector =
                    CameraSelector.Builder().requireLensFacing(currentLensFacing).build()

                if (currentPreviewView != null) {
                    val preview = Preview.Builder().build()
                    preview.setSurfaceProvider(currentPreviewView!!.surfaceProvider)
                    cameraProvider?.bindToLifecycle(
                        this, selector, preview, imageAnalysis, videoCapture!!
                    )
                } else {
                    cameraProvider?.bindToLifecycle(this, selector, imageAnalysis, videoCapture!!)
                }

                startNewSegment()
            } catch (e: Exception) {
                Log.e("BackgroundRecordingService", "Camera binding failed", e)
                isServiceRunning = false
                stopSelf()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    override fun onDestroy() {
        segmentTimer?.cancel()
        segmentTimer = null
        recording?.stop()
        recording = null
        cameraProvider?.unbindAll()
        isServiceRunning = false
        super.onDestroy()
    }

    private fun startNewSegment() {
        val vc = videoCapture ?: return

        segmentTimer?.cancel()
        segmentTimer = java.util.Timer()
        segmentTimer?.schedule(object : java.util.TimerTask() {
            override fun run() {
                ContextCompat.getMainExecutor(this@BackgroundRecordingService).execute {
                    if (isServiceRunning) {
                        startNewSegment()
                    }
                }
            }
        }, segmentDurationMs)

        val displayName = "REC_${System.currentTimeMillis()}"
        val opts = MediaStoreOutputOptions.Builder(
            contentResolver, MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        ).setContentValues(ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/OKDriver-Dashcam")
        }).build()

        try { recording?.stop() } catch (_: Exception) {}

        val output = vc.output
        var recordingBuilder = output.prepareRecording(this, opts)
        if (recordAudioEnabled) {
            recordingBuilder = recordingBuilder.withAudioEnabled()
        }

        recording = recordingBuilder.start(ContextCompat.getMainExecutor(this)) { event ->
            Log.d("BackgroundRecordingService", "Recording event: $event")
            if (event is androidx.camera.video.VideoRecordEvent.Finalize) {
                val uri = event.outputResults.outputUri
                handleSegmentFinalized(uri)
            }
        }
    }

    private fun handleSegmentFinalized(uri: android.net.Uri) {
        if (uri == android.net.Uri.EMPTY) return
        segmentUris.addLast(uri)
        if (segmentUris.size > 3) {
            val oldest = segmentUris.removeFirst()
            try {
                contentResolver.delete(oldest, null, null)
                Log.d("BackgroundRecordingService", "Deleted oldest segment: $oldest")
            } catch (e: Exception) {
                Log.e("BackgroundRecordingService", "Failed to delete old segment: $e")
            }
        }
    }
}

// =============================================================================
// Dashcam Camera Preview (existing — unchanged)
// =============================================================================
class CameraPreviewView(context: Context) : PlatformView {
    private val previewView: PreviewView = PreviewView(context)

    init {
        BackgroundRecordingService.currentPreviewView = previewView
    }

    override fun getView(): View = previewView
    override fun dispose() {
        BackgroundRecordingService.currentPreviewView = null
    }
}

class CameraPreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CameraPreviewView(context)
    }
}

// =============================================================================
// ✅ DMS Camera Preview — sets DrowsinessMonitoringService.currentPreviewView
// =============================================================================
class DmsCameraPreviewView(
    context: Context,
    private val activity: MainActivity
) : PlatformView {
    private val previewView: PreviewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FIT_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        setBackgroundColor(android.graphics.Color.BLACK)
    }

    init {
        DrowsinessMonitoringService.currentPreviewView = previewView
        if (DrowsinessMonitoringService.isServiceRunning) {
            val intent = Intent(context, DrowsinessMonitoringService::class.java).apply {
                action = "ACTION_REBIND_PREVIEW"
            }
            context.startService(intent)
        }
    }

    override fun getView(): View = previewView

    override fun dispose() {
        DrowsinessMonitoringService.currentPreviewView = null
    }
}

class DmsCameraPreviewFactory(
    private val activity: MainActivity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return DmsCameraPreviewView(context, activity)
    }
}