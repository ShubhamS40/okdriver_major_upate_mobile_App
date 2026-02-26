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
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Base64
import android.util.Log
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

    // ── Camera ────────────────────────────────────────────────────────────────
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var previewUseCase: Preview? = null
    private val isCameraInitialized = AtomicBoolean(false)
    private var lastBindWasWithPreview: Boolean? = null   // track state to avoid redundant rebinds

    // ── Frame buffer ──────────────────────────────────────────────────────────
    private val latestJpeg = AtomicReference<ByteArray?>(null)

    // ── WebSocket ─────────────────────────────────────────────────────────────
    private var wsClient: OkHttpClient? = null
    private var webSocket: WebSocket? = null
    private val isWsConnected = AtomicBoolean(false)
    private val isReconnecting = AtomicBoolean(false)

    // ── Timers ────────────────────────────────────────────────────────────────
    private var pingTimer: Timer? = null
    private var reconnectTimer: Timer? = null
    private val backgroundExecutor = Executors.newSingleThreadScheduledExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Alarm ─────────────────────────────────────────────────────────────────
    private var alarmPlayer: MediaPlayer? = null
    private val isAlarmReady = AtomicBoolean(false)
    private val isAlarmPlaying = AtomicBoolean(false)  // prevent stopAlarm spam

    // ── Overlay ───────────────────────────────────────────────────────────────
    private var overlayView: DrowsinessOverlayView? = null
    private var windowManager: WindowManager? = null

    // ── Detection state ───────────────────────────────────────────────────────
    private var drowsyEventCount = 0
    private var lastDialogTimestamp = 0L
    private val DIALOG_COOLDOWN_MS = 25_000L

    // ─────────────────────────────────────────────────────────────────────────
    companion object {
        var isServiceRunning = false
        var eventSink: EventChannel.EventSink? = null
        var wsUrl: String = "ws://20.204.177.196:8000/ws"

        @Volatile var currentPreviewView: PreviewView? = null
        @Volatile var isAssistantShowing = false

        fun onAssistantClosed(driverResponded: Boolean) {
            isAssistantShowing = false
            Log.d(TAG, "Assistant closed. responded=$driverResponded")
        }

        private const val TAG = "DMS_Service"
        private const val NOTIF_ID = 1002
        private const val ALERT_NOTIF_ID = 1003
        private const val CHANNEL_ID = "dms_monitoring"
        private const val ALERT_CHANNEL_ID = "dms_alerts"
    }

    // =========================================================================
    // onStartCommand
    // =========================================================================

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        ensureForeground()

        when (intent?.action) {

            "ACTION_UPDATE_VISIBILITY" -> {
                val visible = intent.getBooleanExtra("isVisible", true)
                updateNotificationText(visible)
                // Only rebind if preview state actually changes
                val needPreview = visible && currentPreviewView != null
                if (isCameraInitialized.get() && lastBindWasWithPreview != needPreview) {
                    rebindCamera(needPreview)
                }
            }

            "ACTION_REBIND_PREVIEW" -> {
                if (isCameraInitialized.get()) rebindCamera(true)
            }

            "ACTION_PLAY_ALARM" -> playAlarmOnce()
            "ACTION_STOP_ALARM"  -> stopAlarm()

            "ACTION_DISMISS_OVERLAY" -> dismissOverlay()

            else -> {
                if (!isServiceRunning) {
                    Log.d(TAG, "DMS service starting")
                    isServiceRunning    = true
                    drowsyEventCount    = 0
                    lastDialogTimestamp = 0L
                    isAssistantShowing  = false
                    lastBindWasWithPreview = null

                    val hasCamera = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.CAMERA
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED

                    if (!hasCamera) {
                        Log.e(TAG, "No camera permission")
                        isServiceRunning = false; stopSelf()
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

    // =========================================================================
    // Notifications
    // =========================================================================

    private fun ensureForeground() {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Drowsiness Monitor",
                    NotificationManager.IMPORTANCE_MIN)
            )
        }
        val n = buildMonitorNotif("Starting...")
        val hasCam = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && hasCam) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun updateNotificationText(visible: Boolean) {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Drowsiness Monitor",
                    if (visible) NotificationManager.IMPORTANCE_MIN
                    else NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val n = buildMonitorNotif(if (visible) "Active" else "🔴 Monitoring in background")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
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

    // =========================================================================
    // Alarm  —  res/raw/alarm.wav
    // =========================================================================

    private fun initAlarmPlayer() {
        mainHandler.post {
            try {
                alarmPlayer?.release(); alarmPlayer = null; isAlarmReady.set(false)

                val resId = resources.getIdentifier("alarm", "raw", packageName)
                if (resId == 0) {
                    Log.e(TAG, "❌ res/raw/alarm not found! Copy alarm.wav → android/app/src/main/res/raw/alarm.wav")
                    return@post
                }

                val mp = MediaPlayer.create(this, resId) ?: run {
                    Log.e(TAG, "❌ MediaPlayer.create returned null"); return@post
                }
                mp.isLooping = false
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                // Max alarm volume
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_ALARM,
                    am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)

                mp.setOnCompletionListener { isAlarmPlaying.set(false) }
                alarmPlayer = mp; isAlarmReady.set(true)
                Log.d(TAG, "✅ Alarm loaded from res/raw/alarm")
            } catch (e: Exception) {
                Log.e(TAG, "initAlarmPlayer: ${e.message}")
            }
        }
    }

    fun playAlarmOnce() {
        if (isAlarmPlaying.get()) return   // ← guard: already playing, skip
        mainHandler.post {
            try {
                val mp = alarmPlayer
                if (mp != null && isAlarmReady.get()) {
                    if (mp.isPlaying) return@post
                    mp.seekTo(0); mp.start()
                    isAlarmPlaying.set(true)
                    Log.d(TAG, "🔊 Alarm PLAYING")
                } else {
                    Log.w(TAG, "Alarm not ready — vibrating")
                    initAlarmPlayer()
                }
                vibrate()
            } catch (e: Exception) {
                Log.e(TAG, "playAlarmOnce: ${e.message}")
                vibrate(); isAlarmPlaying.set(false); initAlarmPlayer()
            }
        }
    }

    fun stopAlarm() {
        if (!isAlarmPlaying.get()) return  // ← guard: not playing, skip (fixes spam)
        mainHandler.post {
            try {
                val mp = alarmPlayer ?: return@post
                if (mp.isPlaying) { mp.pause(); mp.seekTo(0) }
                isAlarmPlaying.set(false)
                Log.d(TAG, "🔇 Alarm stopped")
            } catch (e: Exception) {
                isAlarmPlaying.set(false)
            }
        }
    }

    private fun vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                    .defaultVibrator
                    .vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500), -1))
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(VIBRATOR_SERVICE) as Vibrator)
                    .vibrate(longArrayOf(0, 500, 200, 500), -1)
            }
        } catch (e: Exception) { Log.w(TAG, "vibrate: ${e.message}") }
    }

    // =========================================================================
    // Camera  —  guard rebind to avoid CLOSING/REOPENING loop
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
                            try { latestJpeg.set(yuvToJpeg(img)) }
                            catch (_: Exception) {}
                            finally { img.close() }
                        }
                    }

                isCameraInitialized.set(true)
                rebindCamera(currentPreviewView != null)
                Log.d(TAG, "✅ Camera initialized")
            } catch (e: Exception) {
                Log.e(TAG, "Camera init failed: ${e.message}")
                isServiceRunning = false; stopSelf()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    fun rebindCamera(withPreview: Boolean) {
        ContextCompat.getMainExecutor(this).execute {
            try {
                val provider = cameraProvider ?: return@execute
                val analysis = imageAnalysis ?: return@execute

                // ✅ KEY FIX: skip if nothing changed — prevents CLOSING/REOPENING loop
                if (lastBindWasWithPreview == withPreview) {
                    Log.d(TAG, "Camera bind unchanged (withPreview=$withPreview) — skipping")
                    return@execute
                }

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

            } catch (e: Exception) {
                Log.e(TAG, "rebindCamera: ${e.message}")
            }
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
                    isWsConnected.set(true); isReconnecting.set(false)
                }
                override fun onMessage(ws: WebSocket, text: String) {
                    mainHandler.post { eventSink?.success(text) }
                    try {
                        val obj = JSONObject(text)
                        if (obj.optString("type") == "detection_result") handleDetectionResult(obj)
                    } catch (_: Exception) {}
                }
                override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                    isWsConnected.set(false); scheduleReconnect()
                }
                override fun onFailure(ws: WebSocket, t: Throwable, r: okhttp3.Response?) {
                    isWsConnected.set(false); scheduleReconnect()
                }
            })
    }

    // =========================================================================
    // Detection handler
    // =========================================================================

    private fun handleDetectionResult(obj: JSONObject) {
        val data = obj.optJSONObject("data") ?: return
        val status = data.optString("status", "")
        val shouldAlert = data.optBoolean("should_alert", false) ||
                          data.optInt("alert_level", 0) >= 2

        if (shouldAlert && status == "DROWSY") {
            drowsyEventCount++
            Log.d(TAG, "🚨 DROWSY event #$drowsyEventCount | isShowing=$isAssistantShowing")

            // Always alarm on every drowsy event
            playAlarmOnce()
            showAlertNotification()

            val now = System.currentTimeMillis()
            val cooldownOk = (now - lastDialogTimestamp) > DIALOG_COOLDOWN_MS

            if (!isAssistantShowing && cooldownOk) {
                isAssistantShowing  = true
                lastDialogTimestamp = now

                // Notify Flutter (shows Flutter dialog if app is foreground)
                mainHandler.post {
                    val evt = JSONObject().apply {
                        put("type", "show_dialog"); put("drowsy_events", drowsyEventCount)
                    }
                    eventSink?.success(evt.toString())
                }

                // Alarm 2s → stop → show overlay
                mainHandler.postDelayed({
                    stopAlarm()
                    mainHandler.postDelayed({ showOverlay() }, 300)
                }, 2000)
            } else {
                Log.d(TAG, "Overlay skipped: showing=$isAssistantShowing cooldown=$cooldownOk")
            }

        } else if (status == "ALERT") {
            drowsyEventCount = 0
            stopAlarm()
        }
    }

    // =========================================================================
    // WindowManager OVERLAY  —  works on MIUI without any special permission
    // when the app is a foreground service (already satisfies the requirement)
    // =========================================================================

    private fun showOverlay() {
        mainHandler.post {
            try {
                // Only one overlay at a time
                if (overlayView != null) {
                    Log.d(TAG, "Overlay already visible")
                    return@post
                }

                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager = wm

                val view = DrowsinessOverlayView(this, drowsyEventCount) {
                    // onDismiss callback
                    dismissOverlay()
                }
                overlayView = view

                val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = android.view.Gravity.BOTTOM
                }

                wm.addView(view, params)
                Log.d(TAG, "✅ Overlay shown")

                // Auto-dismiss after 90s if driver doesn't respond
                mainHandler.postDelayed({
                    if (overlayView != null) {
                        Log.d(TAG, "Overlay auto-dismissed (timeout)")
                        dismissOverlay()
                    }
                }, 90_000)

            } catch (e: Exception) {
                Log.e(TAG, "showOverlay failed: ${e.message}", e)
                isAssistantShowing = false
                // Fallback: try Activity launch
                tryLaunchActivity()
            }
        }
    }

    private fun dismissOverlay() {
        mainHandler.post {
            try {
                val v = overlayView ?: return@post
                v.cleanup()
                windowManager?.removeView(v)
            } catch (e: Exception) {
                Log.w(TAG, "dismissOverlay: ${e.message}")
            } finally {
                overlayView = null
                windowManager = null
                isAssistantShowing = false
                Log.d(TAG, "✅ Overlay dismissed")
            }
        }
    }

    // Fallback if overlay fails (e.g. no SYSTEM_ALERT_WINDOW permission yet)
    private fun tryLaunchActivity() {
        try {
            val i = Intent(this, BackgroundAssistantActivity::class.java).apply {
                putExtra("drowsy_events", drowsyEventCount)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(i)
        } catch (e: Exception) {
            Log.e(TAG, "Fallback activity launch failed: ${e.message}")
            isAssistantShowing = false
        }
    }

    // =========================================================================
    // Alert notification
    // =========================================================================

    private fun showAlertNotification() {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(ALERT_CHANNEL_ID, "DMS Alerts",
                    NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val tapIntent = Intent(this, BackgroundAssistantActivity::class.java).apply {
            putExtra("drowsy_events", drowsyEventCount)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(this, 1, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        mgr.notify(ALERT_NOTIF_ID,
            NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setContentTitle("⚠️ Drowsiness Detected!")
                .setContentText("Tap to respond — Driver check-in required")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setAutoCancel(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE)
                .setContentIntent(pi)
                .setFullScreenIntent(pi, true)   // ← shows heads-up even on MIUI
                .build()
        )
    }

    // =========================================================================
    // Loops
    // =========================================================================

    private fun scheduleReconnect() {
        if (isReconnecting.getAndSet(true)) return
        reconnectTimer?.cancel(); reconnectTimer = Timer()
        reconnectTimer?.schedule(object : TimerTask() {
            override fun run() {
                if (isServiceRunning) { isReconnecting.set(false); connectWebSocket() }
            }
        }, 3000L)
    }

    private fun startPingLoop() {
        pingTimer?.cancel(); pingTimer = Timer()
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
                    put("type", "frame"); put("data", "data:image/jpeg;base64,$b64")
                }.toString())
                if (!ok) { isWsConnected.set(false); scheduleReconnect() }
            } catch (_: Exception) {}
        }, 1000L, 900L, TimeUnit.MILLISECONDS)
    }

    // =========================================================================
    // onDestroy
    // =========================================================================

    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        dismissOverlay()
        drowsyEventCount    = 0
        isAssistantShowing  = false
        isServiceRunning    = false
        isCameraInitialized.set(false)
        lastBindWasWithPreview = null
        backgroundExecutor.shutdownNow()
        pingTimer?.cancel(); reconnectTimer?.cancel()
        isWsConnected.set(false)
        try { webSocket?.close(1000, "stopped") } catch (_: Exception) {}
        webSocket = null
        wsClient?.dispatcher?.executorService?.shutdown(); wsClient = null
        stopAlarm()
        alarmPlayer?.release(); alarmPlayer = null; isAlarmReady.set(false)
        cameraProvider?.unbindAll()
        super.onDestroy()
    }

    override fun onBind(intent: Intent): IBinder? = super.onBind(intent)
}