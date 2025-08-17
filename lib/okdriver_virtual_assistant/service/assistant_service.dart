import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'package:just_audio/just_audio.dart';

class AssistantService {
  // Base URL for the backend API
  static const String baseUrl = 'http://98.70.99.58:3000';

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
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
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
        return json.decode(response.body);
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/audio-status/$audioId'),
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

  // Get conversation history
  Future<List<ChatMessage>> getHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/history/$userId'),
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
      final response = await http.delete(
        Uri.parse('$baseUrl/api/history/$userId'),
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

  // Play latest audio file from backend
  Future<void> playLatestAudio() async {
    try {
      // Get the latest audio file from the backend
      final response = await http.get(
        Uri.parse('$baseUrl/api/latest-audio'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['audio_url'] != null) {
          await playAudio(data['audio_url']);
        } else {
          throw Exception('No audio URL found');
        }
      } else {
        throw Exception('Failed to get latest audio: ${response.statusCode}');
      }
    } catch (e) {
      print('Error playing latest audio: $e');
      throw Exception('Failed to play latest audio: $e');
    }
  }

  // Dispose audio player resources
  void dispose() {
    _audioPlayer.dispose();
  }

  // Get available models and speakers from backend
  Future<Map<String, dynamic>> getAvailableConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/config'),
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
        Uri.parse('$baseUrl/api/settings/$userId'),
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
        Uri.parse('$baseUrl/api/settings/$userId'),
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
