import 'package:flutter/material.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/model/chat_type.dart';
import 'package:okdriver/bottom_navigation_bar/fleet_client_bottom_nav/components/chat/individual_chat_screen.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectUserScreen extends StatefulWidget {
  const SelectUserScreen({Key? key}) : super(key: key);

  @override
  _SelectUserScreenState createState() => _SelectUserScreenState();
}

class _SelectUserScreenState extends State<SelectUserScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<ChatUser> _allUsers = [];
  List<ChatUser> _filteredUsers = [];
  bool _isSearching = false;
  String? _companyName;
  String? _companyEmail;
  List<ChatUser> _assignedVehicles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadCompanyFromPrefs();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _loadCompanyFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString('company_name') ?? 'Company';
      _companyEmail = prefs.getString('company_email') ?? 'company@fleet.com';
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() async {
    // Company option
    final companyUsers = ChatDataSample.getSampleUsers()
        .where((u) => u.userType == ChatUserType.company)
        .toList();

    // Vehicles assigned to this client (placeholder, replace with API later)
    // We'll show a single sample row to keep UI working without backend call here
    _assignedVehicles = [
      ChatUser(
        id: 'vehicle_assigned',
        name: 'Assigned Vehicle',
        email: 'vehicle@okdriver',
        userType: ChatUserType.driver,
        isOnline: true,
      )
    ];

    _allUsers = [...companyUsers, ..._assignedVehicles];
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
            user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _navigateToChat(ChatUser user) {
    final conversation = ChatConversation(
      id: 'chat_${user.id}',
      user: user,
      messages: [],
      lastMessageTime: DateTime.now(),
      lastMessageText: 'Start chatting with ${user.name}',
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
        title: const Text('Select User'),
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
            Tab(text: 'Company'),
            Tab(text: 'Vehicles'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(
                  _filteredUsers
                      .where((u) => u.userType == ChatUserType.company)
                      .toList(),
                  isDarkMode,
                ),
                _buildUserList(
                  _filteredUsers
                      .where((u) => u.userType != ChatUserType.company)
                      .toList(),
                  isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<ChatUser> users, bool isDarkMode) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          _isSearching ? 'No users found' : 'No users available',
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
      onTap: () => _navigateToChat(user),
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
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getUserTypeColor(user.userType),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getUserTypeLabel(user.userType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16),
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

  Color _getUserTypeColor(ChatUserType userType) {
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

  String _getUserTypeLabel(ChatUserType userType) {
    switch (userType) {
      case ChatUserType.company:
        return 'COMPANY';
      case ChatUserType.client:
        return 'CLIENT';
      case ChatUserType.driver:
        return 'DRIVER';
      case ChatUserType.support:
        return 'SUPPORT';
      default:
        return 'USER';
    }
  }
}
