import 'package:flutter/material.dart';

enum ChatUserType {
  company,
  client,
  driver,
  support,
}

enum MessageSenderType {
  company,
  client,
  driver,
  system,
}

class ChatUser {
  final String id;
  final String name;
  final String email;
  final ChatUserType userType;
  final bool isOnline;
  final String? profileImageUrl;
  final String? phoneNumber;

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    required this.isOnline,
    this.profileImageUrl,
    this.phoneNumber,
  });
}

class ChatMessage {
  final String id;
  final String message;
  final String senderName;
  final MessageSenderType senderType;
  final DateTime timestamp;
  final String senderId;
  final bool isSentByMe;
  final String? attachmentUrl;

  ChatMessage({
    required this.id,
    required this.message,
    required this.senderName,
    required this.senderType,
    required this.timestamp,
    required this.senderId,
    required this.isSentByMe,
    this.attachmentUrl,
  });
}

class ChatConversation {
  final String id;
  final ChatUser user;
  final List<ChatMessage> messages;
  final DateTime lastMessageTime;
  final String lastMessageText;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.user,
    required this.messages,
    required this.lastMessageTime,
    required this.lastMessageText,
    this.unreadCount = 0,
  });
}

class ChatDataSample {
  static List<ChatUser> getSampleUsers() {
    return [
      ChatUser(
        id: '1',
        name: 'OK Driver Fleet',
        email: 'fleet@okdriver.com',
        userType: ChatUserType.company,
        isOnline: true,
        phoneNumber: '+91 9876543210',
      ),
      ChatUser(
        id: '2',
        name: 'Support Team',
        email: 'support@okdriver.com',
        userType: ChatUserType.support,
        isOnline: true,
        phoneNumber: '+91 9876543211',
      ),
    ];
  }

  static List<ChatConversation> getSampleConversations() {
    final users = getSampleUsers();
    final now = DateTime.now();

    return [
      ChatConversation(
        id: '1',
        user: users[0],
        messages: [],
        lastMessageTime: now.subtract(const Duration(hours: 2)),
        lastMessageText: 'Hello! How can I help you today?',
        unreadCount: 2,
      ),
      ChatConversation(
        id: '2',
        user: users[1],
        messages: [],
        lastMessageTime: now.subtract(const Duration(days: 1)),
        lastMessageText: 'Your issue has been resolved',
        unreadCount: 0,
      ),
    ];
  }
}
