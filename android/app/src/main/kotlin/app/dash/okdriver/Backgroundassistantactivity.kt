package app.dash.okDriver

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.*
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.widget.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit

class BackgroundAssistantActivity : Activity() {

    companion object {
        private const val TAG = "BgAssistant"

        fun start(context: Context, drowsyEvents: Int = 0) {
            context.startActivity(
                Intent(context, BackgroundAssistantActivity::class.java).apply {
                    putExtra("drowsy_events", drowsyEvents)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
            )
        }
    }

    // ── UI refs ───────────────────────────────────────────────────────────────
    private lateinit var statusText: TextView
    private lateinit var responseText: TextView
    private lateinit var micButton: ImageButton
    private lateinit var pulseOrb: View

    // ── Audio ─────────────────────────────────────────────────────────────────
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechRecognizer: SpeechRecognizer? = null

    // ── State ─────────────────────────────────────────────────────────────────
    private var isListening = false
    private var conversationActive = true
    private val mainHandler = Handler(Looper.getMainLooper())
    private val drowsyEvents by lazy { intent.getIntExtra("drowsy_events", 0) }

    // ── HTTP ──────────────────────────────────────────────────────────────────
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // ═════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ✅ Show over lock screen & wake device
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.75f)

        Log.d(TAG, "✅ BackgroundAssistantActivity CREATED (events=$drowsyEvents)")

        buildUI()
        initTts()

        // TTS check-in after 300ms (alarm already played in service)
        mainHandler.postDelayed({
            if (conversationActive) speakCheckIn()
        }, 300)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent — already showing, ignoring")
    }

    override fun onBackPressed() {
        // Block back button — driver must respond
    }

    override fun onDestroy() {
        Log.d(TAG, "BackgroundAssistantActivity onDestroy")
        conversationActive = false
        mainHandler.removeCallbacksAndMessages(null)
        stopListening()
        tts?.stop()
        tts?.shutdown()
        speechRecognizer?.destroy()
        httpClient.dispatcher.cancelAll()
        DrowsinessMonitoringService.onAssistantClosed(true)
        super.onDestroy()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI
    // ═════════════════════════════════════════════════════════════════════════

    private fun buildUI() {
        val root = FrameLayout(this)

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(28), dp(24), dp(28))
            background = roundedBg(Color.parseColor("#F2000000"), dp(24).toFloat())
            elevation = 20f
        }

        // ── Handle bar ───────────────────────────────────────────────────────
        card.addView(
            View(this).apply { background = roundedBg(Color.parseColor("#44FFFFFF"), dp(3).toFloat()) },
            LinearLayout.LayoutParams(dp(36), dp(4)).also { it.bottomMargin = dp(20) }
        )

        // ── Pulsing orb ──────────────────────────────────────────────────────
        pulseOrb = View(this).apply {
            background = roundedBg(Color.parseColor("#CCFF3B30"), dp(50).toFloat())
        }
        card.addView(pulseOrb, LinearLayout.LayoutParams(dp(88), dp(88)).also {
            it.gravity = Gravity.CENTER_HORIZONTAL
            it.bottomMargin = dp(16)
        })
        animateOrb()

        // ── Alert title ──────────────────────────────────────────────────────
        statusText = TextView(this).apply {
            text = "⚠  Drowsiness Detected!"
            textSize = 15f
            setTextColor(Color.parseColor("#FFFF3B30"))
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        card.addView(statusText, wrapLP().also {
            it.gravity = Gravity.CENTER_HORIZONTAL
            it.bottomMargin = dp(14)
        })

        // ── AI response box ──────────────────────────────────────────────────
        responseText = TextView(this).apply {
            text = "Initializing..."
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = roundedBg(Color.parseColor("#1FFFFFFF"), dp(14).toFloat())
            setPadding(dp(18), dp(16), dp(18), dp(16))
            minLines = 2
        }
        card.addView(responseText, fillLP().also { it.bottomMargin = dp(20) })

        // ── Button row ───────────────────────────────────────────────────────
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        // Mic button
        micButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            background = roundedBg(Color.parseColor("#2AFFFFFF"), dp(44).toFloat())
            setPadding(dp(18), dp(18), dp(18), dp(18))
            setOnClickListener { if (!isListening) startListeningNow() }
        }
        row.addView(micButton, LinearLayout.LayoutParams(dp(88), dp(88)).also { it.marginEnd = dp(12) })

        // "I'm Fine" button
        val fineBtn = Button(this).apply {
            text = "✓  I'm Fine"
            setTextColor(Color.parseColor("#30D158"))
            background = roundedBg(Color.parseColor("#2030D158"), dp(22).toFloat())
            textSize = 13f
            setPadding(dp(16), dp(10), dp(16), dp(10))
            setOnClickListener { quickResponse("I'm fine, I am alert now") }
        }
        row.addView(fineBtn, wrapLP().also { it.marginEnd = dp(10) })

        // "Need Help" button
        val helpBtn = Button(this).apply {
            text = "⚠  Need Help"
            setTextColor(Color.parseColor("#FF3B30"))
            background = roundedBg(Color.parseColor("#20FF3B30"), dp(22).toFloat())
            textSize = 13f
            setPadding(dp(16), dp(10), dp(16), dp(10))
            setOnClickListener { quickResponse("I need help, I am very drowsy") }
        }
        row.addView(helpBtn, wrapLP())
        card.addView(row, wrapLP().also {
            it.gravity = Gravity.CENTER_HORIZONTAL
            it.bottomMargin = dp(18)
        })

        // ── Close button ─────────────────────────────────────────────────────
        val closeBtn = Button(this).apply {
            text = "✓  I'm Awake — Close"
            setTextColor(Color.WHITE)
            background = roundedBg(Color.parseColor("#1A7F37"), dp(14).toFloat())
            textSize = 15f
            setOnClickListener { finishSession() }
        }
        card.addView(closeBtn, fillLP())

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        )
        setContentView(root)
    }

    private fun animateOrb() {
        val r = object : Runnable {
            var scale = 1f; var grow = true
            override fun run() {
                if (!conversationActive) return
                scale = if (grow) (scale + 0.04f).coerceAtMost(1.25f) else (scale - 0.04f).coerceAtLeast(0.85f)
                if (scale >= 1.25f) grow = false
                if (scale <= 0.85f) grow = true
                pulseOrb.scaleX = scale; pulseOrb.scaleY = scale
                mainHandler.postDelayed(this, 70)
            }
        }
        mainHandler.post(r)
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TTS
    // ═════════════════════════════════════════════════════════════════════════

    private fun initTts() {
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale.US
                tts?.setSpeechRate(0.9f)
                Log.d(TAG, "✅ TTS ready")
            } else {
                Log.e(TAG, "TTS init failed: $status")
            }
        }
    }

    private fun speakCheckIn() {
        val msg = "Driver, are you alright? Please respond."
        updateStatus("🗣  Checking in...")
        updateResponse(msg)
        speakThen(msg) {
            if (conversationActive) {
                mainHandler.postDelayed({ startListeningNow() }, 400)
            }
        }
    }

    private fun speakThen(text: String, onDone: () -> Unit) {
        if (!ttsReady) {
            mainHandler.postDelayed({ speakThen(text, onDone) }, 500)
            return
        }
        val uid = UUID.randomUUID().toString()
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) {
                if (id == uid) runOnUiThread(onDone)
            }
            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) { runOnUiThread(onDone) }
        })
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, uid)
    }

    // ═════════════════════════════════════════════════════════════════════════
    // STT — works in background using on-device recognition
    // ERROR_CLIENT (5) fix: destroy old recognizer before creating new one,
    //                        and use a fresh instance each time
    // ═════════════════════════════════════════════════════════════════════════

    private fun startListeningNow() {
        if (isListening || !conversationActive) return

        // ✅ Check availability first
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            updateStatus("Voice N/A — use buttons")
            Log.w(TAG, "STT not available on device")
            return
        }

        isListening = true
        updateStatus("🎤  Listening... speak now")
        setMicHighlight(true)

        // ✅ KEY FIX: always destroy the old one before creating a new instance
        speechRecognizer?.apply { cancel(); destroy() }
        speechRecognizer = null

        // ✅ For Android 13+ use on-device recognizer if available (avoids ERROR_CLIENT in bg)
        speechRecognizer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
        ) {
            Log.d(TAG, "Using on-device STT")
            SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        } else {
            Log.d(TAG, "Using cloud STT")
            SpeechRecognizer.createSpeechRecognizer(this)
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) { Log.d(TAG, "STT ready") }
            override fun onBeginningOfSpeech() { updateStatus("🎤  Hearing you...") }
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onPartialResults(r: Bundle?) {
                val partial = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!partial.isNullOrEmpty()) runOnUiThread { responseText.text = "\"$partial\"" }
            }
            override fun onResults(r: Bundle?) {
                isListening = false
                setMicHighlight(false)
                val text = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
                Log.d(TAG, "STT result: '$text'")
                if (text.isNotEmpty()) sendToAI(text) else updateStatus("Tap mic or use buttons below")
            }
            override fun onError(code: Int) {
                isListening = false
                setMicHighlight(false)
                Log.w(TAG, "STT error: $code")
                val msg = when (code) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Didn't catch that — tap mic or buttons"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Mic permission needed — use buttons"
                    SpeechRecognizer.ERROR_CLIENT -> "Mic busy — tap again in a moment"
                    SpeechRecognizer.ERROR_AUDIO -> "Audio error — use buttons"
                    else -> "Tap mic to retry (code $code)"
                }
                runOnUiThread { updateStatus(msg) }
            }
            override fun onEndOfSpeech() { isListening = false; setMicHighlight(false) }
            override fun onEvent(t: Int, p: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "en")
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, "en")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000)
        }

        try {
            speechRecognizer?.startListening(intent)
            // Auto-stop after 12s
            mainHandler.postDelayed({
                if (isListening) stopListening()
            }, 12_000)
        } catch (e: Exception) {
            Log.e(TAG, "startListening error: ${e.message}")
            isListening = false
            setMicHighlight(false)
            updateStatus("Tap mic or use buttons")
        }
    }

    private fun stopListening() {
        isListening = false
        runOnUiThread { setMicHighlight(false) }
        try { speechRecognizer?.stopListening() } catch (_: Exception) {}
    }

    // ═════════════════════════════════════════════════════════════════════════
    // AI chat
    // ═════════════════════════════════════════════════════════════════════════

    private fun sendToAI(userMsg: String) {
        updateStatus("Thinking...")
        updateResponse("You: \"$userMsg\"")

        val body = JSONObject().apply {
            put("message", userMsg)
            put("userId", "1")
            put("modelProvider", "together")
            put("modelName", "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo")
            put("speakerId", "1")
            put("enablePremium", true)
        }.toString()

        httpClient.newCall(
            Request.Builder()
                .url("http://20.204.177.196:5000/api/assistant/chat")
                .post(body.toRequestBody("application/json".toMediaType()))
                .build()
        ).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "AI fail: ${e.message}")
                val reply = "I understand. Please pull over safely if you feel drowsy."
                runOnUiThread {
                    updateResponse(reply)
                    speakThen(reply) {
                        if (conversationActive) mainHandler.postDelayed({ startListeningNow() }, 500)
                    }
                }
            }

            override fun onResponse(call: Call, response: Response) {
                try {
                    val json = JSONObject(response.body?.string() ?: "{}")
                    val reply = json.optString("response", "Please stay alert and drive safely.")
                    runOnUiThread {
                        updateResponse(reply)
                        speakThen(reply) {
                            if (conversationActive) mainHandler.postDelayed({ startListeningNow() }, 500)
                        }
                    }
                } catch (_: Exception) {
                    runOnUiThread { updateResponse("Stay alert. Pull over if needed.") }
                }
            }
        })
    }

    private fun quickResponse(text: String) {
        stopListening()
        updateStatus("Sending...")
        sendToAI(text)
    }

    private fun finishSession() {
        conversationActive = false
        stopListening()
        tts?.stop()
        DrowsinessMonitoringService.onAssistantClosed(true)
        finish()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═════════════════════════════════════════════════════════════════════════

    private fun updateStatus(msg: String) = runOnUiThread { statusText.text = msg }
    private fun updateResponse(msg: String) = runOnUiThread { responseText.text = msg }

    private fun setMicHighlight(active: Boolean) {
        micButton.background = roundedBg(
            if (active) Color.parseColor("#5030D158") else Color.parseColor("#2AFFFFFF"),
            dp(44).toFloat()
        )
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun roundedBg(color: Int, r: Float) = GradientDrawable().apply {
        setColor(color); cornerRadius = r
    }

    private fun wrapLP() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )

    private fun fillLP() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ).also { it.bottomMargin = dp(6) }
}