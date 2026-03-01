package app.dash.okDriver

import android.app.Activity
import android.app.NotificationManager
import android.Manifest
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
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
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager

class BackgroundAssistantActivity : Activity() {

    companion object {
        private const val TAG = "BGA_DEBUG"   // easy to filter in logcat
        private const val REQ_MIC_PERMISSION = 1001
        private const val ASSISTANT_NOTIF_ID = 1004

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

    private lateinit var statusText: TextView
    private lateinit var responseText: TextView
    private lateinit var micButton: ImageButton
    private lateinit var orbView: OrbView

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var conversationActive = true
    private val mainHandler = Handler(Looper.getMainLooper())
    private val drowsyEvents by lazy { intent.getIntExtra("drowsy_events", 0) }
    private var assistantClosedCalled = false

    // Flutter state mirrors
    private var hasResponded = false
    private var recognizedText = ""
    private var assistantResponse = "Driver, are you alright? Please respond."
    private var isSpeakingTts = false

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    // =========================================================================
    // Lifecycle
    // =========================================================================

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "  BackgroundAssistantActivity CREATED  ")
        Log.d(TAG, "═══════════════════════════════════════")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true); setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.75f)

        dismissNotification()
        buildUI()
        initTts()

        val hasMic = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        Log.d(TAG, "hasMicPermission=$hasMic")

        if (hasMic) {
            scheduleCheckIn()
        } else {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.RECORD_AUDIO), REQ_MIC_PERMISSION
            )
            updateStatus("Mic permission needed. Use the buttons.")
        }
    }

    override fun onNewIntent(intent: Intent?) { super.onNewIntent(intent); dismissNotification() }
    override fun onBackPressed() { Log.d(TAG, "Back pressed — ignored") }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        conversationActive = false
        mainHandler.removeCallbacksAndMessages(null)
        stopListening()
        tts?.stop(); tts?.shutdown()
        speechRecognizer?.destroy()
        httpClient.dispatcher.cancelAll()
        notifyAssistantClosed()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_MIC_PERMISSION) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "Mic permission result: granted=$granted")
            if (granted && conversationActive) scheduleCheckIn()
            else updateStatus("Mic permission denied. Use the buttons.")
        }
    }

    private fun dismissNotification() {
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ASSISTANT_NOTIF_ID)
        } catch (e: Exception) { Log.w(TAG, "dismissNotification: ${e.message}") }
    }

    private fun notifyAssistantClosed() {
        if (!assistantClosedCalled) {
            assistantClosedCalled = true
            DrowsinessMonitoringService.onAssistantClosed(true)
            Log.d(TAG, "notifyAssistantClosed called")
        }
    }

    // =========================================================================
    // UI
    // =========================================================================

    private fun buildUI() {
        val root = android.widget.FrameLayout(this)
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(24), dp(24), dp(24))
            background = buildBottomSheetBg()
            elevation = 24f
        }

        card.addView(View(this).apply {
            background = roundedBg(Color.parseColor("#40FFFFFF"), dp(2).toFloat())
        }, LinearLayout.LayoutParams(dp(40), dp(4)).also {
            it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(20)
        })

        orbView = OrbView(this)
        card.addView(orbView, LinearLayout.LayoutParams(dp(120), dp(120)).also {
            it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(20)
        })
        animateOrb(orbView)

        statusText = TextView(this).apply {
            text = "Tap mic or use buttons"
            textSize = 13f
            setTextColor(Color.parseColor("#99FFFFFF"))
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
        }
        card.addView(statusText, wrapLP().also { it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(10) })

        responseText = TextView(this).apply {
            text = assistantResponse
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = roundedBg(Color.parseColor("#12FFFFFF"), dp(12).toFloat())
            setPadding(dp(16), dp(10), dp(16), dp(10))
            minLines = 2; maxLines = 5
            ellipsize = android.text.TextUtils.TruncateAt.END
            setLineSpacing(0f, 1.4f)
        }
        card.addView(responseText, fillLP().also { it.bottomMargin = dp(16) })

        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }

        micButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            scaleType = android.widget.ImageView.ScaleType.CENTER_INSIDE
            background = roundedBg(Color.parseColor("#1AFFFFFF"), dp(25).toFloat())
            setPadding(dp(12), dp(12), dp(12), dp(12))
            setColorFilter(Color.parseColor("#B3FFFFFF"))
            setOnClickListener {
                Log.d(TAG, "Mic button tapped isListening=$isListening isSpeaking=$isSpeakingTts")
                if (!isListening && !isSpeakingTts) startListeningNow()
            }
        }
        row.addView(micButton, LinearLayout.LayoutParams(dp(50), dp(50)).also { it.marginEnd = dp(12) })

        val fineBtn = Button(this).apply {
            text = "I'm fine"
            setTextColor(Color.parseColor("#30D158"))
            background = buildQuickBtn(Color.parseColor("#30D158"))
            textSize = 13f
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            setPadding(dp(16), dp(10), dp(16), dp(10))
            setOnClickListener { handleQuickResponse("I'm fine, I am alert now") }
        }
        row.addView(fineBtn, wrapLP().also { it.marginEnd = dp(10) })

        val helpBtn = Button(this).apply {
            text = "Need help"
            setTextColor(Color.parseColor("#FF3B30"))
            background = buildQuickBtn(Color.parseColor("#FF3B30"))
            textSize = 13f
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            setPadding(dp(16), dp(10), dp(16), dp(10))
            setOnClickListener { handleQuickResponse("I need help, I am very drowsy") }
        }
        row.addView(helpBtn, wrapLP())
        card.addView(row, wrapLP().also { it.gravity = Gravity.CENTER_HORIZONTAL; it.bottomMargin = dp(16) })

        val closeBtn = Button(this).apply {
            text = "✓  I'm Awake — Close"
            setTextColor(Color.WHITE)
            background = roundedBg(Color.parseColor("#1A7F37"), dp(14).toFloat())
            textSize = 15f
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            setPadding(dp(16), dp(14), dp(16), dp(14))
            setOnClickListener { finishSession() }
        }
        card.addView(closeBtn, fillLP())

        root.addView(card, android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM
        ))
        setContentView(root)
        Log.d(TAG, "UI built successfully")
    }

    /**
     * Flutter mirror:
     *   _text.isNotEmpty && !_hasResponded → show speech in quotes
     *   else → show _assistantResponse
     */
    private fun refreshResponseBubble() = runOnUiThread {
        val newText = if (recognizedText.isNotEmpty() && !hasResponded)
            "\"$recognizedText\""
        else
            assistantResponse
        responseText.text = newText
        Log.d(TAG, "🖥 BUBBLE → \"$newText\"")
    }

    private fun animateOrb(v: View) {
        val orb = v as? OrbView
        val r = object : Runnable {
            var scale = 1f; var growing = true; var animVal = 0f
            override fun run() {
                if (!conversationActive) return
                if (growing) { scale = (scale + 0.013f).coerceAtMost(1.2f); animVal = (animVal + 0.013f).coerceAtMost(1.0f); if (scale >= 1.2f) growing = false }
                else { scale = (scale - 0.013f).coerceAtLeast(1.0f); animVal = (animVal - 0.013f).coerceAtLeast(0.0f); if (scale <= 1.0f) growing = true }
                v.scaleX = scale; v.scaleY = scale; orb?.setAnimVal(animVal)
                mainHandler.postDelayed(this, 50)
            }
        }
        mainHandler.post(r)
    }

    // =========================================================================
    // Drawables
    // =========================================================================

    private fun buildBottomSheetBg(): android.graphics.drawable.Drawable {
        val radii = floatArrayOf(dp(30).toFloat(), dp(30).toFloat(), dp(30).toFloat(), dp(30).toFloat(), 0f, 0f, 0f, 0f)
        return LayerDrawable(arrayOf(
            GradientDrawable().apply { setColor(Color.parseColor("#EB000000")); cornerRadii = radii },
            GradientDrawable().apply { setColor(Color.TRANSPARENT); setStroke(dp(2), Color.parseColor("#66FF3B30")); cornerRadii = radii }
        ))
    }

    private fun buildQuickBtn(color: Int) = GradientDrawable().apply {
        setColor((color and 0x00FFFFFF) or 0x26000000); setStroke(dp(2), color); cornerRadius = dp(20).toFloat()
    }

    // =========================================================================
    // TTS
    // =========================================================================

    private fun initTts() {
        Log.d(TAG, "initTts() called")
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            Log.d(TAG, "TTS init callback: status=$status ttsReady=$ttsReady")
            if (ttsReady) {
                tts?.language = Locale.US
                tts?.setSpeechRate(0.85f)
                tts?.setPitch(1.0f)
                Log.d(TAG, "✅ TTS language set to US")
            } else {
                Log.e(TAG, "❌ TTS init FAILED status=$status")
            }
        }
    }

    private fun scheduleCheckIn() {
        Log.d(TAG, "scheduleCheckIn() — will fire in 500ms")
        mainHandler.postDelayed({ if (conversationActive) speakCheckIn() }, 500)
    }

    private fun speakCheckIn() {
        Log.d(TAG, "speakCheckIn() — ttsReady=$ttsReady")
        val msg = "Driver, are you alright? Please respond."
        assistantResponse = msg
        updateStatus("🗣  Checking in...")
        refreshResponseBubble()
        speakThenListen(msg)
    }

    /**
     * Speak text via TTS → onDone → startListeningNow()
     * Mirrors Flutter: _speak(text) → completionHandler → _listen()
     */
    private fun speakThenListen(text: String) {
        if (!conversationActive) { Log.d(TAG, "speakThenListen: conversationActive=false, skip"); return }

        if (!ttsReady) {
            Log.d(TAG, "speakThenListen: TTS not ready yet, retry in 300ms")
            mainHandler.postDelayed({ speakThenListen(text) }, 300)
            return
        }

        Log.d(TAG, "speakThenListen: SPEAKING → \"$text\"")
        isSpeakingTts = true
        updateStatus("🗣  Speaking...")
        orbView.setListening(false)

        val uid = UUID.randomUUID().toString()

        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {
                Log.d(TAG, "TTS onStart uid=$id")
            }
            override fun onDone(id: String?) {
                Log.d(TAG, "TTS onDone uid=$id expected=$uid match=${id == uid}")
                if (id == uid) {
                    runOnUiThread {
                        isSpeakingTts = false
                        Log.d(TAG, "TTS done → starting listen")
                        if (conversationActive) {
                            updateStatus("Tap mic or use buttons")
                            mainHandler.postDelayed({ startListeningNow() }, 400)
                        }
                    }
                }
            }
            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) {
                Log.e(TAG, "TTS onError uid=$id")
                runOnUiThread {
                    isSpeakingTts = false
                    if (conversationActive) {
                        updateStatus("Tap mic or use buttons")
                        mainHandler.postDelayed({ startListeningNow() }, 400)
                    }
                }
            }
        })

        val result = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, uid)
        Log.d(TAG, "TTS speak() returned: $result  (${if (result == TextToSpeech.SUCCESS) "SUCCESS" else "FAILED"})")

        if (result != TextToSpeech.SUCCESS) {
            Log.w(TAG, "TTS speak() FAILED → fallback to listen in 500ms")
            isSpeakingTts = false
            mainHandler.postDelayed({ startListeningNow() }, 500)
        }
    }

    // =========================================================================
    // STT
    // =========================================================================

    private fun startListeningNow() {
        Log.d(TAG, "startListeningNow() isListening=$isListening active=$conversationActive speaking=$isSpeakingTts")
        if (isListening || !conversationActive || isSpeakingTts) {
            Log.d(TAG, "startListeningNow: SKIPPED")
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.w(TAG, "SpeechRecognizer NOT available")
            updateStatus("Voice N/A — use buttons"); return
        }

        isListening = true
        updateStatus("🎤  Listening...")
        setMicHighlight(true)

        speechRecognizer?.apply { cancel(); destroy() }
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        Log.d(TAG, "SpeechRecognizer created")

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) { Log.d(TAG, "STT onReadyForSpeech") }
            override fun onBeginningOfSpeech() { Log.d(TAG, "STT onBeginningOfSpeech"); updateStatus("🎤  Hearing you...") }
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}

            override fun onPartialResults(r: Bundle?) {
                val partial = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: return
                Log.d(TAG, "STT partial: \"$partial\"")
                if (partial.isNotEmpty()) {
                    recognizedText = partial
                    refreshResponseBubble()
                }
            }

            override fun onResults(r: Bundle?) {
                isListening = false; setMicHighlight(false)
                val finalText = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
                Log.d(TAG, "STT FINAL RESULT: \"$finalText\"")
                if (finalText.isNotEmpty()) {
                    recognizedText = finalText
                    refreshResponseBubble()
                    processResponse(finalText)
                } else {
                    Log.w(TAG, "STT: empty result")
                    updateStatus("Tap mic or use buttons below")
                }
            }

            override fun onError(code: Int) {
                isListening = false; setMicHighlight(false)
                Log.w(TAG, "STT ERROR code=$code")
                val msg = when (code) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Didn't catch that — tap mic or buttons"
                    else -> "Tap mic to retry (code $code)"
                }
                runOnUiThread { updateStatus(msg) }
            }

            override fun onEndOfSpeech() { Log.d(TAG, "STT onEndOfSpeech"); isListening = false; setMicHighlight(false) }
            override fun onEvent(t: Int, p: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1500)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2500)
        }
        try {
            speechRecognizer?.startListening(intent)
            Log.d(TAG, "STT startListening() called")
            mainHandler.postDelayed({
                if (isListening) {
                    Log.w(TAG, "STT 15s timeout — stopping")
                    stopListening()
                }
            }, 15_000)
        } catch (e: Exception) {
            Log.e(TAG, "STT startListening EXCEPTION: ${e.message}")
            isListening = false; setMicHighlight(false)
            updateStatus("Tap mic or use buttons")
        }
    }

    private fun stopListening() {
        Log.d(TAG, "stopListening()")
        isListening = false
        runOnUiThread { setMicHighlight(false) }
        try { speechRecognizer?.stopListening() } catch (_: Exception) {}
    }

    // =========================================================================
    // AI
    // =========================================================================

    private fun processResponse(userMsg: String) {
        if (!conversationActive) { Log.d(TAG, "processResponse: conversationActive=false, skip"); return }

        Log.d(TAG, "══════════════════════════════")
        Log.d(TAG, "processResponse START: \"$userMsg\"")
        Log.d(TAG, "══════════════════════════════")

        hasResponded = true
        updateStatus("Thinking...")
        refreshResponseBubble()

        val body = JSONObject().apply {
            put("message", userMsg)
            put("userId", "1")
            put("modelProvider", "together")
            put("modelName", "meta-llama/Llama-3.2-3B-Instruct-Turbo")
            put("speakerId", "1")
            put("enablePremium", true)
        }.toString()

        Log.d(TAG, "HTTP POST body: $body")
        Log.d(TAG, "HTTP URL: http://20.204.177.196:5000/api/assistant/chat")

        val request = Request.Builder()
            .url("http://20.204.177.196:5000/api/assistant/chat")
            .post(body.toRequestBody("application/json".toMediaType()))
            .addHeader("Content-Type", "application/json")
            .build()

        Log.d(TAG, "Enqueuing HTTP call...")

        httpClient.newCall(request).enqueue(object : Callback {

            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "══ HTTP onFailure ══")
                Log.e(TAG, "Error: ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "Cause: ${e.cause}")
                val fallback = "I understand. Please pull over safely if you feel drowsy."
                runOnUiThread {
                    Log.d(TAG, "onFailure → showing fallback on UI thread")
                    assistantResponse = fallback
                    refreshResponseBubble()
                    updateStatus("Assistant")
                    speakThenListen(fallback)
                }
            }

            override fun onResponse(call: Call, response: Response) {
                Log.d(TAG, "══ HTTP onResponse ══")
                Log.d(TAG, "HTTP status code: ${response.code}")
                Log.d(TAG, "HTTP headers: ${response.headers}")

                val rawBody = try {
                    val b = response.body?.string()
                    Log.d(TAG, "HTTP raw body: $b")
                    b ?: "{}"
                } catch (e: Exception) {
                    Log.e(TAG, "HTTP body read error: ${e.message}")
                    "{}"
                }

                runOnUiThread {
                    Log.d(TAG, "onResponse → processing on UI thread")
                    try {
                        val json = JSONObject(rawBody)
                        Log.d(TAG, "JSON keys: ${json.keys().asSequence().toList()}")

                        val reply = json.optString("response", "")
                            .trim()
                            .ifEmpty { "Please stay alert and drive safely." }

                        Log.d(TAG, "Extracted reply: \"$reply\"")

                        assistantResponse = reply
                        refreshResponseBubble()
                        updateStatus("Assistant")
                        Log.d(TAG, "Calling speakThenListen with reply...")
                        speakThenListen(reply)

                    } catch (e: Exception) {
                        Log.e(TAG, "JSON parse error: ${e.message}")
                        Log.e(TAG, "Raw was: $rawBody")
                        val fallback = "Stay alert. Pull over if needed."
                        assistantResponse = fallback
                        refreshResponseBubble()
                        speakThenListen(fallback)
                    }
                }
            }
        })

        Log.d(TAG, "HTTP call enqueued successfully")
    }

    private fun handleQuickResponse(text: String) {
        Log.d(TAG, "handleQuickResponse: \"$text\"")
        stopListening()
        recognizedText = text
        hasResponded = true
        refreshResponseBubble()
        processResponse(text)
    }

    private fun finishSession() {
        Log.d(TAG, "finishSession()")
        conversationActive = false
        stopListening()
        tts?.stop()
        isSpeakingTts = false
        notifyAssistantClosed()
        finish()
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private fun updateStatus(msg: String) = runOnUiThread {
        statusText.text = msg
        statusText.setTextColor(
            if (msg.startsWith("🎤")) Color.parseColor("#30D158") else Color.parseColor("#99FFFFFF")
        )
        orbView.setListening(msg.startsWith("🎤"))
    }

    private fun setMicHighlight(active: Boolean) = runOnUiThread {
        micButton.background = roundedBg(
            if (active) Color.parseColor("#4D30D158") else Color.parseColor("#1AFFFFFF"),
            dp(25).toFloat()
        )
        micButton.setColorFilter(if (active) Color.parseColor("#30D158") else Color.parseColor("#B3FFFFFF"))
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun roundedBg(color: Int, r: Float) = GradientDrawable().apply { setColor(color); cornerRadius = r }
    private fun wrapLP() = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    private fun fillLP() = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).also { it.bottomMargin = dp(6) }

    // =========================================================================
    // OrbView
    // =========================================================================

    inner class OrbView(ctx: Context) : android.view.View(ctx) {
        private var listening = false
        private var animVal = 0f
        private val gradPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val strokePaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE; strokeWidth = 2.5f * resources.displayMetrics.density
            style = android.graphics.Paint.Style.STROKE; strokeCap = android.graphics.Paint.Cap.ROUND
        }
        private val shadowPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { style = android.graphics.Paint.Style.FILL }

        fun setListening(on: Boolean) { listening = on; invalidate() }
        fun setAnimVal(v: Float) { animVal = v; invalidate() }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val cx = width / 2f; val cy = height / 2f; val r = minOf(cx, cy) * 0.83f
            shadowPaint.color = if (listening) Color.parseColor("#80388E3C") else Color.parseColor("#80C62828")
            shadowPaint.maskFilter = android.graphics.BlurMaskFilter(25 * resources.displayMetrics.density, android.graphics.BlurMaskFilter.Blur.NORMAL)
            canvas.drawCircle(cx, cy, r + 5 * resources.displayMetrics.density, shadowPaint)
            shadowPaint.maskFilter = null
            gradPaint.shader = android.graphics.RadialGradient(
                cx, cy, r,
                if (listening) Color.parseColor("#A5D6A7") else Color.parseColor("#EF9A9A"),
                if (listening) Color.parseColor("#2E7D32") else Color.parseColor("#B71C1C"),
                android.graphics.Shader.TileMode.CLAMP
            )
            canvas.drawCircle(cx, cy, r, gradPaint)
            val wR = r * 0.7f
            if (listening) {
                val path = android.graphics.Path()
                val rnd = java.util.Random((animVal * 10000).toInt().toLong())
                for (i in 0..20) {
                    val angle = i * 2 * Math.PI / 20
                    val variance = rnd.nextDouble() * 10 + 5
                    val pr = wR * (0.6f + (variance / 100).toFloat())
                    val x = cx + pr * Math.cos(angle).toFloat()
                    val y = cy + pr * Math.sin(angle).toFloat()
                    if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                path.close(); canvas.drawPath(path, strokePaint)
            } else {
                canvas.drawCircle(cx, cy, wR * 0.7f, strokePaint)
            }
        }
    }
}