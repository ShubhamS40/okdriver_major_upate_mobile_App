// Enum definitions for chat functionality in fleet client bottom nav

import 'package:flutter/material.dart';

enum ChatType {
  company, // Chat with the company/fleet management
  vehicle, // Chat about a specific vehicle
  driver, // Chat with a specific driver
  support // Chat with customer support
}

enum MessageSenderType {
  company, // Message sent by the company/fleet management
  client, // Message sent by the client
  driver, // Message sent by a driver
  system // System-generated message
}

class ChatOption {
  final ChatType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final String id;
  final bool isActive;

  ChatOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.id,
    this.isActive = true,
  });
}
