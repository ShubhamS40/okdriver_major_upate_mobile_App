import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:provider/provider.dart';
import 'package:okdriver/theme/theme_provider.dart';

import 'components/chat_bubble.dart';
import 'models/chat_message.dart';
import 'service/assistant_service.dart';

class OkDriverVirtualAssistantScreen extends StatefulWidget {
  const OkDriverVirtualAssistantScreen({super.key});

  @override
  State<OkDriverVirtualAssistantScreen> createState() =>
      _OkDriverVirtualAssistantScreenState();
}

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

  // Model and speaker selection
  Map<String, dynamic> _availableModels = {};
  Map<String, dynamic> _availableSpeakers = {};
  String _selectedModelProvider = 'together';
  String _selectedModelName = '';
  String _selectedSpeakerId =
      'varun_chat'; // Default speaker, can also be 'keerti_joy'
  bool _enablePremium = false;
  bool _isLoadingConfig = true;

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

      // Load conversation history
      _loadHistory();
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
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() {
            _isListening = false;
          });
          if (_text.isNotEmpty) {
            _sendMessageToBackend(_text);
          }
        }
      },
    );
  }

  // Initialize text-to-speech
  void _initTts() async {
    await _flutterTts
        .setLanguage("hi-IN"); // Hindi language for Hinglish support
    await _flutterTts
        .setSpeechRate(0.5); // Slower speech rate for better understanding
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
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

  // Start listening to user's voice
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
            });
          },
          localeId:
              "en_IN", // English (India) for better recognition of Indian accent
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
      if (_text.isNotEmpty) {
        _sendMessageToBackend(_text);
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
        _isLoadingConfig = false;

        // Set default model if not already set
        if (_selectedModelName.isEmpty && _availableModels.isNotEmpty) {
          final models = _availableModels[_selectedModelProvider] ?? {};
          if (models.isNotEmpty) {
            _selectedModelName = models.keys.first;
          }
        }

        // Set default speaker if not already set
        if (_selectedSpeakerId.isEmpty && _availableSpeakers.isNotEmpty) {
          _selectedSpeakerId = _availableSpeakers.keys.first;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingConfig = false;
      });
      print('Error loading config: $e');
    }
  }

  // Load user settings from backend
  void _loadUserSettings() async {
    try {
      final settings = await _assistantService.getUserSettings(_userId);

      setState(() {
        _selectedModelProvider = settings['modelProvider'] ?? 'together';
        _selectedModelName = settings['modelName'] ?? '';
        _selectedSpeakerId = settings['speakerId'] ??
            'varun_chat'; // Can also default to 'keerti_joy'
        _enablePremium = settings['enablePremium'] ?? false;
      });
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  // Save user settings to backend
  void _saveUserSettings() async {
    try {
      await _assistantService.saveUserSettings(
        _userId,
        modelProvider: _selectedModelProvider,
        modelName: _selectedModelName,
        speakerId: _selectedSpeakerId,
        enablePremium: _enablePremium,
      );
    } catch (e) {
      print('Error saving user settings: $e');
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
      final data = await _assistantService.sendMessage(
        message,
        _userId,
        modelProvider: _selectedModelProvider,
        modelName: _selectedModelName,
        speakerId: _selectedSpeakerId,
        enablePremium: _enablePremium,
      );
      final aiResponse = data['response'];
      final audioId = data['audio_id'];

      final assistantMessage = ChatMessage(text: aiResponse, isUser: false);

      setState(() {
        _messages.add(assistantMessage);
        _isLoading = false;
      });

      // Scroll to bottom after adding AI response
      _scrollToBottom();

      // Check for audio URL and play when available
      // If Maya AI audio is not available, fall back to Flutter TTS
      if (audioId != null && audioId.isNotEmpty) {
        _checkAudioStatus(audioId);
      } else {
        // Fallback to Flutter TTS if no audio ID is provided
        await _flutterTts.speak(aiResponse);
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
            text: "Network error. Please check your connection.",
            isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  // Check audio status and play if available
  void _checkAudioStatus(String audioId) async {
    try {
      final data = await _assistantService.checkAudioStatus(audioId);
      if (data['status'] == 'completed' && data['audio_url'] != null) {
        // Audio is ready, play it using the audio player
        final audioUrl = data['audio_url'];
        print('Audio URL received: $audioUrl');
        await _assistantService.playAudio(audioUrl);
      } else if (data['status'] == 'pending') {
        // If audio is still pending, check again after a delay
        print('Audio still pending, checking again in 2 seconds');
        Future.delayed(const Duration(seconds: 2), () {
          _checkAudioStatus(audioId);
        });
      }
    } catch (e) {
      // Handle error silently
      print('Error checking audio status: $e');
      // Fallback to Flutter TTS if there's an error with Maya AI audio
      final lastMessage = _messages.isNotEmpty ? _messages.last : null;
      if (lastMessage != null && !lastMessage.isUser) {
        await _flutterTts.speak(lastMessage.text);
      }
    }
  }

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

  void _clearHistory() async {
    try {
      await _assistantService.clearHistory(_userId);
      setState(() {
        _messages = [];
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // Play latest audio file from backend
  void _playLatestAudio() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _assistantService.playLatestAudio();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error playing latest audio: $e');
      setState(() {
        _isLoading = false;
      });

      // Show a snackbar with the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play latest audio'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context);
    _isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OkDriver Assistant'),
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
          // Play latest audio button
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _playLatestAudio,
            tooltip: 'Play latest audio',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isNotEmpty ? _clearHistory : null,
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _messages.isEmpty ? _buildEmptyState() : _buildChatList(),
            ),
          ),

          // Loading indicator
          if (_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _text.isEmpty ? 'Listening...' : _text,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _isDarkMode ? Colors.purpleAccent : Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

          // Input area with mic button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mic button with glow effect
                AvatarGlow(
                  animate: _isListening,
                  glowColor: const Color(0xFF9C27B0),
                  glowRadiusFactor: 60.0,
                  duration: const Duration(milliseconds: 2000),
                  // repeatPauseDuration: const Duration(milliseconds: 100),
                  repeat: true,
                  child: GestureDetector(
                    onTap: _listen,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9C27B0).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
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
          Icon(
            Icons.smart_toy_rounded,
            size: 80,
            color: _isDarkMode
                ? const Color(0xFF9C27B0).withOpacity(0.7)
                : const Color(0xFF9C27B0),
          ),
          const SizedBox(height: 20),
          Text(
            'Tap the mic and start speaking',
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'I can help you with driving tips, route suggestions, and more!',
            style: TextStyle(
              color: _isDarkMode ? Colors.white54 : Colors.black45,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
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
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Assistant Settings'),
            content: _isLoadingConfig
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
                                        !entry.key.contains('Premium')) {
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
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
                                if (provider == 'openai' && !_enablePremium) {
                                  return null;
                                }
                                return DropdownMenuItem<String>(
                                  value: provider,
                                  child: Text(provider == 'together'
                                      ? 'Together AI'
                                      : 'OpenAI'),
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
                                final models = _availableModels[value] ?? {};
                                if (models.isNotEmpty) {
                                  // Select first model that matches premium status
                                  for (var entry in models.entries) {
                                    final isPremiumModel =
                                        entry.key.contains('70B') ||
                                            entry.key.contains('Premium') ||
                                            entry.key.contains('gpt-4');

                                    if (_enablePremium || !isPremiumModel) {
                                      _selectedModelName = entry.key;
                                      break;
                                    }
                                  }
                                }
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // Model selection
                        const Text('AI Model',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
                          items:
                              (_availableModels[_selectedModelProvider] ?? {})
                                  .entries
                                  .map((entry) {
                                    final isPremiumModel =
                                        entry.key.contains('70B') ||
                                            entry.key.contains('Premium') ||
                                            entry.key.contains('gpt-4');

                                    // Only show premium models if premium is enabled
                                    if (isPremiumModel && !_enablePremium) {
                                      return null;
                                    }

                                    return DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value),
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
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedSpeakerId.isNotEmpty
                              ? _selectedSpeakerId
                              : null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: _availableSpeakers.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
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
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Save settings
                  _saveUserSettings();

                  // Update state in parent widget
                  this.setState(() {
                    // Update state variables
                  });

                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
