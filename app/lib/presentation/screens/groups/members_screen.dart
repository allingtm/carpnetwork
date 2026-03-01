import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/group_providers.dart';
import '../../theme/app_theme.dart';

class MembersScreen extends ConsumerWidget {
  final String groupId;

  const MembersScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(groupId));
    final myRole = ref.watch(myRoleProvider(groupId));
    final isAdmin = myRole.value == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => context.go('/groups/$groupId/invite'),
            ),
        ],
      ),
      body: members.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No members found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = list[index];
              final user = member['users'] as Map<String, dynamic>?;
              final role = member['role'] as String? ?? 'member';
              final name = user?['full_name'] as String? ?? 'Unknown';
              final memberId = user?['id'] as String?;
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final isSelf = memberId == currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: role == 'admin'
                      ? AppColors.goldenHour.withValues(alpha: 0.15)
                      : AppColors.deepLake.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: role == 'admin'
                          ? AppColors.goldenHour
                          : AppColors.deepLake,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(name),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(you)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.slate),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  role == 'admin' ? 'Admin' : 'Member',
                  style: TextStyle(
                    color:
                        role == 'admin' ? AppColors.goldenHour : AppColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: isAdmin && !isSelf
                    ? PopupMenuButton<String>(
                        onSelected: (action) => _handleMemberAction(
                          context,
                          ref,
                          action,
                          memberId!,
                          name,
                        ),
                        itemBuilder: (_) => [
                          if (role != 'admin')
                            const PopupMenuItem(
                              value: 'promote',
                              child: Text('Promote to admin'),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              'Remove from group',
                              style: TextStyle(color: AppColors.alertRed),
                            ),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _handleMemberAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String memberId,
    String memberName,
  ) async {
    switch (action) {
      case 'promote':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Promote member'),
            content: Text('Promote $memberName to admin?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Promote')),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;

        final repo = ref.read(groupRepositoryProvider);
        await repo.promoteMember(groupId, memberId);
        ref.invalidate(groupMembersProvider(groupId));

      case 'remove':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove member'),
            content:
                Text('Remove $memberName from the group? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.alertRed),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;

        try {
          final client = Supabase.instance.client;
          final session = client.auth.currentSession;
          final functionsUrl =
              '${client.rest.url.replaceAll('/rest/v1', '')}/functions/v1';

          await http.post(
            Uri.parse('$functionsUrl/member-remove'),
            headers: {
              'Authorization': 'Bearer ${session!.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'group_id': groupId,
              'user_id': memberId,
            }),
          );

          ref.invalidate(groupMembersProvider(groupId));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to remove member: $e')),
            );
          }
        }
    }
  }
}
