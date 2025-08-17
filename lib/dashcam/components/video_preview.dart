import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class VideoPreview extends StatelessWidget {
  final CameraController cameraController;
  final bool isRecording;
  final bool isPaused;
  final String recordingDuration;
  final String cameraTypeLabel;

  const VideoPreview({
    Key? key,
    required this.cameraController,
    required this.isRecording,
    required this.isPaused,
    required this.recordingDuration,
    required this.cameraTypeLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate 50% of screen width for square preview
    final previewSize = MediaQuery.of(context).size.width * 0.5;

    return Column(
      children: [
        // Camera preview (square shape)
        Center(
          child: Container(
            width: previewSize,
            height: previewSize, // Square shape with 50% of screen width
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraPreview(cameraController),
            ),
          ),
        ),

        // Recording status bar
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Recording status and duration
              Row(
                children: [
                  Icon(
                    isRecording
                        ? isPaused
                            ? Icons.pause
                            : Icons.fiber_manual_record
                        : Icons.stop,
                    color: isRecording && !isPaused ? Colors.red : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? recordingDuration : 'Ready',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),

              // Camera type indicator
              Text(
                'Camera: $cameraTypeLabel',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SavedVideoPreview extends StatelessWidget {
  final String videoPath;
  final String duration;
  final String timestamp;
  final VoidCallback onPlayPressed;
  final VoidCallback onDeletePressed;

  const SavedVideoPreview({
    Key? key,
    required this.videoPath,
    required this.duration,
    required this.timestamp,
    required this.onPlayPressed,
    required this.onDeletePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video thumbnail (would use actual thumbnail in a real implementation)
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.black,
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.play_circle_fill,
                  size: 48,
                  color: Colors.white,
                ),
                onPressed: onPlayPressed,
              ),
            ),
          ),

          // Video details
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recorded: $timestamp',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Duration: $duration'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                      onPressed: onPlayPressed,
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: onDeletePressed,
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
}
