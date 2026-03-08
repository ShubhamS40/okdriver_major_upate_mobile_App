import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:okdriver/theme/theme_provider.dart';

import 'components/chat_bubble.dart';
import 'components/wave_animation.dart' as wave;
import 'components/interactive_microphone.dart';
import 'components/glass_conatiner.dart' as glass;
import 'models/chat_message.dart';
import 'service/assistant_service.dart';

class OkDriverVirtualAssistantScreen extends StatefulWidget {
  const OkDriverVirtualAssistantScreen({super.key});

  @override
  State<OkDriverVirtualAssistantScreen> createState() =>
      _OkDriverVirtualAssistantScreenState();
}

enum AssistantPhase { idle, wakeListening, listening, speaking, processing }

class _OkDriverVirtualAssistantScreenState
    extends State<OkDriverVirtualAssistantScreen> {
  // ── Services ─────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AssistantService _service = AssistantService();
  final AudioRecorder _recorder = AudioRecorder();
  final ScrollController _scroll = ScrollController();

  // ── State ─────────────────────────────────────────────────────
  List<ChatMessage> _messages = [];
  String _streamingText = ''; // live text_chunks
  String _statusText = ''; // status bar
  bool _isListening = false;
  bool _isLoading = false;
  bool _isWakeListening = false;
  bool _speechReady = false;
  bool _isDarkMode = false;
  AssistantPhase _phase = AssistantPhase.wakeListening;

  // Wake word
  bool _wakeWordEnabled = true;
  DateTime? _lastWakeAt;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkTheme;
      _setupWebSocket();
      if (_wakeWordEnabled) _startWakeListening();
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _recorder.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── WebSocket setup ───────────────────────────────────────────
  void _setupWebSocket() {
    // 1. Status messages from backend ("Samajh rahi hoon...", etc.)
    _service.onStatusUpdate = (s) {
      if (mounted) setState(() => _statusText = s);
    };

    // 2. STT transcript — show user bubble
    _service.onTranscript = (text) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _streamingText = '';
          _isLoading = true;
        });
        _scrollToBottom();
      }
    };

    // 3. Text chunks — stream into reply bubble live
    _service.onTextChunk = (chunk) {
      if (mounted)
        setState(() {
          _streamingText += chunk;
          _phase = AssistantPhase.speaking;
        });
    };

    // 4. Audio chunks — auto-queued and played by service
    // (nothing extra needed here — AssistantService handles it)

    // 5. Done — finalise reply bubble
    _service.onDone = (fullText) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: fullText, isUser: false));
          _streamingText = '';
          _isLoading = false;
          _statusText = '';
          _phase = _wakeWordEnabled
              ? AssistantPhase.wakeListening
              : AssistantPhase.idle;
        });
        _scrollToBottom();
        if (_wakeWordEnabled && !_isWakeListening && !_isListening) {
          _startWakeListening();
        }
      }
    };

    // 6. Error
    _service.onError = (err) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isListening = false;
          _statusText = '';
          _phase = _wakeWordEnabled
              ? AssistantPhase.wakeListening
              : AssistantPhase.idle;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
        if (_wakeWordEnabled) _startWakeListening();
      }
    };

    _service.connect();
  }

  // ── Speech-to-Text init (for wake word only) ──────────────────
  void _initSpeech() async {
    _speechReady = await _speech.initialize();
    print('[STT] ready: $_speechReady');
  }

  // ── Mic press — start recording ───────────────────────────────
  Future<void> _startListening() async {
    if (_isListening) return;

    // Stop wake word first
    if (_isWakeListening) {
      _speech.stop();
      setState(() => _isWakeListening = false);
    }

    await _service.stopAudio(); // stop any playing audio

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      return;
    }

    final dir = await Directory.systemTemp.createTemp('ok_rec');
    final path = '${dir.path}/audio.webm';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() {
      _isListening = true;
      _phase = AssistantPhase.listening;
      _statusText = 'Bol raho ho...';
    });

    print('[Recorder] Started → $path');
  }

  // ── Mic release — stop recording and send to backend ──────────
  Future<void> _stopAndSend() async {
    if (!_isListening) return;

    setState(() {
      _isListening = false;
      _phase = AssistantPhase.processing;
      _statusText = 'Bhej rahi hoon...';
    });

    final path = await _recorder.stop();
    print('[Recorder] Stopped → $path');

    if (path == null || path.isEmpty) {
      setState(() {
        _statusText = '';
        _phase = AssistantPhase.idle;
      });
      return;
    }

    final file = File(path);
    final bytes = await file.readAsBytes();
    await file.delete();

    if (bytes.isEmpty) {
      setState(() {
        _statusText = '';
        _phase = AssistantPhase.idle;
      });
      return;
    }

    print('[WS] Sending ${bytes.length} bytes to backend');

    if (!_service.isConnected) await _service.connect();
    await _service.sendAudio(bytes);
  }

  // ── Toggle mic (tap mode — tap once to start, again to stop) ──
  Future<void> _toggleMic() async {
    if (_isListening) {
      await _stopAndSend();
    } else {
      await _startListening();
    }
  }

  // ── Wake word detection ───────────────────────────────────────
  void _startWakeListening() async {
    if (_isWakeListening || _isListening || !_wakeWordEnabled) return;
    if (!_speechReady) _speechReady = await _speech.initialize();
    if (!_speechReady) return;

    setState(() {
      _isWakeListening = true;
      _phase = AssistantPhase.wakeListening;
    });

    _speech.listen(
      onResult: (r) {
        final phrase = r.recognizedWords.toLowerCase();
        if (_shouldTriggerWake(phrase)) _onWakeDetected();
      },
      listenMode:
          kIsWeb ? stt.ListenMode.confirmation : stt.ListenMode.dictation,
      partialResults: true,
      localeId: 'en_IN',
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: false,
    );
  }

  bool _shouldTriggerWake(String phrase) {
    final now = DateTime.now();
    if (_lastWakeAt != null && now.difference(_lastWakeAt!).inSeconds < 3)
      return false;
    final n = phrase.replaceAll(',', '').replaceAll(' ', '');
    return n.contains('okdriver') || phrase.contains('ok driver');
  }

  Future<void> _onWakeDetected() async {
    _lastWakeAt = DateTime.now();
    _speech.stop();
    setState(() => _isWakeListening = false);
    print('[Wake] Triggered!');
    await _startListening();
  }

  // ── Helpers ───────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _isDarkMode = Provider.of<ThemeProvider>(context).isDarkTheme;
    final bg = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final appBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textCl = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appBg,
        elevation: 0,
        title: Text('OkDriver Assistant',
            style: TextStyle(color: textCl, fontWeight: FontWeight.w600)),
        actions: [
          // Connection dot
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.circle,
                size: 10,
                color: _service.isConnected ? Colors.green : Colors.red),
          ),
          IconButton(
            icon: Icon(Icons.settings,
                color: _isDarkMode ? Colors.white70 : Colors.black54),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status bar ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _statusText.isNotEmpty ? 32 : 0,
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            child: Center(
              child: Text(
                _statusText,
                style: const TextStyle(
                  color: Color(0xFF9C27B0),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),

          // ── Chat list ───────────────────────────────────────
          Expanded(
            child: (_messages.isEmpty && _streamingText.isEmpty)
                ? _buildEmptyState()
                : _buildChatList(),
          ),

          // ── Wave animation bar ──────────────────────────────
          if (_isListening || _phase == AssistantPhase.speaking || _isLoading)
            Container(
              height: 48,
              alignment: Alignment.center,
              child: StatusIndicator(
                isListening: _isListening,
                isProcessing: _isLoading,
                isSpeaking: _phase == AssistantPhase.speaking,
                isDarkMode: _isDarkMode,
              ),
            ),

          // ── Mic button ──────────────────────────────────────
          glass.GlassContainer(
            color: _isDarkMode ? Colors.black : Colors.white,
            opacity: _isDarkMode ? 0.3 : 0.7,
            blur: 10.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: GestureDetector(
                  // Hold-to-talk
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopAndSend(),
                  // Tap-to-toggle
                  onTap: _toggleMic,
                  child: InteractiveMicrophone(
                    isListening: _isListening,
                    isWakeListening: _isWakeListening,
                    onTap: _toggleMic,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    String hint;
    if (_isWakeListening)
      hint = '"OkDriver" bolke activate karo';
    else if (_isListening)
      hint = 'Sun rahi hoon... release karo';
    else if (_isLoading)
      hint = 'Soch rahi hoon...';
    else
      hint = 'Mic dabao aur bolo';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9C27B0).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: ClipOval(
              child: glass.GlassContainer(
                color: _isDarkMode ? Colors.black : Colors.white,
                opacity: 0.1,
                blur: 8.0,
                child: Center(
                  child: wave.WaveAnimation(
                    isActive: _isListening ||
                        _isWakeListening ||
                        _phase == AssistantPhase.speaking,
                    color: _isDarkMode
                        ? const Color(0xFF9C27B0).withOpacity(0.7)
                        : const Color(0xFF9C27B0),
                    size: 120,
                    strokeWidth: 2.0,
                    numberOfWaves: 3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          glass.GlassContainer(
            color: _isDarkMode ? Colors.black : Colors.white,
            opacity: _isDarkMode ? 0.2 : 0.1,
            blur: 5.0,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(children: [
                Text(hint,
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Groq LLM + XTTS v2',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat list ─────────────────────────────────────────────────
  Widget _buildChatList() {
    final total = _messages.length + (_streamingText.isNotEmpty ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: total,
      itemBuilder: (ctx, i) {
        // Streaming bubble at the end
        if (_streamingText.isNotEmpty && i == _messages.length) {
          return ChatBubble(message: _streamingText, isUser: false);
        }
        return ChatBubble(
            message: _messages[i].text, isUser: _messages[i].isUser);
      },
    );
  }

  // ── Settings dialog ───────────────────────────────────────────
  void _showSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Wake Word'),
              subtitle: const Text('"OkDriver" se activate'),
              value: _wakeWordEnabled,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (v) {
                setState(() => _wakeWordEnabled = v);
                Navigator.pop(context);
                if (v)
                  _startWakeListening();
                else
                  _speech.stop();
              },
            ),
            ListTile(
              leading: Icon(
                _service.isConnected ? Icons.wifi : Icons.wifi_off,
                color: _service.isConnected ? Colors.green : Colors.red,
              ),
              title: const Text('Backend'),
              subtitle: Text(AssistantService.wsUrl,
                  style: const TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _service.connect();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
