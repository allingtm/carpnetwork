import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/messages/message_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/message_bubble.dart';

/// Provider for chat messages in a group.
final _chatMessagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, groupId) async {
  final repo = MessageRepository();
  return repo.getMessages(groupId);
});

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageRepo = MessageRepository();
  RealtimeChannel? _channel;

  bool _isSending = false;
  String? _replyToId;
  String? _replyToContent;

  @override
  void initState() {
    super.initState();
    _subscribeToChannel();
  }

  void _subscribeToChannel() {
    _channel = Supabase.instance.client.channel('group:${widget.groupId}:chat');
    _channel!.onBroadcast(event: 'new_message', callback: (_) {
      ref.invalidate(_chatMessagesProvider(widget.groupId));
    }).subscribe();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _messageRepo.sendMessage(
        groupId: widget.groupId,
        content: content,
        replyToId: _replyToId,
      );
      _messageController.clear();
      setState(() {
        _replyToId = null;
        _replyToContent = null;
      });
      ref.invalidate(_chatMessagesProvider(widget.groupId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onReply(Map<String, dynamic> message) {
    setState(() {
      _replyToId = message['id'] as String?;
      _replyToContent = message['content'] as String? ?? '';
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_chatMessagesProvider(widget.groupId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['user_id'] == currentUserId;

                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      onLongPress: () => _onReply(message),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Reply preview
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.mist.withValues(alpha: 0.5),
                border: const Border(
                  top: BorderSide(color: AppColors.mist),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: AppColors.reedGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _replyToContent ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.mist),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: AppColors.mist),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: AppColors.deepLake,
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
