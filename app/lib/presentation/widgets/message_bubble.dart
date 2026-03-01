import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = message['deleted_at'] != null;
    final content = message['content'] as String? ?? '';
    final user = message['users'] as Map<String, dynamic>?;
    final senderName = user?['full_name'] as String? ?? 'Unknown';
    final createdAt = DateTime.tryParse(message['created_at'] as String? ?? '');
    final replyToId = message['reply_to_id'] as String?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.deepLake.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.mist),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepLake,
                  ),
                ),
              if (replyToId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: const Border(
                      left: BorderSide(color: AppColors.reedGreen, width: 2),
                    ),
                    color: AppColors.mist.withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'Reply',
                    style: TextStyle(fontSize: 11, color: AppColors.slate),
                  ),
                ),
              Text(
                isDeleted ? '[Message deleted]' : content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDeleted
                      ? AppColors.slate.withValues(alpha: 0.5)
                      : AppColors.slate,
                  fontStyle: isDeleted ? FontStyle.italic : null,
                ),
              ),
              if (createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat.Hm().format(createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.slate.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
