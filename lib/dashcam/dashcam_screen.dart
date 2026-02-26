import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _selectedDuration = '15m';
  String _storageOption = 'local';
  Timer? _recordingTimer;
  int _elapsedSeconds = 0;

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
      case '30m':
        return 30;
      case '1h':
        return 60;
      case '15m':
      default:
        return 15;
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
                          'Dashcam ready\nRecord button dabao start karne ke liye',
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
                      _buildDurationOption('15m', '15 min'),
                      _buildDurationOption('30m', '30 min'),
                      _buildDurationOption('1h', '1 hour'),
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    color: _isRecording ? Colors.black : Colors.red,
                    size: 36,
                  ),
                  onPressed: _toggleRecording,
                  tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
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
