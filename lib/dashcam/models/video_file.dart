import 'dart:io';

class VideoFile {
  final String path;
  final DateTime timestamp;
  final String duration;
  final int size;
  final bool isCloudSaved;

  VideoFile({
    required this.path,
    required this.timestamp,
    required this.duration,
    required this.size,
    this.isCloudSaved = false,
  });

  // Create a VideoFile from a file path
  static Future<VideoFile> fromPath(String path) async {
    final file = File(path);
    final fileName = path.split('/').last;

    // Extract timestamp from filename (dashcam_1234567890.mp4)
    DateTime timestamp;
    try {
      final timestampStr = fileName.split('_')[1].split('.')[0];
      timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
    } catch (e) {
      // Fallback to file creation time
      timestamp = await file.lastModified();
    }

    // Get file size
    final size = await file.length();

    // In a real implementation, we would extract the actual duration
    // For now, we'll use a placeholder
    const duration = '00:00';

    return VideoFile(
      path: path,
      timestamp: timestamp,
      duration: duration,
      size: size,
    );
  }

  // Format the timestamp for display
  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  // Format the file size for display
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Get the file name
  String get fileName {
    return path.split('/').last;
  }

  // Delete the file
  Future<void> delete() async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Create a copy of this VideoFile with updated properties
  VideoFile copyWith({
    String? path,
    DateTime? timestamp,
    String? duration,
    int? size,
    bool? isCloudSaved,
  }) {
    return VideoFile(
      path: path ?? this.path,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      isCloudSaved: isCloudSaved ?? this.isCloudSaved,
    );
  }
}
