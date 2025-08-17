import 'package:flutter/material.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAssistantAvatar(isDarkMode),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDarkMode
                        ? const Color(0xFF9C27B0)
                        : const Color(0xFF9C27B0))
                    : (isDarkMode
                        ? const Color(0xFF2D2D2D)
                        : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDarkMode ? Colors.white : Colors.black87),
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isUser) _buildUserAvatar(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildAssistantAvatar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF9C27B0) : const Color(0xFF9C27B0),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildUserAvatar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blueGrey.shade700 : Colors.blueGrey.shade300,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
