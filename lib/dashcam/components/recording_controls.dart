import 'package:flutter/material.dart';

class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onRecordPressed;
  final VoidCallback onPauseResumePressed;
  final VoidCallback onDeletePressed;

  const RecordingControls({
    Key? key,
    required this.isRecording,
    required this.isPaused,
    required this.onRecordPressed,
    required this.onPauseResumePressed,
    required this.onDeletePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Record/Stop button
          _buildControlButton(
            icon: Icon(
              isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: isRecording ? Colors.black : Colors.red,
              size: 36,
            ),
            onPressed: onRecordPressed,
            tooltip: isRecording ? 'Stop Recording' : 'Start Recording',
          ),

          // Pause/Resume button (only shown when recording)
          if (isRecording)
            _buildControlButton(
              icon: Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                size: 36,
              ),
              onPressed: onPauseResumePressed,
              tooltip: isPaused ? 'Resume Recording' : 'Pause Recording',
            ),

          // Delete button
          _buildControlButton(
            icon: const Icon(
              Icons.delete,
              size: 36,
            ),
            onPressed: onDeletePressed,
            tooltip: 'Delete Recording',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required Icon icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class RecordingOptions extends StatelessWidget {
  final String selectedDuration;
  final String storageOption;
  final Function(String) onDurationChanged;
  final Function(String) onStorageOptionChanged;

  const RecordingOptions({
    Key? key,
    required this.selectedDuration,
    required this.storageOption,
    required this.onDurationChanged,
    required this.onStorageOptionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration selection
          const Text(
            'Recording Duration:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDurationOption('15m', '15 min'),
              _buildDurationOption('30m', '30 min'),
              _buildDurationOption('1h', '1 hour'),
            ],
          ),

          const SizedBox(height: 24),

          // Storage option
          const Text(
            'Storage Option:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStorageOption('local', 'Local Storage'),
              _buildStorageOption('cloud', 'Cloud Storage'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationOption(String value, String label) {
    final isSelected = selectedDuration == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onDurationChanged(value);
        }
      },
    );
  }

  Widget _buildStorageOption(String value, String label) {
    final isSelected = storageOption == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onStorageOptionChanged(value);
        }
      },
    );
  }
}

class RecordingProgressBar extends StatelessWidget {
  final double progress;
  final String duration;

  const RecordingProgressBar({
    Key? key,
    required this.progress,
    required this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recording Progress:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(duration),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
        ),
      ],
    );
  }
}
