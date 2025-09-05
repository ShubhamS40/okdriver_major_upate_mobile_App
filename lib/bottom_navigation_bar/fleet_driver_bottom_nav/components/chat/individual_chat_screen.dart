import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/model/chat_type.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:okdriver/service/socket_service.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;

class IndividualChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const IndividualChatScreen({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  _IndividualChatScreenState createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isAttachmentMenuOpen = false;
  final SocketService _socketService = SocketService();
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.conversation.messages);

    // Initialize socket connection
    _initializeSocket();

    // If there are no messages, add a system message
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: 'system_${DateTime.now().millisecondsSinceEpoch}',
          message: 'Chat started with ${widget.conversation.user.name}',
          senderName: 'System',
          senderType: MessageSenderType.system,
          timestamp: DateTime.now(),
          senderId: 'system',
          isSentByMe: false,
        ),
      );
    }
    // Scroll to bottom after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _initializeSocket() async {
    await _socketService.initializeSocket();

    // Listen for new messages
    _messageSubscription = _socketService.messageStream.listen((messageData) {
      if (mounted) {
        final message = ChatMessage(
          id: messageData['id'].toString(),
          message: messageData['message'] ?? '',
          senderName:
              messageData['senderType'] == 'COMPANY' ? 'Company' : 'Driver',
          senderType: messageData['senderType'] == 'COMPANY'
              ? MessageSenderType.company
              : MessageSenderType.driver,
          timestamp: DateTime.parse(messageData['createdAt']),
          senderId:
              messageData['senderType'] == 'COMPANY' ? 'company' : 'driver',
          isSentByMe: messageData['senderType'] == 'DRIVER',
        );

        setState(() {
          _messages.add(message);
        });

        _scrollToBottom();
      }
    });

    // Listen for connection status
    _connectionSubscription =
        _socketService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {});
      }
    });

    // Load chat history
    _socketService.getChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    // Send message via socket
    _socketService.sendMessageToCompany(messageText);

    // Add message to local list immediately for better UX
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      message: messageText,
      senderName: 'You',
      senderType: MessageSenderType.driver,
      timestamp: DateTime.now(),
      senderId: 'current_user',
      isSentByMe: true,
    );

    setState(() {
      _messages.add(message);
    });

    // Scroll to bottom after adding the message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  MessageSenderType _getSenderTypeFromUserType(ChatUserType userType) {
    switch (userType) {
      case ChatUserType.company:
        return MessageSenderType.company;
      case ChatUserType.client:
        return MessageSenderType.client;
      case ChatUserType.driver:
        return MessageSenderType.driver;
      case ChatUserType.support:
        return MessageSenderType.system;
      default:
        return MessageSenderType.system;
    }
  }

  void _toggleAttachmentMenu() {
    setState(() {
      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;
    final user = widget.conversation.user;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getAvatarColor(user.userType),
              radius: 20,
              child: user.profileImageUrl != null
                  ? null
                  : Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: user.isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Connection status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _socketService.isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _socketService.isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  _socketService.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // Implement video call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Implement voice call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice call feature coming soon')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle menu item selection
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value selected')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'View Contact',
                child: Text('View Contact'),
              ),
              const PopupMenuItem(
                value: 'Media, links, and docs',
                child: Text('Media, links, and docs'),
              ),
              const PopupMenuItem(
                value: 'Search',
                child: Text('Search'),
              ),
              const PopupMenuItem(
                value: 'Mute notifications',
                child: Text('Mute notifications'),
              ),
              const PopupMenuItem(
                value: 'Clear chat',
                child: Text('Clear chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black : const Color(0xFFECE5DD),
                image: DecorationImage(
                  image: AssetImage(
                    isDarkMode
                        ? 'assets/images/chat_bg_dark.png'
                        : 'assets/images/chat_bg_light.png',
                  ),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.2,
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    // Typing indicator
                    return _buildTypingIndicator(isDarkMode);
                  }
                  return _buildMessageBubble(_messages[index], isDarkMode);
                },
              ),
            ),
          ),
          // Attachment menu
          if (_isAttachmentMenuOpen) _buildAttachmentMenu(isDarkMode),
          // Message input
          _buildMessageInput(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDarkMode) {
    final isMe = message.senderType == MessageSenderType.driver;
    final isSystem = message.senderType == MessageSenderType.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              message.message,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 12.0,
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? (isDarkMode ? const Color(0xFF054D44) : const Color(0xFFDCF8C6))
              : (isDarkMode ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2.0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                  color: _getSenderColor(message.senderType),
                ),
              ),
            Text(
              message.message,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2.0),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10.0,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(
                        Icons.done_all,
                        size: 14.0,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.conversation.user.name} is typing',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 12.0,
              ),
            ),
            const SizedBox(width: 8.0),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentMenu(bool isDarkMode) {
    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentButton(
              Icons.photo, 'Photos', Colors.purple, isDarkMode),
          _buildAttachmentButton(
              Icons.camera_alt, 'Camera', Colors.red, isDarkMode),
          _buildAttachmentButton(
              Icons.insert_drive_file, 'Document', Colors.blue, isDarkMode),
          _buildAttachmentButton(
              Icons.location_on, 'Location', Colors.green, isDarkMode),
          _buildAttachmentButton(
              Icons.person, 'Contact', Colors.orange, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton(
      IconData icon, String label, Color color, bool isDarkMode) {
    return InkWell(
      onTap: () {
        // Handle attachment selection
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label attachment coming soon')),
        );
        setState(() {
          _isAttachmentMenuOpen = false;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isAttachmentMenuOpen ? Icons.close : Icons.attach_file,
              color: Colors.grey[600],
            ),
            onPressed: _toggleAttachmentMenu,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
              ),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            icon: Icon(
              _messageController.text.trim().isEmpty ? Icons.mic : Icons.send,
              color: Colors.green,
            ),
            onPressed: () {
              if (_messageController.text.trim().isEmpty) {
                // Implement voice message functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Voice message feature coming soon')),
                );
              } else {
                _sendMessage();
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Color _getAvatarColor(ChatUserType userType) {
    switch (userType) {
      case ChatUserType.company:
        return Colors.blue;
      case ChatUserType.client:
        return Colors.orange;
      case ChatUserType.driver:
        return Colors.green;
      case ChatUserType.support:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getSenderColor(MessageSenderType senderType) {
    switch (senderType) {
      case MessageSenderType.company:
        return Colors.blue;
      case MessageSenderType.client:
        return Colors.orange;
      case MessageSenderType.driver:
        return Colors.green;
      case MessageSenderType.system:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
