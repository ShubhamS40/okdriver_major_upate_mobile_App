import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/model/chat_type.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class IndividualChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const IndividualChatScreen({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.conversation.messages);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: messageText,
      senderName: 'You',
      senderType: MessageSenderType.client,
      timestamp: DateTime.now(),
      senderId: 'client',
      isSentByMe: true,
    );

    setState(() {
      _messages.add(newMessage);
    });

    _scrollToBottom();

    // Simulate reply after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final replyMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Thank you for your message. We will get back to you soon.',
          senderName: widget.conversation.user.name,
          senderType: MessageSenderType.company,
          timestamp: DateTime.now(),
          senderId: widget.conversation.user.id,
          isSentByMe: false,
        );

        setState(() {
          _messages.add(replyMessage);
        });

        _scrollToBottom();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  _getAvatarColor(widget.conversation.user.userType),
              radius: 18,
              child: widget.conversation.user.profileImageUrl != null
                  ? null
                  : Text(
                      widget.conversation.user.name
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.conversation.user.name,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  widget.conversation.user.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.conversation.user.isOnline
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Calling ${widget.conversation.user.name}...'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMoreOptions(context);
            },
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
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(
                            _messages[index], isDarkMode);
                      },
                    ),
            ),
          ),

          // Message input
          _buildMessageInput(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDarkMode) {
    final isMe = message.isSentByMe;
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

  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.attach_file,
              color: Colors.grey[600],
            ),
            onPressed: () {
              // Implement attachment functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attachment feature coming soon')),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.send,
              color: Colors.green,
            ),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Profile feature coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Block feature coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report feature coming soon')),
                  );
                },
              ),
            ],
          ),
        );
      },
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
}
