package app.dash.okDriver

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.widget.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * DrowsinessOverlayView
 *
 * Drawn via WindowManager — works on MIUI/Xiaomi without needing
 * "Display pop-up windows" special permission (foreground service satisfies the requirement).
 *
 * Flow: overlay appears → TTS speaks check-in → STT listens → AI responds → loop
 */
class DrowsinessOverlayView(
    context: Context,
    private val drowsyEvents: Int,
    private val onDismiss: () -> Unit
) : FrameLayout(context) {

    companion object {
        private const val TAG = "OverlayView"
    }

    // ── TTS / STT ─────────────────────────────────────────────────────────────
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var stt: SpeechRecognizer? = null
    private var isListening = false
    private var active = true

    // ── UI ────────────────────────────────────────────────────────────────────
    private lateinit var statusTv: TextView
    private lateinit var responseTv: TextView
    private lateinit var micBtn: ImageButton
    private lateinit var orbView: View

    // ── Handler ───────────────────────────────────────────────────────────────
    private val handler = Handler(Looper.getMainLooper())

    // ── HTTP ──────────────────────────────────────────────────────────────────
    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // =========================================================================
    init {
        buildUI()
        initTts()
        // Speak check-in after 300ms (alarm already stopped in service)
        handler.postDelayed({ if (active) speakCheckIn() }, 300)
    }

    // =========================================================================
    // UI construction
    // =========================================================================

    private fun buildUI() {
        setBackgroundColor(Color.TRANSPARENT)

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(20), dp(24), dp(20), dp(28))
            background = roundRect(Color.parseColor("#F0050505"), dp(28).toFloat())
            elevation = 24f
        }

        // Handle bar
        card.addView(
            View(context).apply { background = roundRect(Color.parseColor("#44FFFFFF"), dp(3).toFloat()) },
            lp(dp(36), dp(4)).also { it.bottomMargin = dp(18) }
        )

        // Orb
        orbView = View(context).apply {
            background = roundRect(Color.parseColor("#CCFF3B30"), dp(48).toFloat())
        }
        card.addView(orbView, lp(dp(80), dp(80)).also {
            it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(14)
        })
        startOrbPulse()

        // Status label
        statusTv = TextView(context).apply {
            text = "⚠  Drowsiness Detected!"
            textSize = 14f
            setTextColor(Color.parseColor("#FFFF3B30"))
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        card.addView(statusTv, wrapLp().also {
            it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(12)
        })

        // AI response box
        responseTv = TextView(context).apply {
            text = "Initializing..."
            textSize = 15f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = roundRect(Color.parseColor("#1CFFFFFF"), dp(14).toFloat())
            setPadding(dp(16), dp(14), dp(16), dp(14))
            minLines = 2
        }
        card.addView(responseTv, fillLp().also { it.bottomMargin = dp(18) })

        // Button row
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        micBtn = ImageButton(context).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            background = roundRect(Color.parseColor("#2CFFFFFF"), dp(40).toFloat())
            setPadding(dp(16), dp(16), dp(16), dp(16))
            setOnClickListener { if (!isListening) startSTT() }
        }
        row.addView(micBtn, lp(dp(80), dp(80)).also { it.marginEnd = dp(10) })

        val fineBtn = Button(context).apply {
            text = "✓ I'm Fine"
            setTextColor(Color.parseColor("#30D158"))
            background = roundRect(Color.parseColor("#2030D158"), dp(20).toFloat())
            textSize = 13f
            setPadding(dp(14), dp(8), dp(14), dp(8))
            setOnClickListener { quickReply("I'm fine and alert now") }
        }
        row.addView(fineBtn, wrapLp().also { it.marginEnd = dp(8) })

        val helpBtn = Button(context).apply {
            text = "⚠ Need Help"
            setTextColor(Color.parseColor("#FF3B30"))
            background = roundRect(Color.parseColor("#20FF3B30"), dp(20).toFloat())
            textSize = 13f
            setPadding(dp(14), dp(8), dp(14), dp(8))
            setOnClickListener { quickReply("I need help, I am very drowsy") }
        }
        row.addView(helpBtn, wrapLp())
        card.addView(row, wrapLp().also {
            it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(14)
        })

        // Close button
        val closeBtn = Button(context).apply {
            text = "✓  I'm Awake — Close"
            setTextColor(Color.WHITE)
            background = roundRect(Color.parseColor("#1A7F37"), dp(14).toFloat())
            textSize = 14f
            setOnClickListener { closeOverlay() }
        }
        card.addView(closeBtn, fillLp())

        addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        )
    }

    private fun startOrbPulse() {
        val r = object : Runnable {
            var s = 1f; var grow = true
            override fun run() {
                if (!active) return
                s = if (grow) (s + 0.05f).coerceAtMost(1.3f) else (s - 0.05f).coerceAtLeast(0.8f)
                if (s >= 1.3f) grow = false; if (s <= 0.8f) grow = true
                orbView.scaleX = s; orbView.scaleY = s
                handler.postDelayed(this, 80)
            }
        }
        handler.post(r)
    }

    // =========================================================================
    // TTS
    // =========================================================================

    private fun initTts() {
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale.US
                tts?.setSpeechRate(0.9f)
                Log.d(TAG, "✅ TTS ready")
            } else {
                Log.e(TAG, "TTS failed: $status")
            }
        }
    }

    private fun speakCheckIn() {
        val msg = "Driver, are you alright? Please respond."
        setStatus("🗣  Checking in...")
        setResponse(msg)
        speak(msg) { if (active) handler.postDelayed({ startSTT() }, 400) }
    }

    private fun speak(text: String, onDone: (() -> Unit)? = null) {
        if (!ttsReady) {
            handler.postDelayed({ speak(text, onDone) }, 500); return
        }
        val uid = UUID.randomUUID().toString()
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { if (id == uid) post { onDone?.invoke() } }
            @Deprecated("Deprecated") override fun onError(id: String?) { post { onDone?.invoke() } }
        })
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, uid)
    }

    // =========================================================================
    // STT  —  works in background: destroy & recreate each time
    // =========================================================================

    private fun startSTT() {
        if (isListening || !active) return

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            setStatus("Voice N/A — use buttons"); return
        }

        isListening = true
        setStatus("🎤  Listening...")
        setMicActive(true)

        // Always create fresh to avoid ERROR_CLIENT
        stt?.apply { cancel(); destroy() }; stt = null

        stt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            Log.d(TAG, "Using on-device STT")
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }

        stt?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(b: Bundle?) {}
            override fun onBeginningOfSpeech() { setStatus("🎤  Hearing you...") }
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onPartialResults(r: Bundle?) {
                val p = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!p.isNullOrEmpty()) post { responseTv.text = "\"$p\"" }
            }
            override fun onResults(r: Bundle?) {
                isListening = false; setMicActive(false)
                val text = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                Log.d(TAG, "STT: '$text'")
                if (text.isNotEmpty()) sendToAI(text)
                else setStatus("Tap mic or use buttons")
            }
            override fun onError(code: Int) {
                isListening = false; setMicActive(false)
                Log.w(TAG, "STT error $code")
                val msg = when (code) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Didn't catch that — tap mic to retry"
                    SpeechRecognizer.ERROR_CLIENT         -> "Tap mic again in a moment"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Use buttons below"
                    else -> "Tap mic or use buttons (code $code)"
                }
                post { setStatus(msg) }
            }
            override fun onEndOfSpeech() { isListening = false; setMicActive(false) }
            override fun onEvent(t: Int, b: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1500L)
        }

        try {
            stt?.startListening(intent)
            handler.postDelayed({ if (isListening) stopSTT() }, 12_000)
        } catch (e: Exception) {
            Log.e(TAG, "STT startListening: ${e.message}")
            isListening = false; setMicActive(false)
            setStatus("Tap mic or use buttons")
        }
    }

    private fun stopSTT() {
        isListening = false
        post { setMicActive(false) }
        try { stt?.stopListening() } catch (_: Exception) {}
    }

    // =========================================================================
    // AI chat
    // =========================================================================

    private fun sendToAI(userMsg: String) {
        setStatus("Thinking...")
        setResponse("You: \"$userMsg\"")

        val body = JSONObject().apply {
            put("message", userMsg); put("userId", "1")
            put("modelProvider", "together")
            put("modelName", "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo")
            put("speakerId", "1"); put("enablePremium", true)
        }.toString()

        http.newCall(
            Request.Builder()
                .url("http://20.204.177.196:5000/api/assistant/chat")
                .post(body.toRequestBody("application/json".toMediaType()))
                .build()
        ).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                val reply = "I understand. Pull over safely if drowsy."
                post { setResponse(reply); speak(reply) { if (active) handler.postDelayed({ startSTT() }, 400) } }
            }
            override fun onResponse(call: Call, response: Response) {
                val reply = try {
                    JSONObject(response.body?.string() ?: "{}").optString(
                        "response", "Stay alert. Pull over if needed.")
                } catch (_: Exception) { "Stay alert and drive safely." }
                post { setResponse(reply); speak(reply) { if (active) handler.postDelayed({ startSTT() }, 400) } }
            }
        })
    }

    private fun quickReply(text: String) {
        stopSTT(); setStatus("Sending...")
        sendToAI(text)
    }

    // =========================================================================
    // Dismiss
    // =========================================================================

    fun cleanup() {
        active = false
        handler.removeCallbacksAndMessages(null)
        stopSTT()
        stt?.destroy(); stt = null
        tts?.stop(); tts?.shutdown(); tts = null
        http.dispatcher.cancelAll()
    }

    private fun closeOverlay() {
        cleanup()
        onDismiss()
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private fun setStatus(msg: String) = post { statusTv.text = msg }
    private fun setResponse(msg: String) = post { responseTv.text = msg }
    private fun setMicActive(on: Boolean) {
        post {
            micBtn.background = roundRect(
                if (on) Color.parseColor("#5030D158") else Color.parseColor("#2CFFFFFF"),
                dp(40).toFloat()
            )
        }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun roundRect(color: Int, r: Float) = GradientDrawable().apply {
        setColor(color); cornerRadius = r
    }

    private fun lp(w: Int, h: Int) = LinearLayout.LayoutParams(w, h)
    private fun wrapLp() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )
    private fun fillLp() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ).also { it.bottomMargin = dp(4) }

    // Block touch events from passing through to app below
    override fun onTouchEvent(event: MotionEvent?) = true
}