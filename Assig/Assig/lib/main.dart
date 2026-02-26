import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: DarkRecorder(), debugShowCheckedModeBanner: false));

class DarkRecorder extends StatefulWidget {
  const DarkRecorder({super.key});
  @override
  State<DarkRecorder> createState() => _DarkRecorderState();
}

class _DarkRecorderState extends State<DarkRecorder> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.dark.okdriver/recorder');
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
     Timer.periodic(const Duration(seconds: 1), (timer) => _updateStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    platform.invokeMethod('updateVisibility', {"visible": state == AppLifecycleState.resumed});
  }

  Future<void> _updateStatus() async {
    final bool status = await platform.invokeMethod('isRunning');
    if (mounted && status != _isRunning) setState(() => _isRunning = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [

            _buildHeader(),
            const SizedBox(height: 10),
            Expanded(
              child: _isRunning
                  ? const AndroidView(
                viewType: 'camera_preview_view',
                creationParamsCodec: StandardMessageCodec(),

              )
                  : const Center(child: Icon(Icons.videocam_off, color: Colors.white12, size: 80)),
            ),

            _buildControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

   Widget _buildHeader() {
    return Column(
      children: [
        const Text("ENCRYPTED NODE", style: TextStyle(color: Colors.cyan, letterSpacing: 6, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(_isRunning ? "SESSION: ACTIVE" : "SESSION: READY",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
      ],
    );
  }

   Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _iconBtn(Icons.flip_camera_ios, "FLIP", () => platform.invokeMethod('switchCamera')),

        GestureDetector(
          onTap: () async {
             final statuses = await [
              Permission.camera,
              Permission.microphone,
              Permission.notification,
            ].request();

            if (statuses[Permission.camera]?.isGranted == true &&
                statuses[Permission.microphone]?.isGranted == true &&
                statuses[Permission.notification]?.isGranted == true) {

              _isRunning ? await platform.invokeMethod('stopService') : await platform.invokeMethod('startService');
            } else {
              print("Required permissions denied. Cannot start recording.");
            }
          },
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRunning ? Colors.red.withOpacity(0.15) : Colors.cyan.withOpacity(0.15),
              border: Border.all(color: _isRunning ? Colors.red : Colors.cyan, width: 4),
            ),
            child: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 45, color: _isRunning ? Colors.red : Colors.cyan),
          ),
        ),

         const SizedBox(width: 80),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback tap) {
    return Column(
      children: [
        IconButton(icon: Icon(icon, color: Colors.white70, size: 30), onPressed: tap),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}