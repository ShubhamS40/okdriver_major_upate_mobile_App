import 'package:flutter/material.dart';
import 'package:okdriver/service/socket_service.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/model/chat_type.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VehicleCompanyChatScreen extends StatefulWidget {
  const VehicleCompanyChatScreen({Key? key}) : super(key: key);

  @override
  State<VehicleCompanyChatScreen> createState() =>
      _VehicleCompanyChatScreenState();
}

class _VehicleCompanyChatScreenState extends State<VehicleCompanyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();

  List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isLoadingHistory = false;
  String? _vehicleNumber;
  String? _companyName;
  String? _vehicleId;
  String? _companyId;
  String? _authToken;
  int _unreadCount = 0;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _loadVehicleInfo();
    _initializeSocket();
  }

  Future<void> _loadVehicleInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Debug: Print all stored data
    print('📱 All SharedPreferences data:');
    print(
        '📱 current_vehicle_number: ${prefs.getString('current_vehicle_number')}');
    print('📱 company_name: ${prefs.getString('company_name')}');
    print('📱 vehicle_token: ${prefs.getString('vehicle_token')}');
    print('📱 vehicle_id: ${prefs.getInt('vehicle_id')}');
    print('📱 company_id: ${prefs.getInt('company_id')}');

    setState(() {
      _vehicleNumber =
          prefs.getString('current_vehicle_number') ?? 'Unknown Vehicle';
      _companyName = prefs.getString('company_name') ?? 'Company';
      _vehicleId = prefs.getInt('vehicle_id')?.toString();
      _companyId = prefs.getInt('company_id')?.toString();
      _authToken = prefs.getString('vehicle_token');
    });

    print('📱 Loaded vehicle info: $_vehicleNumber, Company: $_companyName');
    print('📱 Vehicle ID: $_vehicleId, Company ID: $_companyId');
  }

  void _initializeSocket() async {
    print('🔌 Initializing socket...');
    await _socketService.initializeSocket();

    // Wait a bit for socket to connect
    await Future.delayed(const Duration(milliseconds: 1000));

    // Listen for new messages
    _messageSubscription = _socketService.messageStream.listen((messageData) {
      if (mounted) {
        print('📨 Received message data: $messageData');
        _processNewMessage(messageData);
      }
    });

    // Listen for connection status
    _connectionSubscription =
        _socketService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });

    // Load chat history after socket is connected
    Future.delayed(const Duration(milliseconds: 2000), () {
      print('📨 Loading chat history...');
      _loadChatHistoryFromAPI();
    });
  }

  void _processNewMessage(Map<String, dynamic> messageData) {
    final message = ChatMessage(
      id: messageData['id'].toString(),
      message: messageData['message'] ?? '',
      senderName: messageData['senderType'] == 'COMPANY' ? 'Company' : 'You',
      senderType: messageData['senderType'] == 'COMPANY'
          ? MessageSenderType.company
          : MessageSenderType.driver,
      timestamp: DateTime.parse(messageData['createdAt']),
      senderId: messageData['senderType'] == 'COMPANY' ? 'company' : 'driver',
      isSentByMe: messageData['senderType'] == 'DRIVER',
    );

    setState(() {
      // Check if message already exists to avoid duplicates
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        print('✅ Message added: ${message.message} from ${message.senderName}');

        // Track unread messages from company
        if (message.senderType == MessageSenderType.company) {
          _unreadCount++;
          print('📊 Unread count: $_unreadCount');
        }
      } else {
        print('⚠️ Duplicate message ignored: ${message.id}');
      }
    });

    _scrollToBottom();
  }

  Future<void> _loadChatHistoryFromAPI() async {
    if (_vehicleId == null || _authToken == null) {
      print('❌ Missing vehicle ID or auth token');
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      print('🌐 Loading chat history from API...');

      final url =
          'http://localhost:5000/api/company/vehicles/$_vehicleId/chat-history';
      print('📡 API URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> chatData = responseData['data'];
          print('📨 Chat history loaded: ${chatData.length} messages');

          List<ChatMessage> loadedMessages = [];

          for (var messageData in chatData) {
            try {
              final message = ChatMessage(
                id: messageData['id'].toString(),
                message: messageData['message'] ?? '',
                senderName: messageData['senderType'] == 'COMPANY'
                    ? (_companyName ?? 'Company')
                    : 'You',
                senderType: messageData['senderType'] == 'COMPANY'
                    ? MessageSenderType.company
                    : MessageSenderType.driver,
                timestamp: DateTime.parse(messageData['createdAt'] ??
                    DateTime.now().toIso8601String()),
                senderId: messageData['senderType'] == 'COMPANY'
                    ? 'company'
                    : 'driver',
                isSentByMe: messageData['senderType'] == 'DRIVER',
              );

              loadedMessages.add(message);
              print(
                  '✅ Processed message: ${message.message} from ${message.senderName}');
            } catch (e) {
              print('❌ Error processing message: $e');
              print('❌ Message data: $messageData');
            }
          }

          setState(() {
            _messages = loadedMessages;
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _isLoadingHistory = false;
          });

          // Scroll to bottom after loading
          Future.delayed(const Duration(milliseconds: 100), () {
            _scrollToBottom();
          });

          print(
              '✅ Chat history loaded successfully: ${_messages.length} messages');
        } else {
          print('❌ API returned success=false or no data');
          setState(() {
            _isLoadingHistory = false;
          });
        }
      } else {
        print('❌ API request failed with status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        setState(() {
          _isLoadingHistory = false;
        });

        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to load chat history: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception loading chat history: $e');
      setState(() {
        _isLoadingHistory = false;
      });

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chat history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  void _markMessagesAsRead() {
    if (_unreadCount > 0) {
      print('👀 Marking $_unreadCount messages as read');
      _socketService.markMessagesAsRead(_messages
          .where((m) => m.senderType == MessageSenderType.company)
          .map((m) => int.parse(m.id))
          .toList());

      setState(() {
        _unreadCount = 0;
      });
    }
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
    });
    print('🗑️ Messages cleared');
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    print('📤 Sending message: $messageText');

    // Send message via socket
    _socketService.sendMessageToCompany(messageText);

    // Don't add message locally - let it come through socket to avoid echoing
    // The message will be received via socket and added to the list
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with Company',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _companyName ?? 'Company',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          // Connection status indicator with retry button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isConnected) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: () {
                    print('🔄 Retrying connection...');
                    _socketService.retryConnection();
                  },
                  tooltip: 'Retry Connection',
                ),
              ],
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Vehicle info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isDarkMode ? Colors.grey[800] : Colors.blue[50],
            child: Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vehicle: $_vehicleNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue[800],
                  ),
                ),
                const Spacer(),
                Text(
                  '24h chat history',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (_isLoadingHistory) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black : const Color(0xFFECE5DD),
              ),
              child: _isLoadingHistory
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading chat history...'),
                        ],
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDarkMode
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation with your company',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadChatHistoryFromAPI,
                                child: const Text('Reload Chat History'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _clearMessages,
                                child: const Text('Clear Messages'),
                              ),
                            ],
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
