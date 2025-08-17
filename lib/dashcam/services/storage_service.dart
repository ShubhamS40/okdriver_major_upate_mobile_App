import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:okdriver/dashcam/models/video_file.dart';

enum StorageType { local, cloud }

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Save a video file to the specified storage
  Future<String> saveVideo({
    required String sourcePath,
    required StorageType storageType,
  }) async {
    switch (storageType) {
      case StorageType.local:
        return await _saveToLocalStorage(sourcePath);
      case StorageType.cloud:
        return await _saveToCloudStorage(sourcePath);
    }
  }

  // Save a video file to local storage
  Future<String> _saveToLocalStorage(String sourcePath) async {
    try {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = sourcePath.split('/').last;
      final destinationPath = '${directory.path}/$fileName';

      // If the source and destination are different, copy the file
      if (sourcePath != destinationPath) {
        final sourceFile = File(sourcePath);
        await sourceFile.copy(destinationPath);
      }

      return destinationPath;
    } catch (e) {
      throw Exception('Failed to save video to local storage: $e');
    }
  }

  // Save a video file to cloud storage (placeholder implementation)
  Future<String> _saveToCloudStorage(String sourcePath) async {
    // In a real implementation, this would upload the file to a cloud storage service
    // such as Firebase Storage, Google Drive, or a custom API
    // For now, we'll just save it locally and pretend it's in the cloud
    try {
      final localPath = await _saveToLocalStorage(sourcePath);
      // Pretend we've uploaded it to the cloud and got a URL back
      return 'https://cloud-storage.example.com/${localPath.split('/').last}';
    } catch (e) {
      throw Exception('Failed to save video to cloud storage: $e');
    }
  }

  // Get all saved videos from local storage
  Future<List<VideoFile>> getLocalVideos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = Directory(directory.path).listSync();

      // Filter for dashcam video files
      final videoFiles = <VideoFile>[];
      for (final file in files) {
        if (file.path.contains('dashcam_') && file.path.endsWith('.mp4')) {
          final videoFile = await VideoFile.fromPath(file.path);
          videoFiles.add(videoFile);
        }
      }

      // Sort by timestamp (newest first)
      videoFiles.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return videoFiles;
    } catch (e) {
      throw Exception('Failed to get local videos: $e');
    }
  }

  // Get all saved videos from cloud storage (placeholder implementation)
  Future<List<VideoFile>> getCloudVideos() async {
    // In a real implementation, this would fetch video metadata from a cloud storage service
    // For now, we'll just return an empty list
    return [];
  }

  // Delete a video file
  Future<void> deleteVideo(VideoFile videoFile) async {
    try {
      if (videoFile.isCloudSaved) {
        // In a real implementation, this would delete the file from cloud storage
        // For now, we'll just delete the local file
        await videoFile.delete();
      } else {
        await videoFile.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete video: $e');
    }
  }

  // Get the total size of all saved videos
  Future<int> getTotalVideoSize() async {
    try {
      final localVideos = await getLocalVideos();
      int total = 0;
      for (var video in localVideos) {
        total += await video.size;
      }
      return total;
    } catch (e) {
      throw Exception('Failed to get total video size: $e');
    }
  }

  // Get the available storage space
  Future<int> getAvailableStorageSpace() async {
    try {
      // This is a simplified implementation
      // In a real app, you would use a platform-specific method to get available space
      final directory = await getApplicationDocumentsDirectory();
      final stat = await Directory(directory.path).statSync();
      // This is not accurate, but it's a placeholder
      return 1024 * 1024 * 1024; // 1 GB
    } catch (e) {
      throw Exception('Failed to get available storage space: $e');
    }
  }
}
