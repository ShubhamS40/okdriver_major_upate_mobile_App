// import 'package:flutter/material.dart';
// import 'package:porcupine_flutter/porcupine_manager.dart';
// import 'package:permission_handler/permission_handler.dart';

// class WakeWordTestScreen extends StatefulWidget {
//   @override
//   _WakeWordTestScreenState createState() => _WakeWordTestScreenState();
// }

// class _WakeWordTestScreenState extends State<WakeWordTestScreen> {
//   late PorcupineManager _porcupineManager;
//   String _status = "Say 'Porcupine' to trigger the assistant";

//   @override
//   void initState() {
//     super.initState();
//     requestMicPermission().then((granted) {
//       if (granted) {
//         initPorcupine();
//       } else {
//         setState(() => _status = "Microphone permission denied.");
//       }
//     });
//   }

//   Future<bool> requestMicPermission() async {
//     final status = await Permission.microphone.request();
//     return status.isGranted;
//   }

//   Future<void> initPorcupine() async {
//     try {
//       _porcupineManager = await PorcupineManager.fromBuiltInKeywords(
//         keywords: ['porcupine'],
//         onKeywordDetected: (int keywordIndex) {
//           setState(() {
//             _status = "Wake word 'Porcupine' detected!";
//           });
//           _onWakeWordDetected();
//         },
//         sensitivity: 0.7,
//       );

//       await _porcupineManager.start();
//     } catch (e) {
//       print("Error initializing Porcupine: $e");
//     }
//   }

//   void _onWakeWordDetected() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text("Wake Word Detected"),
//         content: Text("Assistant Activated! 🚀"),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _porcupineManager.stop();
//     _porcupineManager.delete();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Wake Word Test")),
//       body: Center(
//         child: Text(
//           _status,
//           textAlign: TextAlign.center,
//           style: TextStyle(fontSize: 18),
//         ),
//       ),
//     );
//   }
// }
