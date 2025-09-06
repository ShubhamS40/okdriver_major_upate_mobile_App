import 'package:flutter/material.dart';

// Enum for different types of chat users
enum ChatUserType {
  company, // Company/fleet management
  client, // Client who uses the service
  driver, // Driver who works for the company
  support // Customer support
}

// Enum for message sender types
enum MessageSenderType {
  company, // Message sent by the company/fleet management
  client, // Message sent by the client
  driver, // Message sent by a driver
  system, // System-generated message
  support // Support team messages
}

// Class to represent a chat user (contact)
class ChatUser {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final ChatUserType userType;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.profileImageUrl,
    required this.userType,
    this.isOnline = false,
    this.lastSeen,
  });
}

// Class to represent a chat message
class ChatMessage {
  final String id;
  final String message;
  final String senderId;
  final String senderName;
  final MessageSenderType senderType;
  final DateTime timestamp;
  final bool isRead;
  final bool isSentByMe;
  final String? attachmentUrl;
  final String? attachmentType; // image, document, audio, etc.

  ChatMessage({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.timestamp,
    this.isRead = false,
    required this.isSentByMe,
    this.attachmentUrl,
    this.attachmentType,
  });
}

// Class to represent a chat conversation
class ChatConversation {
  final String id;
  final ChatUser user;
  final List<ChatMessage> messages;
  final DateTime lastMessageTime;
  final String lastMessageText;
  int unreadCount;

  ChatConversation({
    required this.id,
    required this.user,
    required this.messages,
    required this.lastMessageTime,
    required this.lastMessageText,
    this.unreadCount = 0,
  });
}

// Sample data generator for testing
class ChatDataSample {
  // Generate sample users
  static List<ChatUser> getSampleUsers() {
    return [
      ChatUser(
        id: '1',
        name: 'OK Driver Fleet',
        email: 'fleet@okdriver.com',
        phoneNumber: '+91 9876543210',
        userType: ChatUserType.company,
        isOnline: true,
      ),
      ChatUser(
        id: '2',
        name: 'Mohan Transport',
        email: 'mohan@transport.com',
        phoneNumber: '+91 9876543211',
        userType: ChatUserType.client,
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatUser(
        id: '3',
        name: 'Sharma Logistics',
        email: 'sharma@logistics.com',
        phoneNumber: '+91 9876543212',
        userType: ChatUserType.client,
        isOnline: true,
      ),
      ChatUser(
        id: '4',
        name: 'Rahul Singh',
        email: 'rahul.s@gmail.com',
        phoneNumber: '+91 9876543213',
        userType: ChatUserType.driver,
        isOnline: true,
      ),
      ChatUser(
        id: '5',
        name: 'Customer Support',
        email: 'support@okdriver.com',
        phoneNumber: '+91 9876543214',
        userType: ChatUserType.support,
        isOnline: true,
      ),
    ];
  }

  // Generate sample conversations
  static List<ChatConversation> getSampleConversations() {
    final users = getSampleUsers();
    final now = DateTime.now();

    return users.map((user) {
      final messages = _generateMessagesForUser(user, now);
      return ChatConversation(
        id: 'conv_${user.id}',
        user: user,
        messages: messages,
        lastMessageTime: messages.isNotEmpty ? messages.last.timestamp : now,
        lastMessageText:
            messages.isNotEmpty ? messages.last.message : 'Start chatting',
        unreadCount: user.id == '2' ? 3 : (user.id == '3' ? 1 : 0),
      );
    }).toList();
  }

  // Generate sample messages for a user
  static List<ChatMessage> _generateMessagesForUser(
      ChatUser user, DateTime now) {
    switch (user.id) {
      case '1': // OK Driver Fleet
        return [
          ChatMessage(
            id: '1_1',
            message: 'Good morning! Your shift starts at 9:00 AM today.',
            senderId: '1',
            senderName: 'OK Driver Fleet',
            senderType: MessageSenderType.company,
            timestamp: now.subtract(const Duration(days: 1, hours: 2)),
            isRead: true,
            isSentByMe: false,
          ),
          ChatMessage(
            id: '1_2',
            message: 'Good morning! I will be starting my shift on time.',
            senderId: '4',
            senderName: 'Rahul Singh',
            senderType: MessageSenderType.driver,
            timestamp:
                now.subtract(const Duration(days: 1, hours: 1, minutes: 45)),
            isRead: true,
            isSentByMe: true,
          ),
          ChatMessage(
            id: '1_3',
            message:
                'Please pick up the delivery from Warehouse B by 10:30 AM.',
            senderId: '1',
            senderName: 'OK Driver Fleet',
            senderType: MessageSenderType.company,
            timestamp: now.subtract(const Duration(days: 1, hours: 1)),
            isRead: true,
            isSentByMe: false,
          ),
        ];
      case '2': // Mohan Transport
        return [
          ChatMessage(
            id: '2_1',
            message: 'We need to schedule a delivery for tomorrow.',
            senderId: '2',
            senderName: 'Mohan Transport',
            senderType: MessageSenderType.client,
            timestamp: now.subtract(const Duration(hours: 5)),
            isRead: true,
            isSentByMe: false,
          ),
          ChatMessage(
            id: '2_2',
            message: 'I can arrange that. What time would be convenient?',
            senderId: '4',
            senderName: 'Rahul Singh',
            senderType: MessageSenderType.driver,
            timestamp: now.subtract(const Duration(hours: 4, minutes: 30)),
            isRead: true,
            isSentByMe: true,
          ),
          ChatMessage(
            id: '2_3',
            message: 'Around 2 PM would be perfect.',
            senderId: '2',
            senderName: 'Mohan Transport',
            senderType: MessageSenderType.client,
            timestamp: now.subtract(const Duration(hours: 1)),
            isRead: false,
            isSentByMe: false,
          ),
        ];
      case '3': // Sharma Logistics
        return [
          ChatMessage(
            id: '3_1',
            message: 'Can you provide an update on the current delivery?',
            senderId: '3',
            senderName: 'Sharma Logistics',
            senderType: MessageSenderType.client,
            timestamp: now.subtract(const Duration(minutes: 45)),
            isRead: true,
            isSentByMe: false,
          ),
          ChatMessage(
            id: '3_2',
            message:
                'I am currently at the location. Will complete delivery in 15 minutes.',
            senderId: '4',
            senderName: 'Rahul Singh',
            senderType: MessageSenderType.driver,
            timestamp: now.subtract(const Duration(minutes: 30)),
            isRead: true,
            isSentByMe: true,
          ),
          ChatMessage(
            id: '3_3',
            message: 'Great, please send a confirmation once delivered.',
            senderId: '3',
            senderName: 'Sharma Logistics',
            senderType: MessageSenderType.client,
            timestamp: now.subtract(const Duration(minutes: 15)),
            isRead: false,
            isSentByMe: false,
          ),
        ];
      case '5': // Customer Support
        return [
          ChatMessage(
            id: '5_1',
            message: 'Hello, how can I help you today?',
            senderId: '5',
            senderName: 'Customer Support',
            senderType: MessageSenderType.support,
            timestamp: now.subtract(const Duration(days: 2, hours: 3)),
            isRead: true,
            isSentByMe: false,
          ),
          ChatMessage(
            id: '5_2',
            message: 'I need help with updating my vehicle information.',
            senderId: '4',
            senderName: 'Rahul Singh',
            senderType: MessageSenderType.driver,
            timestamp:
                now.subtract(const Duration(days: 2, hours: 2, minutes: 45)),
            isRead: true,
            isSentByMe: true,
          ),
          ChatMessage(
            id: '5_3',
            message:
                'Sure, I can help with that. Please provide your vehicle registration number.',
            senderId: '5',
            senderName: 'Customer Support',
            senderType: MessageSenderType.support,
            timestamp:
                now.subtract(const Duration(days: 2, hours: 2, minutes: 30)),
            isRead: true,
            isSentByMe: false,
          ),
        ];
      default:
        return [];
    }
  }
}
