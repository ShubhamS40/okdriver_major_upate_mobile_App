import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({Key? key}) : super(key: key);

  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  List<VideoFile> _videoFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedVideos();
  }

  Future<void> _loadSavedVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = Directory(directory.path).listSync();

      // Filter for dashcam video files
      final videoFiles = files
          .where((file) =>
              file.path.contains('dashcam_') && file.path.endsWith('.mp4'))
          .map((file) {
        final fileName = file.path.split('/').last;
        final timestamp = _extractTimestampFromFileName(fileName);
        return VideoFile(
          path: file.path,
          timestamp: timestamp,
          duration: '00:00', // In a real app, we would extract actual duration
          size: File(file.path).lengthSync(),
        );
      }).toList();

      // Sort by timestamp (newest first)
      videoFiles.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _videoFiles = videoFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading videos: $e')),
      );
    }
  }

  DateTime _extractTimestampFromFileName(String fileName) {
    try {
      // Extract timestamp from dashcam_1234567890.mp4 format
      final timestampStr = fileName.split('_')[1].split('.')[0];
      return DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
    } catch (e) {
      return DateTime.now(); // Fallback
    }
  }

  Future<void> _deleteVideo(VideoFile videoFile) async {
    try {
      final file = File(videoFile.path);
      if (await file.exists()) {
        await file.delete();
        setState(() {
          _videoFiles.remove(videoFile);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting video: $e')),
      );
    }
  }

  void _playVideo(VideoFile videoFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoFile: videoFile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recordings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedVideos,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videoFiles.isEmpty
              ? const Center(child: Text('No saved recordings found'))
              : ListView.builder(
                  itemCount: _videoFiles.length,
                  itemBuilder: (context, index) {
                    final videoFile = _videoFiles[index];
                    return _buildVideoItem(videoFile);
                  },
                ),
    );
  }

  Widget _buildVideoItem(VideoFile videoFile) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video thumbnail (would use actual thumbnail in a real implementation)
          Container(
            height: 180,
            width: double.infinity,
            color: Colors.black,
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.play_circle_fill,
                  size: 64,
                  color: Colors.white,
                ),
                onPressed: () => _playVideo(videoFile),
              ),
            ),
          ),

          // Video details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recorded: ${_formatDateTime(videoFile.timestamp)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 4),
                    Text('Duration: ${videoFile.duration}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.storage, size: 16),
                    const SizedBox(width: 4),
                    Text('Size: ${_formatFileSize(videoFile.size)}'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                      onPressed: () => _playVideo(videoFile),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: () => _showDeleteConfirmation(videoFile),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  void _showDeleteConfirmation(VideoFile videoFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVideo(videoFile);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final VideoFile videoFile;

  const VideoPlayerScreen({Key? key, required this.videoFile})
      : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoFile.path));
    await _controller.initialize();
    setState(() {
      _isInitialized = true;
    });
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recorded: ${_formatDateTime(widget.videoFile.timestamp)}'),
      ),
      body: _isInitialized
          ? Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.all(16),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                    ),
                  ],
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class VideoFile {
  final String path;
  final DateTime timestamp;
  final String duration;
  final int size;

  VideoFile({
    required this.path,
    required this.timestamp,
    required this.duration,
    required this.size,
  });
}
