package app.dash.okDriver

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.ImageFormat
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Base64
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.core.Preview
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleService
import io.flutter.plugin.common.EventChannel
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class DrowsinessMonitoringService : LifecycleService() {

    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var previewUseCase: Preview? = null
    private val isCameraInitialized = AtomicBoolean(false)
    private var lastBindWasWithPreview: Boolean? = null
    private val latestJpeg = AtomicReference<ByteArray?>(null)

    private var wsClient: OkHttpClient? = null
    private var webSocket: WebSocket? = null
    private val isWsConnected = AtomicBoolean(false)
    private val isReconnecting = AtomicBoolean(false)

    private var pingTimer: Timer? = null
    private var reconnectTimer: Timer? = null
    private val backgroundExecutor = Executors.newSingleThreadScheduledExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var alarmPlayer: MediaPlayer? = null
    private val isAlarmReady = AtomicBoolean(false)
    private val isAlarmPlaying = AtomicBoolean(false)

    private var overlayView: DrowsinessOverlayView? = null
    private var windowManager: WindowManager? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // ✅ Single source of truth — reset karna zaruri hai jab bhi dialog close ho
    private var drowsyEventCount = 0

    @Volatile private var isFlutterForeground = true

    val isAssistantShowing = AtomicBoolean(false)
    private var assistantTimeoutTimer: Timer? = null
    private val ASSISTANT_TIMEOUT_MS = 30_000L

    companion object {
        var isServiceRunning = false
        var eventSink: EventChannel.EventSink? = null
        var wsUrl: String = "ws://20.204.177.196:8000/ws"

        @Volatile var currentPreviewView: PreviewView? = null
        @Volatile private var instance: DrowsinessMonitoringService? = null

        // ✅ Overlay ya BackgroundAssistantActivity dono is function ko call karte hain
        fun onAssistantClosed(driverResponded: Boolean) {
            val service = instance ?: return
            // ✅ Full reset — drowsy count + flags
            service.drowsyEventCount = 0
            service.isAssistantShowing.set(false)
            service.cancelAssistantTimeout()
            service.releaseWakeLock()
            service.resumeDetectionAfterAssistant()
            Log.d(TAG, "✅ onAssistantClosed — drowsyEventCount=0, responded=$driverResponded")
        }

        private const val TAG = "DMS_Service"
        private const val NOTIF_ID = 1002
        private const val ASSISTANT_NOTIF_ID = 1004
        private const val CHANNEL_ID = "dms_monitoring"
        private const val ASSISTANT_CHANNEL_ID = "dms_assistant"
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        ensureForeground()

        when (intent?.action) {

            "ACTION_UPDATE_VISIBILITY" -> {
                val visible = intent.getBooleanExtra("isVisible", true)
                isFlutterForeground = visible
                Log.d(TAG, "Flutter visibility: foreground=$visible")
                updateNotificationText(visible)
                val needPreview = visible && currentPreviewView != null
                if (isCameraInitialized.get() && lastBindWasWithPreview != needPreview) {
                    rebindCamera(needPreview)
                }
            }

            "ACTION_REBIND_PREVIEW" -> {
                if (isCameraInitialized.get()) rebindCamera(true)
            }

            "ACTION_PLAY_ALARM" -> playAlarmOnce()

            "ACTION_STOP_ALARM" -> stopAlarm()

            // ✅ FIXED: Flutter dialog "I'm Awake — Close" button → full reset
            "ACTION_ASSISTANT_CLOSED" -> {
                drowsyEventCount = 0
                isAssistantShowing.set(false)
                cancelAssistantTimeout()
                releaseWakeLock()
                dismissOverlay()
                resumeDetectionAfterAssistant()
                Log.d(TAG, "✅ ACTION_ASSISTANT_CLOSED — drowsyEventCount=0, detection resumed")
            }

            // ✅ NEW: Flutter onDialogClosed callback se explicit counter reset
            "ACTION_RESET_DROWSY_COUNTER" -> {
                drowsyEventCount = 0
                isAssistantShowing.set(false)
                cancelAssistantTimeout()
                Log.d(TAG, "✅ ACTION_RESET_DROWSY_COUNTER — drowsyEventCount=0, isAssistantShowing=false")
            }

            else -> {
                if (!isServiceRunning) {
                    Log.d(TAG, "DMS service starting")
                    isServiceRunning = true
                    drowsyEventCount = 0
                    isAssistantShowing.set(false)
                    isFlutterForeground = true
                    lastBindWasWithPreview = null
                    cancelAssistantTimeout()

                    val hasCamera = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.CAMERA
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED

                    if (!hasCamera) {
                        Log.e(TAG, "No camera permission")
                        isServiceRunning = false
                        stopSelf()
                        return Service.START_NOT_STICKY
                    }

                    initAlarmPlayer()
                    startCamera()
                    connectWebSocket()
                    startCaptureLoop()
                    startPingLoop()
                }
            }
        }
        return Service.START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        cancelAssistantTimeout()
        dismissOverlay()
        releaseWakeLock()
        drowsyEventCount = 0
        isAssistantShowing.set(false)
        isServiceRunning = false
        isFlutterForeground = true
        isCameraInitialized.set(false)
        lastBindWasWithPreview = null
        instance = null
        backgroundExecutor.shutdownNow()
        pingTimer?.cancel()
        reconnectTimer?.cancel()
        isWsConnected.set(false)
        try { webSocket?.close(1000, "stopped") } catch (_: Exception) {}
        webSocket = null
        wsClient?.dispatcher?.executorService?.shutdown()
        wsClient = null
        stopAlarm()
        alarmPlayer?.release()
        alarmPlayer = null
        isAlarmReady.set(false)
        cameraProvider?.unbindAll()
        super.onDestroy()
    }

    // =========================================================================
    // ✅ WindowManager Overlay
    // =========================================================================

    private fun canDrawOverlay(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(this)
        } else true
    }

    private fun showOverlay() {
        if (!canDrawOverlay()) {
            Log.w(TAG, "⚠️ No overlay permission — falling back to notification+Activity")
            showAssistantViaNotification()
            return
        }

        dismissOverlay()
        Log.d(TAG, "✅ Showing WindowManager overlay")

        mainHandler.post {
            try {
                val overlay = DrowsinessOverlayView(
                    context = this,
                    drowsyEvents = drowsyEventCount,
                    onDismiss = {
                        dismissOverlay()
                        onAssistantClosed(true) // ✅ Yahan bhi full reset hoga
                    }
                )

                val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                }

                val focusableParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    type,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.BOTTOM
                }

                windowManager?.addView(overlay, focusableParams)
                overlayView = overlay
                Log.d(TAG, "✅ Overlay added to WindowManager")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Overlay add failed: ${e.message}")
                showAssistantViaNotification()
            }
        }
    }

    private fun dismissOverlay() {
        mainHandler.post {
            try {
                val v = overlayView ?: return@post
                v.cleanup()
                windowManager?.removeView(v)
                overlayView = null
                val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                mgr.cancel(ASSISTANT_NOTIF_ID)
                Log.d(TAG, "✅ Overlay dismissed")
            } catch (e: Exception) {
                overlayView = null
                Log.w(TAG, "Overlay dismiss: ${e.message}")
            }
        }
    }

    // =========================================================================
    // WakeLock
    // =========================================================================

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock?.release()
            wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                "okdriver:drowsiness_alert"
            )
            wakeLock?.acquire(60_000L)
            Log.d(TAG, "✅ WakeLock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock: ${e.message}")
        }
    }

    internal fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
        wakeLock = null
    }

    // =========================================================================
    // Assistant timeout
    // =========================================================================

    internal fun startAssistantTimeout() {
        cancelAssistantTimeout()
        assistantTimeoutTimer = Timer()
        assistantTimeoutTimer?.schedule(object : TimerTask() {
            override fun run() {
                if (isAssistantShowing.get()) {
                    Log.w(TAG, "⚠️ Assistant timeout — full reset")
                    // ✅ Timeout par bhi counter reset
                    drowsyEventCount = 0
                    isAssistantShowing.set(false)
                    releaseWakeLock()
                    dismissOverlay()
                    resumeDetectionAfterAssistant()
                }
            }
        }, ASSISTANT_TIMEOUT_MS)
    }

    internal fun cancelAssistantTimeout() {
        assistantTimeoutTimer?.cancel()
        assistantTimeoutTimer = null
    }

    // =========================================================================
    // Notifications
    // =========================================================================

    private fun ensureForeground() {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Drowsiness Monitor", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val n = buildMonitorNotif("Starting...")
        val hasCam = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasMic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && (hasCam || hasMic)) {
            var type = 0
            if (hasCam) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            if (hasMic) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            startForeground(NOTIF_ID, n, type)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun updateNotificationText(visible: Boolean) {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Drowsiness Monitor", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val n = buildMonitorNotif(if (visible) "Active" else "🔴 Monitoring in background")
        val hasCam = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasMic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && (hasCam || hasMic)) {
            var type = 0
            if (hasCam) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            if (hasMic) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            startForeground(NOTIF_ID, n, type)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun buildMonitorNotif(text: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Drowsiness Monitoring")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true).build()

    private fun showAssistantViaNotification() {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                ASSISTANT_CHANNEL_ID, "Drowsiness Alert", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            mgr.createNotificationChannel(ch)
        }
        val activityIntent = Intent(this, BackgroundAssistantActivity::class.java).apply {
            putExtra("drowsy_events", drowsyEventCount)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            this, ASSISTANT_NOTIF_ID, activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(this, ASSISTANT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Drowsiness Detected!")
            .setContentText("Tap to talk with assistant ")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setFullScreenIntent(pi, true)
            .setContentIntent(pi)
            .setSound(null).setVibrate(null)
            .build()
        mgr.notify(ASSISTANT_NOTIF_ID, notif)
        Log.d(TAG, "✅ Fallback notification sent")
        try { startActivity(activityIntent) } catch (_: Exception) {}
    }

    // =========================================================================
    // Alarm
    // =========================================================================

    private fun initAlarmPlayer() {
        mainHandler.post {
            try {
                alarmPlayer?.release()
                alarmPlayer = null
                isAlarmReady.set(false)
                val resId = resources.getIdentifier("alarm", "raw", packageName)
                if (resId == 0) { Log.e(TAG, "❌ res/raw/alarm not found!"); return@post }
                val mp = MediaPlayer.create(this, resId) ?: return@post
                mp.isLooping = false
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
                mp.setOnCompletionListener { isAlarmPlaying.set(false) }
                alarmPlayer = mp
                isAlarmReady.set(true)
                Log.d(TAG, "✅ Alarm loaded")
            } catch (e: Exception) { Log.e(TAG, "initAlarmPlayer: ${e.message}") }
        }
    }

    fun playAlarmOnce() {
        if (isAlarmPlaying.get()) return
        mainHandler.post {
            try {
                val mp = alarmPlayer
                if (mp != null && isAlarmReady.get()) {
                    if (mp.isPlaying) return@post
                    mp.seekTo(0)
                    mp.start()
                    isAlarmPlaying.set(true)
                    Log.d(TAG, "🔊 Alarm PLAYING")
                } else {
                    initAlarmPlayer()
                }
                vibrate()
            } catch (e: Exception) {
                vibrate()
                isAlarmPlaying.set(false)
                initAlarmPlayer()
            }
        }
    }

    fun stopAlarm() {
        mainHandler.post {
            try {
                val mp = alarmPlayer ?: return@post
                if (mp.isPlaying) { mp.pause(); mp.seekTo(0) }
                isAlarmPlaying.set(false)
                Log.d(TAG, "🔇 Alarm stopped")
            } catch (e: Exception) { isAlarmPlaying.set(false) }
        }
    }

    private fun vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                    .defaultVibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500), -1))
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(VIBRATOR_SERVICE) as Vibrator).vibrate(longArrayOf(0, 500, 200, 500), -1)
            }
        } catch (e: Exception) {}
    }

    // =========================================================================
    // Camera
    // =========================================================================

    private fun startCamera() {
        ProcessCameraProvider.getInstance(this).addListener({
            try {
                cameraProvider = ProcessCameraProvider.getInstance(this).get()
                imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                    .build().also { ia ->
                        ia.setAnalyzer(Executors.newSingleThreadExecutor()) { img ->
                            try { latestJpeg.set(yuvToJpeg(img)) } catch (_: Exception) {}
                            finally { img.close() }
                        }
                    }
                isCameraInitialized.set(true)
                rebindCamera(currentPreviewView != null)
                Log.d(TAG, "✅ Camera initialized")
            } catch (e: Exception) {
                Log.e(TAG, "Camera init failed: ${e.message}")
                isServiceRunning = false
                stopSelf()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    fun rebindCamera(withPreview: Boolean) {
        ContextCompat.getMainExecutor(this).execute {
            try {
                val provider = cameraProvider ?: return@execute
                val analysis = imageAnalysis ?: return@execute
                if (lastBindWasWithPreview == withPreview) return@execute
                val selector = CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_FRONT).build()
                provider.unbindAll()
                previewUseCase = null
                if (withPreview && currentPreviewView != null) {
                    previewUseCase = Preview.Builder().build().also {
                        it.setSurfaceProvider(currentPreviewView!!.surfaceProvider)
                    }
                    provider.bindToLifecycle(this, selector, analysis, previewUseCase!!)
                    Log.d(TAG, "Camera: WITH preview")
                } else {
                    provider.bindToLifecycle(this, selector, analysis)
                    Log.d(TAG, "Camera: WITHOUT preview (background)")
                }
                lastBindWasWithPreview = withPreview
            } catch (e: Exception) { Log.e(TAG, "rebindCamera: ${e.message}") }
        }
    }

    // =========================================================================
    // YUV → JPEG
    // =========================================================================

    private fun yuvToJpeg(image: ImageProxy): ByteArray {
        val w = image.width; val h = image.height
        val yP = image.planes[0]; val uP = image.planes[1]; val vP = image.planes[2]
        val nv21 = ByteArray(w * h * 3 / 2)
        var yOff = 0; val yBuf = yP.buffer
        for (r in 0 until h) { yBuf.position(r * yP.rowStride); yBuf.get(nv21, yOff, w); yOff += w }
        var uvOff = w * h; val uBuf = uP.buffer; val vBuf = vP.buffer
        for (r in 0 until h / 2) for (c in 0 until w / 2) {
            val i = r * uP.rowStride + c * uP.pixelStride
            if (uvOff + 1 < nv21.size) {
                vBuf.position(i); nv21[uvOff++] = vBuf.get()
                uBuf.position(i); nv21[uvOff++] = uBuf.get()
            }
        }
        val out = ByteArrayOutputStream()
        YuvImage(nv21, ImageFormat.NV21, w, h, null).compressToJpeg(Rect(0, 0, w, h), 75, out)
        return out.toByteArray()
    }

    // =========================================================================
    // WebSocket
    // =========================================================================

    private fun connectWebSocket() {
        if (isReconnecting.get()) return
        isWsConnected.set(false)
        try { webSocket?.close(1000, "Reconnecting") } catch (_: Exception) {}
        webSocket = null
        wsClient = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .pingInterval(20, TimeUnit.SECONDS)
            .build()
        webSocket = wsClient?.newWebSocket(
            Request.Builder().url(wsUrl).build(),
            object : WebSocketListener() {
                override fun onOpen(ws: WebSocket, r: okhttp3.Response) {
                    Log.d(TAG, "✅ WS connected")
                    isWsConnected.set(true)
                    isReconnecting.set(false)
                }
                override fun onMessage(ws: WebSocket, text: String) {
                    mainHandler.post { eventSink?.success(text) }
                    try {
                        val obj = JSONObject(text)
                        if (obj.optString("type") == "detection_result") handleDetectionResult(obj)
                    } catch (_: Exception) {}
                }
                override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                    isWsConnected.set(false)
                    if (!isAssistantShowing.get()) scheduleReconnect()
                    else Log.d(TAG, "WS closed while assistant showing — no reconnect")
                }
                override fun onFailure(ws: WebSocket, t: Throwable, r: okhttp3.Response?) {
                    isWsConnected.set(false)
                    if (!isAssistantShowing.get()) scheduleReconnect()
                    else Log.d(TAG, "WS failure while assistant showing — no reconnect")
                }
            })
    }

    // =========================================================================
    // ✅ MAIN: handleDetectionResult
    // =========================================================================

    private fun handleDetectionResult(obj: JSONObject) {
        val data = obj.optJSONObject("data") ?: return
        val status = data.optString("status", "")
        val shouldAlert = data.optBoolean("should_alert", false) ||
                data.optInt("alert_level", 0) >= 2

        if (shouldAlert && status == "DROWSY") {
            drowsyEventCount++
            Log.d(TAG, "🚨 DROWSY event #$drowsyEventCount | isShowing=${isAssistantShowing.get()} | foreground=$isFlutterForeground")

            val canShow = isAssistantShowing.compareAndSet(false, true)

            if (canShow) {
                pauseDetectionForAssistant()
                playAlarmOnce()
                startAssistantTimeout()
                acquireWakeLock()

                if (isFlutterForeground && eventSink != null) {
                    // ── FOREGROUND: Flutter dialog ──
                    Log.d(TAG, "📱 FOREGROUND — Flutter show_dialog")
                    mainHandler.post {
                        eventSink?.success(JSONObject().apply {
                            put("type", "show_dialog")
                            put("drowsy_events", drowsyEventCount)
                        }.toString())
                    }
                    mainHandler.postDelayed({ stopAlarm() }, 2200)
                } else {
                    // ── BACKGROUND: WindowManager Overlay ──
                    Log.d(TAG, "📱 BACKGROUND — WindowManager Overlay")
                    mainHandler.postDelayed({
                        stopAlarm()
                        mainHandler.postDelayed({ showOverlay() }, 300)
                    }, 2200)
                }

            } else {
                Log.d(TAG, "⏭ Already showing — skip")
            }

        } else if (status == "ALERT") {
            // ✅ Driver awake — counter reset
            if (drowsyEventCount > 0) {
                Log.d(TAG, "✅ Status ALERT — drowsyEventCount reset to 0")
                drowsyEventCount = 0
            }
            stopAlarm()
        }
    }

    // =========================================================================
    // Loops
    // =========================================================================

    private fun scheduleReconnect() {
        if (isReconnecting.getAndSet(true)) return
        reconnectTimer?.cancel()
        reconnectTimer = Timer()
        reconnectTimer?.schedule(object : TimerTask() {
            override fun run() {
                if (isServiceRunning) { isReconnecting.set(false); connectWebSocket() }
            }
        }, 3000L)
    }

    private fun startPingLoop() {
        pingTimer?.cancel()
        pingTimer = Timer()
        pingTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (isWsConnected.get()) {
                    try {
                        val ok = webSocket?.send(JSONObject(mapOf("type" to "ping")).toString())
                        if (ok == false) { isWsConnected.set(false); scheduleReconnect() }
                    } catch (_: Exception) {}
                }
            }
        }, 15000L, 15000L)
    }

    private fun startCaptureLoop() {
        backgroundExecutor.scheduleAtFixedRate({
            val bytes = latestJpeg.getAndSet(null) ?: return@scheduleAtFixedRate
            if (!isWsConnected.get()) return@scheduleAtFixedRate
            val ws = webSocket ?: return@scheduleAtFixedRate
            try {
                val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                val ok = ws.send(JSONObject().apply {
                    put("type", "frame")
                    put("data", "data:image/jpeg;base64,$b64")
                }.toString())
                if (!ok) { isWsConnected.set(false); scheduleReconnect() }
            } catch (_: Exception) {}
        }, 1000L, 900L, TimeUnit.MILLISECONDS)
    }

    // =========================================================================
    // Pause / Resume detection
    // =========================================================================

    private fun pauseDetectionForAssistant() {
        Log.d(TAG, "⏸ Pausing detection/WebSocket for assistant")
        try {
            pingTimer?.cancel(); pingTimer = null
            reconnectTimer?.cancel(); reconnectTimer = null
            isReconnecting.set(false)
            isWsConnected.set(false)
            try { webSocket?.close(1000, "assistant_active") } catch (_: Exception) {}
            webSocket = null
        } catch (_: Exception) {}
    }

    internal fun resumeDetectionAfterAssistant() {
        if (!isServiceRunning) return
        if (isAssistantShowing.get()) {
            Log.d(TAG, "resumeDetectionAfterAssistant: assistant still showing, skip")
            return
        }
        Log.d(TAG, "▶ Resuming detection/WebSocket after assistant")
        connectWebSocket()
        startPingLoop()
    }

    override fun onBind(intent: Intent): IBinder? = super.onBind(intent)
}