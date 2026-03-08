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
  String _streamingText = '';
  String _statusText = '';
  bool _isListening = false;
  bool _isLoading = false;
  bool _isWakeListening = false;
  bool _speechReady = false;
  bool _isDarkMode = false;
  AssistantPhase _phase = AssistantPhase.wakeListening;

  VoiceMode _voiceMode = VoicePreferences.voiceMode;

  bool _wakeWordEnabled = true;
  DateTime? _lastWakeAt;

  @override
  void initState() {
    super.initState();
    _initTts(); // ✅ TTS PEHLE init karo
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkTheme;
      _setupWebSocket();
      _service.enableAudioPlayback = _voiceMode == VoiceMode.xtts;
      if (_wakeWordEnabled) _startWakeListening();
    });
  }

  // ── ✅ TTS INIT — yahi missing tha ────────────────────────────
  Future<void> _initTts() async {
    try {
      // Hindi-English mixed content ke liye hi-IN best
      await _tts.setLanguage('hi-IN');
      await _tts.setSpeechRate(0.5); // natural speed
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // TTS khatam hone pe wake word resume karo
      _tts.setCompletionHandler(() {
        print('[TTS] Completed');
        if (mounted) {
          setState(() {
            _phase = _wakeWordEnabled
                ? AssistantPhase.wakeListening
                : AssistantPhase.idle;
          });
          if (_wakeWordEnabled && !_isWakeListening && !_isListening) {
            _startWakeListening();
          }
        }
      });

      _tts.setErrorHandler((msg) {
        print('[TTS] Error: $msg');
      });

      print('[TTS] ✅ Initialized');
    } catch (e) {
      print('[TTS] ❌ Init failed: $e');
    }
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
    _service.onStatusUpdate = (s) {
      if (mounted) setState(() => _statusText = s);
    };

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

    _service.onTextChunk = (chunk) {
      if (mounted)
        setState(() {
          _streamingText += chunk;
          _phase = AssistantPhase.speaking;
        });
    };

    _service.onDone = (fullText) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: fullText, isUser: false));
          _streamingText = '';
          _isLoading = false;
          _statusText = '';
        });
        _scrollToBottom();

        if (_voiceMode == VoiceMode.flutterTts && fullText.isNotEmpty) {
          // ✅ stop() await karke phir speak — overlap avoid
          _tts.stop().then((_) {
            _tts.speak(fullText);
            // phase + wake resume _tts.setCompletionHandler mein hoga
          });
        } else {
          // XTTS mode — service audio handle karega
          setState(() {
            _phase = _wakeWordEnabled
                ? AssistantPhase.wakeListening
                : AssistantPhase.idle;
          });
          if (_wakeWordEnabled && !_isWakeListening && !_isListening) {
            _startWakeListening();
          }
        }
      }
    };

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

  // ── Speech-to-Text init ───────────────────────────────────────
  void _initSpeech() async {
    _speechReady = await _speech.initialize();
    print('[STT] ready: $_speechReady');
  }

  // ── Mic press ─────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_isListening) return;

    // ✅ TTS rok do pehle — user bolta hai to assistant chup rahe
    await _tts.stop();

    if (_isWakeListening) {
      _speech.stop();
      setState(() => _isWakeListening = false);
    }

    await _service.stopAudio();

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

  // ── Mic release ───────────────────────────────────────────────
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

  // ── Toggle mic ────────────────────────────────────────────────
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
          Expanded(
            child: (_messages.isEmpty && _streamingText.isEmpty)
                ? _buildEmptyState()
                : _buildChatList(),
          ),
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
          glass.GlassContainer(
            color: _isDarkMode ? Colors.black : Colors.white,
            opacity: _isDarkMode ? 0.3 : 0.7,
            blur: 10.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopAndSend(),
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

  Widget _buildChatList() {
    final total = _messages.length + (_streamingText.isNotEmpty ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: total,
      itemBuilder: (ctx, i) {
        if (_streamingText.isNotEmpty && i == _messages.length) {
          return ChatBubble(message: _streamingText, isUser: false);
        }
        return ChatBubble(
            message: _messages[i].text, isUser: _messages[i].isUser);
      },
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Voice Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            RadioListTile<VoiceMode>(
              title: Row(
                children: [
                  const Text('Fast TTS'),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9C27B0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: const Text('Phone ki awaaz — bilkul jaldi'),
              value: VoiceMode.flutterTts,
              groupValue: _voiceMode,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (mode) {
                if (mode == null) return;
                setState(() => _voiceMode = mode);
                VoicePreferences.voiceMode = mode;
                _service.enableAudioPlayback = false;
                Navigator.pop(context);
              },
            ),
            RadioListTile<VoiceMode>(
              title: const Text('Priya XTTS'),
              subtitle: const Text('Server ki high-quality awaaz'),
              value: VoiceMode.xtts,
              groupValue: _voiceMode,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (mode) {
                if (mode == null) return;
                setState(() => _voiceMode = mode);
                VoicePreferences.voiceMode = mode;
                _service.enableAudioPlayback = true;
                Navigator.pop(context);
              },
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _service.isConnected ? Icons.wifi : Icons.wifi_off,
                color: _service.isConnected ? Colors.green : Colors.red,
              ),
              title: const Text('Voice Backend'),
              subtitle: Text(
                _service.isConnected ? 'Online' : 'Offline — tap to reconnect',
                style: const TextStyle(fontSize: 11),
              ),
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
