// This is a barrel file to make it easier to import the voice assistant module

import 'package:flutter/material.dart';

export 'index.dart';

// This class is now deprecated and will be removed in a future version.
// Use OkDriverVirtualAssistantScreen from okdriver_virtual_assistant/okdriver_virtual_assistant_screen.dart instead.
@Deprecated('Use OkDriverVirtualAssistantScreen instead')
class OkDriverVirtualAssistant extends StatelessWidget {
  const OkDriverVirtualAssistant({super.key});

  @override
  Widget build(BuildContext context) {
    return const OkDriverVirtualAssistant();
  }
}
