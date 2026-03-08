import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

enum VoiceMode { flutterTts, xtts }

class VoicePreferences {
  static VoiceMode voiceMode = VoiceMode.flutterTts;
}

enum WsMessageType { status, transcript, textChunk, audioChunk, done, error }

class WsMessage {
  final WsMessageType type;
  final String? text, audio, msg, fullText;

  WsMessage(
      {required this.type, this.text, this.audio, this.msg, this.fullText});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final t = json['type'] as String? ?? '';
    WsMessageType type;
    switch (t) {
      case 'status':
        type = WsMessageType.status;
        break;
      case 'transcript':
        type = WsMessageType.transcript;
        break;
      case 'text_chunk':
        type = WsMessageType.textChunk;
        break;
      case 'audio_chunk':
        type = WsMessageType.audioChunk;
        break;
      case 'done':
        type = WsMessageType.done;
        break;
      default:
        type = WsMessageType.error;
        break;
    }
    return WsMessage(
      type: type,
      text: json['text'] as String?,
      audio: json['audio'] as String?,
      msg: json['msg'] as String?,
      fullText: json['full_text'] as String?,
    );
  }
}

typedef OnStatusUpdate = void Function(String);
typedef OnTranscript = void Function(String);
typedef OnTextChunk = void Function(String);
typedef OnDone = void Function(String);
typedef OnError = void Function(String);

class AssistantService {
  static const String serverIp = '20.204.177.196';
  static const int serverPort = 4000;
  static String get wsUrl => 'ws://$serverIp:$serverPort/ws/talk';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlayingAudio = false;
  bool _isConnected = false;

  /// false = Flutter TTS mode (backend XTTS skip karega)
  bool enableAudioPlayback = false;

  OnStatusUpdate? onStatusUpdate;
  OnTranscript? onTranscript;
  OnTextChunk? onTextChunk;
  OnDone? onDone;
  OnError? onError;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;
    try {
      print('[WS] Connecting to $wsUrl');
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _sub = _channel!.stream
          .listen(_onMessage, onError: _onWsError, onDone: _onWsDone);
      print('[WS] Connected');
    } catch (e) {
      _isConnected = false;
      onError?.call('Connection failed: $e');
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
  }

  // Backend ko mode batao — XTTS chahiye ya nahi
  Future<void> _sendConfig() async {
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'config',
        'generate_tts': enableAudioPlayback,
      }));
      print('[WS] Config → generate_tts=$enableAudioPlayback');
    } catch (e) {
      print('[WS] Config error: $e');
    }
  }

  // Config pehle bhejo, phir audio bytes
  Future<void> sendAudio(Uint8List bytes) async {
    if (!_isConnected) await connect();
    await _sendConfig();
    try {
      _channel!.sink.add(bytes);
      print('[WS] Sent ${bytes.length} bytes');
    } catch (e) {
      print('[WS] Send error: $e');
      onError?.call('Send failed: $e');
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg = WsMessage.fromJson(map);
      switch (msg.type) {
        case WsMessageType.status:
          onStatusUpdate?.call(msg.msg ?? '');
          break;
        case WsMessageType.transcript:
          onTranscript?.call(msg.text ?? '');
          break;
        case WsMessageType.textChunk:
          onTextChunk?.call(msg.text ?? '');
          break;
        case WsMessageType.audioChunk:
          if (enableAudioPlayback &&
              msg.audio != null &&
              msg.audio!.isNotEmpty) {
            _enqueueAudio(base64Decode(msg.audio!));
          }
          break;
        case WsMessageType.done:
          onDone?.call(msg.fullText ?? '');
          break;
        case WsMessageType.error:
          onError?.call(msg.msg ?? 'Unknown error');
          break;
      }
    } catch (e) {
      print('[WS] Parse error: $e');
    }
  }

  void _enqueueAudio(Uint8List bytes) {
    _audioQueue.add(bytes);
    if (!_isPlayingAudio) _playNext();
  }

  Future<void> _playNext() async {
    if (_audioQueue.isEmpty) {
      _isPlayingAudio = false;
      return;
    }
    _isPlayingAudio = true;
    final bytes = _audioQueue.removeAt(0);
    try {
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/ok_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(bytes);
      await _player.setFilePath(file.path);
      await _player.play();
      await _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed);
      await file.delete();
    } catch (e) {
      print('[Audio] Playback error: $e');
    }
    _playNext();
  }

  Future<void> stopAudio() async {
    _audioQueue.clear();
    _isPlayingAudio = false;
    await _player.stop();
  }

  void _onWsError(e) {
    _isConnected = false;
    onError?.call('WebSocket error: $e');
  }

  void _onWsDone() {
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _player.dispose();
  }

  // Legacy stubs
  Future<Map<String, dynamic>> sendMessage(String msg, String uid,
          {String modelProvider = '',
          String modelName = '',
          String speakerId = '',
          bool enablePremium = false}) async =>
      {'response': '', 'audio_id': null, 'model_used': 'groq'};
  Future<Map<String, dynamic>> getAvailableConfig() async => {
        'available_models': {
          'groq': {'llama-3.3-70b-versatile': 'Llama 3.3 70B'}
        },
        'available_speakers': {'ana_florence': 'Ana Florence (XTTS)'},
      };
  Future<Map<String, dynamic>> getUserSettings(String uid) async => {
        'modelProvider': 'groq',
        'modelName': 'llama-3.3-70b-versatile',
        'speakerId': 'ana_florence',
        'enablePremium': false
      };
  Future<void> saveUserSettings(String uid,
      {String modelProvider = '',
      String modelName = '',
      String speakerId = '',
      bool enablePremium = false}) async {}
  Future<List<dynamic>> getHistory(String uid) async => [];
  Future<void> pollAudioAndPlay(String audioId) async {}
}
