import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/catch_providers.dart';
import '../../../application/providers/group_providers.dart';
import '../../../brick/models/catch_report.model.dart';
import '../../../data/messages/message_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/catch_card.dart';
import '../../widgets/intelligence_card.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/session_card.dart';

/// Provider for messages in a group.
final _messagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, groupId) async {
  final repo = MessageRepository();
  return repo.getMessages(groupId);
});

class GroupFeedScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupFeedScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends ConsumerState<GroupFeedScreen> {
  final _scrollController = ScrollController();
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _subscribeToChannel();
  }

  void _subscribeToChannel() {
    _channel = Supabase.instance.client.channel('group:${widget.groupId}');
    _channel!
        .onBroadcast(event: 'new_catch', callback: (_) => _refreshFeed())
        .onBroadcast(event: 'new_message', callback: (_) => _refreshFeed())
        .onBroadcast(event: 'photo_ready', callback: (_) => _refreshFeed())
        .subscribe();
  }

  void _refreshFeed() {
    ref.invalidate(catchesProvider(widget.groupId));
    ref.invalidate(_messagesProvider(widget.groupId));
  }

  void _onScroll() {
    // Pagination trigger — could fetch more items near bottom
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId));
    final catches = ref.watch(catchesProvider(widget.groupId));
    final messages = ref.watch(_messagesProvider(widget.groupId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.whenOrNull(data: (g) => g?['name'] as String?) ??
            'Group Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => context.go('/groups/${widget.groupId}/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outlined),
            onPressed: () => context.go('/groups/${widget.groupId}/members'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'repository':
                  context.go('/groups/${widget.groupId}/repository');
                case 'settings':
                  context.go('/groups/${widget.groupId}/settings');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'repository', child: Text('Repository')),
              const PopupMenuItem(
                  value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: _buildFeed(catches, messages, currentUserId),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.reedGreen,
        foregroundColor: Colors.white,
        onPressed: () => context.go('/groups/${widget.groupId}/catch/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFeed(
    AsyncValue<List<CatchReport>> catches,
    AsyncValue<List<Map<String, dynamic>>> messages,
    String? currentUserId,
  ) {
    // Merge catches and messages into a unified feed
    final catchList = catches.value ?? [];
    final messageList = messages.value ?? [];
    final isLoading = catches.isLoading || messages.isLoading;
    final hasError = catches.hasError || messages.hasError;

    if (isLoading && catchList.isEmpty && messageList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError && catchList.isEmpty && messageList.isEmpty) {
      return Center(
        child: Text(
          'Error loading feed',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    // Build unified feed items with type tags
    final items = <_FeedItem>[];

    for (final c in catchList) {
      items.add(_FeedItem(type: _FeedType.catchReport, data: c, date: c.caughtAt));
    }

    for (final m in messageList) {
      final createdAt =
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime(2000);
      items.add(_FeedItem(type: _FeedType.message, data: m, date: createdAt));
    }

    // Sort reverse chronological
    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stream, size: 64, color: AppColors.mist),
              const SizedBox(height: 16),
              Text(
                'No activity yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Log your first catch to get started!',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshFeed(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          switch (item.type) {
            case _FeedType.catchReport:
              final catchReport = item.data;
              return CatchCard(
                catchData: {
                  'fish_species': catchReport.fishSpecies,
                  'fish_weight_lb': catchReport.fishWeightLb,
                  'fish_weight_oz': catchReport.fishWeightOz,
                  'fish_name': catchReport.fishName,
                  'bait_type': catchReport.baitType,
                  if (catchReport.venueId != null) 'venues': {'name': ''},
                },
                onTap: () => context.go(
                    '/groups/${widget.groupId}/catch/${catchReport.id}'),
              );
            case _FeedType.message:
              final msg = item.data as Map<String, dynamic>;
              return MessageBubble(
                message: msg,
                isMe: msg['user_id'] == currentUserId,
              );
            case _FeedType.session:
              return SessionCard(session: item.data as Map<String, dynamic>);
            case _FeedType.intelligence:
              return IntelligenceCard(
                  item: item.data as Map<String, dynamic>);
          }
        },
      ),
    );
  }
}

enum _FeedType { catchReport, message, session, intelligence }

class _FeedItem {
  final _FeedType type;
  final dynamic data;
  final DateTime date;

  const _FeedItem({
    required this.type,
    required this.data,
    required this.date,
  });
}
