import 'package:flutter/material.dart';
import 'package:okdriver/okdriver_virtual_assistant/models/chat_message.dart';
import 'package:okdriver/okdriver_virtual_assistant/service/assistant_service.dart';

class ConversationHistoryScreen extends StatefulWidget {
  final String userId;
  const ConversationHistoryScreen({super.key, required this.userId});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final AssistantService _assistantService = AssistantService();
  bool _isLoading = true;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final history = await _assistantService.getHistory(widget.userId);
      setState(() {
        _messages = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversation')),
      );
    }
  }

  Future<void> _clearHistory() async {
    try {
      await _assistantService.clearHistory(widget.userId);
      setState(() {
        _messages = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear conversation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _messages.isNotEmpty ? _clearHistory : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: msg.isUser
                              ? Colors.blue.shade200
                              : Colors.grey.shade300,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            msg.isUser
                                ? Icons.person_outline
                                : Icons.smart_toy_outlined,
                            color: msg.isUser ? Colors.blue : Colors.deepPurple,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              msg.text,
                              style: const TextStyle(fontSize: 15, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
