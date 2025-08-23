import 'package:flutter/material.dart';
import 'package:okdriver/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import 'glass_conatiner.dart'; // fixed typo (was glass_conatiner.dart)

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isLoading;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isUser,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAssistantAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: GlassContainer(
              color: isUser
                  ? const Color(0xFF9C27B0).withOpacity(isDarkMode ? 0.5 : 0.7)
                  : (isDarkMode
                      ? Colors.grey.shade800.withOpacity(0.5)
                      : Colors.white.withOpacity(0.3)),
              blur: 10.0,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUser
                    ? const Color(0xFF9C27B0).withOpacity(0.3)
                    : Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        message,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : (isDarkMode ? Colors.white : Colors.black87),
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAssistantAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9C27B0).withOpacity(0.7),
            const Color(0xFF7B1FA2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.assistant,
        size: 22,
        color: Colors.white,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9C27B0).withOpacity(0.8),
            const Color(0xFF7B1FA2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}
