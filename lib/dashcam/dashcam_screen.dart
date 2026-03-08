import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:permission_handler/permission_handler.dart';

import 'components/camera_selection.dart';

class DashcamScreen extends StatefulWidget {
  final CameraType cameraType;

  const DashcamScreen({
    Key? key,
    required this.cameraType,
  }) : super(key: key);

  @override
  State<DashcamScreen> createState() => _DashcamScreenState();
}

class _DashcamScreenState extends State<DashcamScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _recorderChannel =
      MethodChannel('com.example.okdriver/recorder');

  bool _isRecording = false;
  String _recordingDuration = '00:00';
  // Default recording segment duration
  String _selectedDuration = '10m';
  String _storageOption = 'local';
  bool _recordAudio = true; // mic mute/unmute toggle
  Timer? _recordingTimer;
  int _elapsedSeconds = 0;

  static const String _supportEmail = 'support@okdriver.in';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncServiceStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRecordingTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recorderChannel.invokeMethod('updateVisibility', {
      'visible': state == AppLifecycleState.resumed,
    });
  }

  Future<void> _syncServiceStatus() async {
    try {
      final status =
          await _recorderChannel.invokeMethod<bool>('isRunning') ?? false;
      if (mounted) {
        setState(() {
          _isRecording = status;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermissions = await _ensurePermissions();
    if (!hasPermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Camera aur microphone permission enable karo dashcam recording ke liye.'),
        ),
      );
      return;
    }

    try {
      await _recorderChannel.invokeMethod('startService', {
        'cameraType': widget.cameraType.toString().split('.').last,
        'segmentMinutes': _getDurationInMinutes(),
        'recordAudio': _recordAudio,
      });
      setState(() {
        _isRecording = true;
        _elapsedSeconds = 0;
        _recordingDuration = '00:00';
      });
      _startRecordingTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording start nahi ho payi: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _stopRecordingTimer();
    try {
      await _recorderChannel.invokeMethod('stopService');
      setState(() {
        _isRecording = false;
        _elapsedSeconds = 0;
        _recordingDuration = '00:00';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording stop nahi ho payi: $e')),
      );
    }
  }

  Future<bool> _ensurePermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    if (cameraStatus.isGranted && micStatus.isGranted) {
      return true;
    }

    final cameraResult = await Permission.camera.request();
    final micResult = await Permission.microphone.request();

    return cameraResult.isGranted && micResult.isGranted;
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _elapsedSeconds++;
        final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
        _recordingDuration = '$minutes:$seconds';
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  int _getDurationInMinutes() {
    switch (_selectedDuration) {
      case '20m':
        return 20;
      case '30m':
        return 30;
      case '10m':
      default:
        return 10;
    }
  }

  double _calculateProgressValue() {
    final totalSeconds = _getDurationInMinutes() * 60;
    if (totalSeconds == 0) return 0;
    final value = _elapsedSeconds / totalSeconds;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  void _setRecordingDuration(String value) {
    setState(() {
      _selectedDuration = value;
    });
  }

  void _setStorageOption(String value) {
    setState(() {
      _storageOption = value;
    });

    if (value == 'cloud') {
      _showCloudSupportDialog();
    }
  }

  Future<void> _showCloudSupportDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cloud Storage Support'),
          content: const Text(
            'Cloud storage setup/help ke liye contact karein:\n\nsupport@okdriver.in',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                    const ClipboardData(text: _supportEmail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Email copied: support@okdriver.in')),
                  );
                }
              },
              child: const Text('Copy email'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashcam'),
      ),
      body: Column(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: _isRecording
                  ? const AndroidView(
                      viewType: 'camera_preview_view',
                      creationParamsCodec: StandardMessageCodec(),
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'Dashcam ready \n Click start to begin recording',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isRecording
                          ? Icons.fiber_manual_record
                          : Icons.stop_circle_outlined,
                      color: _isRecording ? Colors.red : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRecording ? _recordingDuration : 'Ready',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  'Camera: ${widget.cameraType.toString().split('.').last}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recording Duration:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDurationOption('10m', '10 min'),
                      _buildDurationOption('20m', '20 min'),
                      _buildDurationOption('30m', '30 min'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Storage Option:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildStorageOption('local', 'Local Storage'),
                      _buildStorageOption('cloud', 'Cloud Storage'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isRecording)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recording Progress:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _calculateProgressValue(),
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: Row(
              children: [
                // Start / Stop recording button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording
                          ? Colors.red.shade600
                          : Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      size: 24,
                    ),
                    label: Text(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Mic mute/unmute toggle
                Tooltip(
                  message: _recordAudio
                      ? 'Tap to mute audio (video only)'
                      : 'Tap to record audio with video',
                  child: InkWell(
                    onTap: _isRecording
                        ? null
                        : () {
                            setState(() {
                              _recordAudio = !_recordAudio;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_recordAudio
                                    ? 'Audio recording enabled'
                                    : 'Audio muted — only video will be saved'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recordAudio
                            ? Colors.black.withOpacity(0.8)
                            : Colors.grey.shade400,
                      ),
                      child: Icon(
                        _recordAudio ? Icons.mic : Icons.mic_off,
                        color: _isRecording ? Colors.white54 : Colors.white,
                        size: 24,
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

  Widget _buildDurationOption(String value, String label) {
    final isSelected = _selectedDuration == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _setRecordingDuration(value);
        }
      },
    );
  }

  Widget _buildStorageOption(String value, String label) {
    final isSelected = _storageOption == value;
    return ChoiceChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _setStorageOption(value);
        }
      },
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
    );
  }
}
