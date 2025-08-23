import 'package:flutter/material.dart';
import 'package:okdriver/okdriver_virtual_assistant/components/conservation_chat_histroy.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:avatar_glow/avatar_glow.dart';
import 'package:provider/provider.dart';
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
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AssistantService _assistantService = AssistantService();

  bool _isListening = false;
  String _text = '';
  bool _isLoading = false;
  List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late bool _isDarkMode;
  final String _userId = 'default'; // Could be replaced with actual user ID

  // Wake word
  bool _wakeWordEnabled = true;
  bool _isWakeListening = false;
  bool _speechReady = false;
  DateTime? _lastWakeAt;

  // Interaction phases for dynamic orb
  AssistantPhase _phase = AssistantPhase.wakeListening;

  // Model and speaker selection
  Map<String, dynamic> _availableModels = {};
  Map<String, dynamic> _availableSpeakers = {};
  String _selectedModelProvider = 'together';
  String _selectedModelName = '';
  String _selectedSpeakerId = 'flutter_tts'; // Default to Flutter TTS
  bool _enablePremium = false;
  bool _isLoadingConfig = true;

  // Wake word choice and fast TTS option
  String _wakeWord = 'okdriver'; // options: 'okdriver' or 'bro'
  bool _lowLatencyTts = true; // speak immediately using device TTS

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();

    // Initialize _isDarkMode from ThemeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkTheme;
      });

      // Load available models and speakers
      _loadConfig();

      // Load user settings
      _loadUserSettings();

      // Optionally load history in background if needed
      // _loadHistory();
      if (_wakeWordEnabled) {
        _startWakeWordListening();
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _scrollController.dispose();
    _assistantService.dispose(); // Dispose audio player resources
    super.dispose();
  }

  // Initialize speech recognition
  void _initSpeech() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() {
            _isListening = false;
            _phase = AssistantPhase.processing;
          });
          if (_text.isNotEmpty) {
            _sendMessageToBackend(_text);
          } else {
            setState(() {
              _phase = _wakeWordEnabled
                  ? AssistantPhase.wakeListening
                  : AssistantPhase.idle;
            });
          }
        }
      },
    );
    // ignore: avoid_print
    print('[OkDriver] Speech initialized: ${_speechReady ? 'OK' : 'FAILED'}');
  }

  // Initialize text-to-speech with enhanced settings
  void _initTts() async {
    print('[OkDriver] Initializing Flutter TTS');

    // Set default language to Hindi for Hinglish support
    await _flutterTts.setLanguage("hi-IN");

    // Configure TTS parameters for better quality
    await _flutterTts
        .setSpeechRate(0.5); // Slower speech rate for better understanding
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Get available voices and set a good quality voice if available
    try {
      var voices = await _flutterTts.getVoices;
      print('[OkDriver] Available TTS voices: ${voices?.length ?? 0}');

      if (voices != null && voices is List && voices.isNotEmpty) {
        // Try to find a high-quality voice
        Map? selectedVoice;

        for (var voice in voices) {
          if (voice is Map &&
              voice['quality'] != null &&
              voice['quality'] == 'enhanced' &&
              voice['locale'] != null &&
              voice['locale'].toString().startsWith('hi')) {
            selectedVoice = voice;
            break;
          }
        }

        // If no enhanced Hindi voice found, try to find any Hindi voice
        if (selectedVoice == null) {
          for (var voice in voices) {
            if (voice is Map &&
                voice['locale'] != null &&
                voice['locale'].toString().startsWith('hi')) {
              selectedVoice = voice;
              break;
            }
          }
        }

        // If still no Hindi voice, use any available voice
        if (selectedVoice == null && voices.isNotEmpty && voices[0] is Map) {
          selectedVoice = voices[0];
        }

        if (selectedVoice != null) {
          // Pass the entire voice map to setVoice
          await _flutterTts.setVoice(Map<String, String>.from(selectedVoice));
          print('[OkDriver] Set voice to: ${selectedVoice['name']}');
        }
      }
    } catch (e) {
      // Fallback to default voice if error occurs
      print('[OkDriver] Error setting voice: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize voice: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    // Set handlers for speaking state changes
    _flutterTts.setStartHandler(() {
      setState(() {
        _phase = AssistantPhase.speaking;
      });
      print('[OkDriver] TTS started speaking');
    });

    _flutterTts.setCompletionHandler(() {
      print('[OkDriver] TTS completed speaking');
      if (mounted) {
        setState(() {
          _phase = _wakeWordEnabled
              ? AssistantPhase.wakeListening
              : AssistantPhase.idle;
        });

        // If wake word is enabled, start listening for it again
        if (_wakeWordEnabled && !_isWakeListening && !_isListening) {
          print(
              '[OkDriver] Restarting wake word listening after TTS completion');
          _startWakeWordListening();
        }
      }
    });

    // Set progress handler for potential UI updates during speech
    _flutterTts.setProgressHandler((text, start, end, word) {
      // Could be used for word highlighting or other UI feedback
    });

    print("TTS initialized successfully");
  }

  // Load conversation history
  void _loadHistory() async {
    try {
      final history = await _assistantService.getHistory(_userId);
      setState(() {
        _messages = history;
      });
      _scrollToBottom();
    } catch (e) {
      // Handle error silently
    }
  }

  // Start listening to user's voice with automatic processing
  void _listen() async {
    if (!_isListening) {
      if (!_speechReady) {
        _speechReady = await _speech.initialize();
      }
      if (_speechReady) {
        setState(() {
          _isListening = true;
          _text = '';
          _phase = AssistantPhase.listening;
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
            });
            // Log recognized speech to terminal
            // ignore: avoid_print
            print('[OkDriver] Recognized: ${result.recognizedWords}');
            // Handle final result here
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              setState(() {
                _isListening = false;
                _phase = AssistantPhase.processing;
              });
              _speech.stop();
              _sendMessageToBackend(result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 10), // Auto-stop after 10 seconds
          pauseFor: const Duration(
              seconds: 2), // Auto-stop after 2 seconds of silence
          localeId:
              "en_IN", // English (India) for better recognition of Indian accent
        );
      }
    } else {
      // Manual stop when button is pressed during listening
      setState(() {
        _isListening = false;
        _phase = AssistantPhase.processing;
      });
      _speech.stop();
      if (_text.isNotEmpty) {
        _sendMessageToBackend(_text);
      } else {
        setState(() {
          _phase = _wakeWordEnabled
              ? AssistantPhase.wakeListening
              : AssistantPhase.idle;
        });
      }
    }
  }

  // Wake word continuous listening
  void _startWakeWordListening() async {
    if (_isWakeListening || _isListening) return;
    if (!_speechReady) {
      _speechReady = await _speech.initialize();
    }
    if (!_speechReady) return;
    setState(() {
      _isWakeListening = true;
      _phase = AssistantPhase.wakeListening;
    });
    if (kIsWeb) {
      _speech.listen(
        onResult: (result) {
          final phrase = result.recognizedWords.toLowerCase();
          if (_shouldTriggerWake(phrase)) {
            _onWakeDetected();
          }
        },
        partialResults: true,
        localeId: "en_IN",
      );
    } else {
      _speech.listen(
        onResult: (result) {
          final phrase = result.recognizedWords.toLowerCase();
          if (_shouldTriggerWake(phrase)) {
            _onWakeDetected();
          }
        },
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        localeId: "en_IN",
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 2),
        cancelOnError: false,
      );
    }
  }

  bool _shouldTriggerWake(String phrase) {
    final now = DateTime.now();
    if (_lastWakeAt != null && now.difference(_lastWakeAt!).inSeconds < 3) {
      return false;
    }
    final normalized = phrase.replaceAll(',', '').replaceAll(' ', '');
    if (_wakeWord == 'bro') {
      return phrase.contains('bro');
    }
    return normalized.contains('okdriver') || phrase.contains('ok driver');
  }

  Future<void> _onWakeDetected() async {
    _lastWakeAt = DateTime.now();
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isWakeListening = false;
      });
    }
    // Immediate greeting without hitting backend
    if (_lowLatencyTts) {
      await _flutterTts.speak('Hey bro, how can I help you today?');
    }
    // Then start active listening for the user's query
    _listen();
  }

  void _toggleWakeWord(bool enabled) {
    setState(() {
      _wakeWordEnabled = enabled;
    });
    if (_wakeWordEnabled) {
      _startWakeWordListening();
    } else {
      if (_isWakeListening) {
        _speech.stop();
        setState(() {
          _isWakeListening = false;
        });
      }
    }
  }

  // Load available models and speakers from backend
  void _loadConfig() async {
    try {
      setState(() {
        _isLoadingConfig = true;
      });

      final config = await _assistantService.getAvailableConfig();

      setState(() {
        _availableModels = config['available_models'] ?? {};
        _availableSpeakers = config['available_speakers'] ?? {};

        // Add Flutter TTS as a speaker option
        if (_availableSpeakers is Map) {
          _availableSpeakers['flutter_tts'] = 'Flutter TTS (Device)';
        }

        _isLoadingConfig = false;

        // Set default model if not already set
        if (_selectedModelName.isEmpty && _availableModels.isNotEmpty) {
          final models = _availableModels[_selectedModelProvider] ?? {};
          if (models.isNotEmpty) {
            _selectedModelName = models.keys.first;
          }
        }

        // Set default speaker to Flutter TTS if not already set
        if (_selectedSpeakerId.isEmpty) {
          _selectedSpeakerId = 'flutter_tts';
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingConfig = false;
        // Set default speaker to Flutter TTS if config fails
        _selectedSpeakerId = 'flutter_tts';
      });
      print('Error loading config: $e');
    }
  }

  // Load user settings from backend
  void _loadUserSettings() async {
    try {
      print('[OkDriver] Loading user settings');
      final settings = await _assistantService.getUserSettings(_userId);

      // Save current speaker ID before updating
      final String previousSpeakerId = _selectedSpeakerId;

      setState(() {
        _selectedModelProvider = settings['modelProvider'] ?? 'together';
        _selectedModelName = settings['modelName'] ?? '';
        _selectedSpeakerId = settings['speakerId'] ?? 'flutter_tts';
        _enablePremium = settings['enablePremium'] ?? false;
      });

      print(
          '[OkDriver] Settings loaded: Speaker=$_selectedSpeakerId, Model=$_selectedModelProvider/$_selectedModelName');

      // If voice selection changed, reinitialize TTS
      if (previousSpeakerId != _selectedSpeakerId) {
        print(
            '[OkDriver] Voice selection changed during settings load, reinitializing TTS');
        _initTts();
      }
    } catch (e) {
      print('[OkDriver] Error loading user settings: $e');
      // Default to Flutter TTS if settings fail to load
      setState(() {
        _selectedSpeakerId = 'flutter_tts';
      });
      _initTts();
    }
  }

  // Save user settings to backend
  void _saveUserSettings() async {
    try {
      print(
          '[OkDriver] Saving user settings: Speaker=$_selectedSpeakerId, Model=$_selectedModelProvider/$_selectedModelName');

      // Save current speaker ID before updating
      final String previousSpeakerId = _selectedSpeakerId;

      await _assistantService.saveUserSettings(
        _userId,
        modelProvider: _selectedModelProvider,
        modelName: _selectedModelName,
        speakerId: _selectedSpeakerId,
        enablePremium: _enablePremium,
      );

      // If voice is changed to or from Flutter TTS, reinitialize TTS
      if (_selectedSpeakerId == 'flutter_tts' ||
          previousSpeakerId == 'flutter_tts') {
        print('[OkDriver] Voice selection changed, reinitializing TTS');
        _initTts();
      }

      // Show confirmation to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Settings saved successfully. Voice: ${_selectedSpeakerId == 'flutter_tts' ? 'Device TTS' : _availableSpeakers[_selectedSpeakerId] ?? _selectedSpeakerId}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[OkDriver] Error saving user settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Send message to backend API
  void _sendMessageToBackend(String message) async {
    if (message.isEmpty) return;

    final userMessage = ChatMessage(text: message, isUser: true);

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    // Scroll to bottom after adding user message
    _scrollToBottom();

    try {
      // Only send speakerId to backend if not using Flutter TTS
      final String backendSpeakerId = _selectedSpeakerId == 'flutter_tts'
          ? 'varun_chat' // Default backend voice when using Flutter TTS
          : _selectedSpeakerId;

      // Log outbound request
      // ignore: avoid_print
      print(
          '[OkDriver] Sending to backend => message:"$message", provider:$_selectedModelProvider, model:$_selectedModelName, speaker:$backendSpeakerId');

      final data = await _assistantService.sendMessage(
        message,
        _userId,
        modelProvider: _selectedModelProvider,
        modelName: _selectedModelName,
        speakerId: backendSpeakerId,
        enablePremium: _enablePremium,
      );
      final aiResponse = data['response'];
      final audioId = data['audio_id'];
      final modelUsed = data['model_used'];

      // Log inbound response
      // ignore: avoid_print
      print(
          '[OkDriver] Response <- model:$modelUsed, audioId:${audioId ?? 'null'}');
      // ignore: avoid_print
      print('[OkDriver] Assistant: $aiResponse');

      final assistantMessage = ChatMessage(text: aiResponse, isUser: false);

      setState(() {
        _messages.add(assistantMessage);
        _isLoading = false;
      });

      // Scroll to bottom after adding AI response
      _scrollToBottom();

      // Prioritize Flutter TTS for immediate response, or use API audio if selected
      if (_selectedSpeakerId == 'flutter_tts') {
        // Use device TTS for immediate response
        await _flutterTts.speak(aiResponse);
      } else if (_lowLatencyTts) {
        // If low latency is enabled, use Flutter TTS first for immediate response
        await _flutterTts.speak(aiResponse);
        // Then play the cloud audio when it's ready (if available)
        if (audioId != null && audioId.isNotEmpty) {
          _checkAudioStatus(audioId);
        }
      } else if (audioId != null && audioId.isNotEmpty) {
        // If user selected a cloud voice and audio is available, play it
        _checkAudioStatus(audioId);
      } else {
        // Fallback to Flutter TTS if no audio ID is provided
        await _flutterTts.speak(aiResponse);
      }

      // If we're in wake word mode, automatically start listening again after speaking
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _phase = _wakeWordEnabled
              ? AssistantPhase.wakeListening
              : AssistantPhase.idle;
        });

        // If wake word is enabled, start listening for it again
        if (_wakeWordEnabled && !_isWakeListening && !_isListening) {
          _startWakeWordListening();
        }
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
            text: "Network error. Please check your connection.",
            isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
      await _flutterTts.speak("Network error. Please check your connection.");
    }
  }

  // Check audio status and play when ready
  void _checkAudioStatus(String audioId) async {
    try {
      print('[OkDriver] Checking audio status for ID: $audioId');
      await _assistantService.pollAudioAndPlay(audioId);
    } catch (e) {
      print('[OkDriver] Error playing audio: $e');
      // Fallback to Flutter TTS if audio fails
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        print('[OkDriver] Falling back to Flutter TTS');
        await _flutterTts.speak(_messages.last.text);
      }
    }
  }

  // Scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        title: Text(
          'OkDriver Assistant',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(showHistory: false),
          ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'View History',
            onPressed: () => _showSettingsDialog(showHistory: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat area
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildChatList(),
          ),

          // Status indicator with waveform
          if (_isListening || _phase == AssistantPhase.speaking || _isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: StatusIndicator(
                isListening: _isListening,
                isProcessing: _isLoading,
                isSpeaking: _phase == AssistantPhase.speaking,
                isDarkMode: _isDarkMode,
              ),
            ),

          // Input area with wake word toggle and mic button
          glass.GlassContainer(
            color: _isDarkMode ? Colors.black : Colors.white,
            opacity: _isDarkMode ? 0.3 : 0.7,
            blur: 10.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Wake word toggle
                  Row(
                    children: [
                      Switch(
                        value: _wakeWordEnabled,
                        onChanged: (v) => _toggleWakeWord(v),
                        activeColor: const Color(0xFF9C27B0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Wake word',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  // Interactive microphone with wave animation
                  InteractiveMicrophone(
                      isListening: _isListening,
                      // isProcessing: _isLoading,
                      isWakeListening: _isWakeListening,
                      onTap: _listen
                      // isDarkMode: _isDarkMode,
                      // primaryColor: const Color(0xFF9C27B0),
                      // backgroundColor: _isDarkMode ? Colors.black : Colors.white,
                      // size: 60.0,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated wave for empty state with glass effect
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
                ),
              ],
            ),
            child: ClipOval(
              child: glass.GlassContainer(
                color: _isDarkMode ? Colors.black : Colors.white,
                opacity: 0.1,
                blur: 8.0,
                child: Center(
                  child: wave.WaveAnimation(
                    isActive: true,
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
              child: Column(
                children: [
                  Text(
                    'Tap the mic and start speaking',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'I can help you with driving tips, route suggestions, and more!',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return ChatBubble(
          message: _messages[index].text,
          isUser: _messages[index].isUser,
        );
      },
    );
  }

  // Show settings dialog
  void _showSettingsDialog({bool showHistory = false}) {
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        initialIndex: showHistory ? 1 : 0,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const TabBar(
                tabs: [
                  Tab(text: 'Settings'),
                  Tab(text: 'History'),
                ],
                labelColor: Color(0xFF9C27B0),
                indicatorColor: Color(0xFF9C27B0),
                unselectedLabelColor: Colors.grey,
              ),
              content: Container(
                width: double.maxFinite,
                height: 400, // Fixed height for dialog
                child: TabBarView(
                  children: [
                    // Settings Tab
                    _isLoadingConfig
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Premium toggle
                                SwitchListTile(
                                  title: const Text('Enable Premium'),
                                  subtitle: const Text('Access premium models'),
                                  value: _enablePremium,
                                  onChanged: (value) {
                                    setState(() {
                                      _enablePremium = value;

                                      // If premium is disabled, switch to together provider
                                      if (!_enablePremium &&
                                          _selectedModelProvider == 'openai') {
                                        _selectedModelProvider = 'together';

                                        // Select first non-premium model
                                        final models =
                                            _availableModels['together'] ?? {};
                                        if (models.isNotEmpty) {
                                          for (var entry in models.entries) {
                                            if (!entry.key.contains('70B') &&
                                                !entry.key
                                                    .contains('Premium')) {
                                              _selectedModelName = entry.key;
                                              break;
                                            }
                                          }
                                        }
                                      }
                                    });
                                  },
                                ),

                                const Divider(),

                                // Model provider selection
                                const Text('Model Provider',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedModelProvider,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  items: _availableModels.keys
                                      .map((provider) {
                                        // Only show OpenAI if premium is enabled
                                        if (provider == 'openai' &&
                                            !_enablePremium) {
                                          return null;
                                        }
                                        return DropdownMenuItem<String>(
                                          value: provider,
                                          child: Text(provider.toUpperCase()),
                                        );
                                      })
                                      .where((item) => item != null)
                                      .cast<DropdownMenuItem<String>>()
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedModelProvider = value;
                                        // Reset model selection
                                        final models =
                                            _availableModels[value] ?? {};
                                        if (models.isNotEmpty) {
                                          _selectedModelName =
                                              models.keys.first;
                                        }
                                      });
                                    }
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Model selection
                                const Text('Model',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedModelName.isNotEmpty
                                      ? _selectedModelName
                                      : null,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  items: (_availableModels[
                                              _selectedModelProvider] ??
                                          {})
                                      .entries
                                      .map((entry) {
                                        // Filter out premium models if premium is not enabled
                                        if (!_enablePremium &&
                                            (entry.key.contains('70B') ||
                                                entry.value
                                                    .toString()
                                                    .contains('Premium'))) {
                                          return null;
                                        }
                                        return DropdownMenuItem<String>(
                                          value: entry.key,
                                          child: Text(entry.value.toString()),
                                        );
                                      })
                                      .where((item) => item != null)
                                      .cast<DropdownMenuItem<String>>()
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedModelName = value;
                                      });
                                    }
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Speaker selection
                                const Text('Voice',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedSpeakerId,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  items: {
                                    'flutter_tts': 'Flutter TTS (Device)',
                                    ..._availableSpeakers as Map,
                                  }
                                      .entries
                                      .map((entry) => DropdownMenuItem<String>(
                                            value: entry.key,
                                            child: Text(entry.value.toString()),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedSpeakerId = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                    // History Tab
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_messages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'No conversation history yet',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: message.isUser
                                        ? Colors.blueGrey
                                        : const Color(0xFF9C27B0),
                                    child: Icon(
                                      message.isUser
                                          ? Icons.person
                                          : Icons.assistant,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    message.isUser ? 'You' : 'Assistant',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    message.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    // Show full message in a dialog
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(message.isUser
                                            ? 'You'
                                            : 'Assistant'),
                                        content: SingleChildScrollView(
                                          child: Text(message.text),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          const SizedBox(height: 20),
                          if (_messages.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                // Show confirmation dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Clear History'),
                                    content: Text(
                                        'Are you sure you want to clear all conversation history?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          this.setState(() {
                                            _messages.clear();
                                          });
                                          Navigator.pop(
                                              context); // Close confirmation dialog
                                          Navigator.pop(
                                              context); // Close settings dialog
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Conversation history cleared'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        },
                                        child: Text('Clear',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon:
                                  Icon(Icons.delete_outline, color: Colors.red),
                              label: Text('Clear History',
                                  style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update the main state with the new values from the dialog
                    this.setState(() {
                      // These values are already updated in the dialog's setState
                      // Just making sure they're properly applied to the main state
                    });
                    // Save settings and apply changes immediately
                    _saveUserSettings();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
