import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/individual_chat_screen.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_driver_bottom_nav/components/chat/model/chat_type.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class SelectUserScreen extends StatefulWidget {
  const SelectUserScreen({Key? key}) : super(key: key);

  @override
  _SelectUserScreenState createState() => _SelectUserScreenState();
}

class _SelectUserScreenState extends State<SelectUserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<ChatUser> _allUsers;
  late List<ChatUser> _filteredUsers;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    // Load sample users for now
    // In a real app, this would fetch from an API or local database
    _allUsers = ChatDataSample.getSampleUsers();
    _filteredUsers = List.from(_allUsers);
  }

  void _filterUsers() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredUsers = List.from(_allUsers);
      });
      return;
    }

    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.phoneNumber != null &&
                user.phoneNumber!.toLowerCase().contains(query));
      }).toList();
    });
  }

  List<ChatUser> _getUsersByType(ChatUserType type) {
    return _filteredUsers.where((user) => user.userType == type).toList();
  }

  void _startNewChat(ChatUser user) {
    // Create a new conversation or find existing one
    final now = DateTime.now();
    final conversation = ChatConversation(
      id: 'new_conv_${user.id}_${now.millisecondsSinceEpoch}',
      user: user,
      messages: [],
      lastMessageTime: now,
      lastMessageText: 'Start a new conversation',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualChatScreen(
          conversation: conversation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
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
            : const Text('Select Contact'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'COMPANIES'),
            Tab(text: 'CLIENTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All contacts tab
          _buildUserList(_filteredUsers, isDarkMode),

          // Companies tab
          _buildUserList(_getUsersByType(ChatUserType.company), isDarkMode),

          // Clients tab
          _buildUserList(_getUsersByType(ChatUserType.client), isDarkMode),
        ],
      ),
    );
  }

  Widget _buildUserList(List<ChatUser> users, bool isDarkMode) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          _isSearching ? 'No contacts found' : 'No contacts available',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user, isDarkMode);
      },
    );
  }

  Widget _buildUserTile(ChatUser user, bool isDarkMode) {
    return ListTile(
      onTap: () => _startNewChat(user),
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
      title: Text(user.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.email,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          if (user.phoneNumber != null)
            Text(
              user.phoneNumber!,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
        ],
      ),
      trailing: Icon(
        Icons.chat,
        color: Colors.green,
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
}
