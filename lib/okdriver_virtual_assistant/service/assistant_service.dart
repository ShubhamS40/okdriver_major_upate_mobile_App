import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'package:just_audio/just_audio.dart';
import 'package:okdriver/service/api_config.dart';

class AssistantService {
  // Base URL for the backend API
  static const String baseUrl = ApiConfig.baseUrl;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Send a message to the backend API with model and speaker selection
  Future<Map<String, dynamic>> sendMessage(
    String message,
    String userId, {
    required String modelProvider,
    required String modelName,
    required String speakerId,
    bool enablePremium = false,
  }) async {
    try {
      // ignore: avoid_print
      print('[OkDriver][HTTP] POST /api/assistant/chat');
      final response = await http.post(
        Uri.parse('$baseUrl/api/assistant/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'userId': userId,
          'modelProvider': modelProvider,
          'modelName': modelName,
          'speakerId': speakerId,
          'enablePremium': enablePremium,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // ignore: avoid_print
        print(
            '[OkDriver][HTTP] 200 OK body: ${json.encode(decoded).substring(0, decoded.toString().length > 300 ? 300 : json.encode(decoded).length)}');
        return decoded;
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Check audio status
  Future<Map<String, dynamic>> checkAudioStatus(String audioId) async {
    try {
      // ignore: avoid_print
      print('[OkDriver][HTTP] GET /api/assistant/audio-status/$audioId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/assistant/audio-status/$audioId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check audio status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Poll audio status with short backoff for lower perceived latency
  Future<void> pollAudioAndPlay(String audioId) async {
    const delays = [500, 700, 900, 1200, 1500];
    for (final ms in delays) {
      final status = await checkAudioStatus(audioId);
      if (status['status'] == 'completed' && status['audio_url'] != null) {
        await playAudio(status['audio_url']);
        return;
      }
      await Future.delayed(Duration(milliseconds: ms));
    }
  }

  // Get conversation history
  Future<List<ChatMessage>> getHistory(String userId) async {
    try {
      // ignore: avoid_print
      print('[OkDriver][HTTP] GET /api/assistant/history/$userId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/assistant/history/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> historyData = data['history'];

        return historyData.map((item) {
          return ChatMessage(
            text: item['content'],
            isUser: item['role'] == 'user',
          );
        }).toList();
      } else {
        throw Exception('Failed to get history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Clear conversation history
  Future<void> clearHistory(String userId) async {
    try {
      // ignore: avoid_print
      print('[OkDriver][HTTP] DELETE /api/assistant/history/$userId');
      final response = await http.delete(
        Uri.parse('$baseUrl/api/assistant/history/$userId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to clear history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Play audio from URL
  Future<void> playAudio(String audioUrl) async {
    try {
      // Stop any currently playing audio
      await _audioPlayer.stop();

      // Set the URL source - audioUrl already contains the full URL
      // The error was due to concatenating baseUrl with a URL that already had the base URL
      final url = audioUrl.startsWith('http') ? audioUrl : '$baseUrl$audioUrl';

      print('Playing audio from: $url');
      await _audioPlayer.setUrl(url);

      // Play the audio
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing audio: $e');
      throw Exception('Failed to play audio: $e');
    }
  }

  // Removed playLatestAudio; endpoint not provided by backend

  // Dispose audio player resources
  void dispose() {
    _audioPlayer.dispose();
  }

  // Get available models and speakers from backend
  Future<Map<String, dynamic>> getAvailableConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/assistant/config'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get user settings
  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/assistant/settings/$userId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get user settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Save user settings
  Future<void> saveUserSettings(
    String userId, {
    required String modelProvider,
    required String modelName,
    required String speakerId,
    required bool enablePremium,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/assistant/settings/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'modelProvider': modelProvider,
          'modelName': modelName,
          'speakerId': speakerId,
          'enablePremium': enablePremium,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
