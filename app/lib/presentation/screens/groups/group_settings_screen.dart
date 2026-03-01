import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/group_providers.dart';
import '../../theme/app_theme.dart';

class GroupSettingsScreen extends ConsumerWidget {
  final String groupId;

  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final myRole = ref.watch(myRoleProvider(groupId));
    final isAdmin = myRole.value == 'admin';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Settings')),
      body: group.when(
        data: (g) {
          if (g == null) {
            return const Center(child: Text('Group not found'));
          }

          final ruleSet = g['rule_sets'] as Map<String, dynamic>?;
          final rules = ruleSet?['rules'] as Map<String, dynamic>?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Group Name',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        g['name'] as String? ?? '',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rule set
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Rule Set',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.reedGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ruleSet?['name'] as String? ?? 'Default',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.reedGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (ruleSet?['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          ruleSet!['description'] as String,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (rules != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (rules['max_members'] != null)
                          _RuleItem(
                            icon: Icons.people,
                            label: 'Max members',
                            value: '${rules['max_members']}',
                          ),
                        if (rules['location_detail'] != null)
                          _RuleItem(
                            icon: Icons.location_on,
                            label: 'Location detail',
                            value: rules['location_detail'] as String,
                          ),
                        if (rules['photos_required'] != null)
                          _RuleItem(
                            icon: Icons.camera_alt,
                            label: 'Photos required',
                            value: rules['photos_required'] == true
                                ? 'Yes'
                                : 'No',
                          ),
                        if (rules['named_fish'] != null)
                          _RuleItem(
                            icon: Icons.label,
                            label: 'Named fish logging',
                            value:
                                rules['named_fish'] == true ? 'Yes' : 'No',
                          ),
                        if (rules['sharing_allowed'] != null)
                          _RuleItem(
                            icon: Icons.share,
                            label: 'Sharing allowed',
                            value: rules['sharing_allowed'] == true
                                ? 'Yes'
                                : 'No',
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Leave group (non-admin) or admin actions
              if (!isAdmin)
                OutlinedButton.icon(
                  onPressed: () => _leaveGroup(context, ref, currentUserId),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Leave Group'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.alertRed,
                    side: const BorderSide(color: AppColors.alertRed),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _leaveGroup(
    BuildContext context,
    WidgetRef ref,
    String? userId,
  ) async {
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
            'Are you sure you want to leave this group? You will need a new invite to rejoin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.alertRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      await Supabase.instance.client
          .from('group_memberships')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      ref.invalidate(myGroupsProvider);
      if (context.mounted) context.go('/dashboard');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RuleItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.slate.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
