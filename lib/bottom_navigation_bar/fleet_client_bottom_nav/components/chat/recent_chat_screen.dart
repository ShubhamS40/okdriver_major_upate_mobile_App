import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/individual_chat_screen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/company_chat_screen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/model/chat_type.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/select_user_screen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:okdriver/service/client_chat_api_service.dart';

class RecentChatScreen extends StatefulWidget {
  const RecentChatScreen({Key? key}) : super(key: key);

  @override
  _RecentChatScreenState createState() => _RecentChatScreenState();
}

class _RecentChatScreenState extends State<RecentChatScreen> {
  late List<ChatConversation> _conversations;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<ChatConversation> _filteredConversations = [];
  String? _clientEmail;
  String? _companyName;
  int _unreadCount = 0;
  String _lastMessageText = 'Start chatting with your company';
  DateTime _lastMessageTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_filterConversations);

    // Get unread count after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      _getUnreadCount();
    });
  }

  Future<void> _init() async {
    await _loadClientInfo();
    await _loadMetaFromBackend();
    _loadConversations();
  }

  void _getUnreadCount() {
    // This would typically call a service to get unread count
    print('📊 Getting unread count...');

    // Simulate unread count for testing
    Future.delayed(const Duration(milliseconds: 500), () {
      _updateUnreadCount(1); // Test with 1 unread message
    });
  }

  Future<void> _loadClientInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _clientEmail = prefs.getString('client_email') ?? 'client@example.com';
      _companyName = prefs.getString('company_name') ?? 'Company';
    });
  }

  Future<void> _loadMetaFromBackend() async {
    final api = ClientChatApiService();
    await api.initialize();
    try {
      // unread count
      final unread = await api.getUnreadCount();
      // last message (limit 1)
      final chats = await api.getChatHistory(limit: 1, offset: 0);
      if (mounted) {
        setState(() {
          _unreadCount = unread;
          if (chats.isNotEmpty) {
            _lastMessageText = (chats.first['message'] ?? '').toString();
            final createdAt = chats.first['createdAt'] as String?;
            _lastMessageTime = createdAt != null
                ? DateTime.tryParse(createdAt) ?? DateTime.now()
                : DateTime.now();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterConversations);
    _searchController.dispose();
    super.dispose();
  }

  void _loadConversations() {
    // Create client-company chat conversation
    final clientCompanyChat = ChatConversation(
      id: 'client_company_chat',
      user: ChatUser(
        id: 'company',
        name: _companyName ?? 'Company',
        email: 'company@fleet.com',
        userType: ChatUserType.company,
        isOnline: true,
      ),
      messages: [],
      lastMessageTime: _lastMessageTime,
      lastMessageText: _lastMessageText,
      unreadCount: _unreadCount,
    );

    // Only client-company chat should be visible in recent chats
    _conversations = [clientCompanyChat];
    _filteredConversations = List.from(_conversations);
  }

  void _filterConversations() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredConversations = List.from(_conversations);
      });
      return;
    }

    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _conversations.where((conversation) {
        return conversation.user.name.toLowerCase().contains(query) ||
            conversation.user.email.toLowerCase().contains(query) ||
            conversation.lastMessageText.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _navigateToChat(ChatConversation conversation) {
    if (conversation.id == 'client_company_chat') {
      // Navigate to client-company chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CompanyChatScreen(),
        ),
      ).then((_) {
        // Reset unread count when returning from chat
        _updateUnreadCount(0);
      });
    } else {
      // Navigate to individual chat screen for other conversations
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IndividualChatScreen(
            conversation: conversation,
          ),
        ),
      );
    }
  }

  void _updateUnreadCount(int count) {
    setState(() {
      if (_conversations.isNotEmpty) {
        _unreadCount = count;
        _filteredConversations = List.from(_conversations);
      }
    });
  }

  void _navigateToSelectUser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectUserScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              )
            : const Text('Chats'),
      ),
      body: _filteredConversations.isEmpty
          ? Center(
              child: Text(
                _isSearching
                    ? 'No conversations found'
                    : 'No conversations yet',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            )
          : ListView.builder(
              itemCount: _filteredConversations.length,
              itemBuilder: (context, index) {
                final conversation = _filteredConversations[index];
                return _buildConversationTile(conversation, isDarkMode);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToSelectUser,
        backgroundColor: Colors.green,
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildConversationTile(
      ChatConversation conversation, bool isDarkMode) {
    final user = conversation.user;
    final lastMessageTime = _formatTime(conversation.lastMessageTime);

    return ListTile(
      onTap: () => _navigateToChat(conversation),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: _getAvatarColor(user.userType),
            radius: 24,
            child: user.profileImageUrl != null
                ? null
                : Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode ? Colors.black : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.name,
              style: TextStyle(
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            lastMessageTime,
            style: TextStyle(
              fontSize: 12,
              color: conversation.unreadCount > 0
                  ? Colors.green
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: conversation.unreadCount > 0
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessageText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? (isDarkMode ? Colors.white : Colors.black)
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today, show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      // Within a week, show day name
      return _getDayName(dateTime.weekday);
    } else {
      // Older, show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
