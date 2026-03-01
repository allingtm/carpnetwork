import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/group_providers.dart';
import '../../theme/app_theme.dart';

/// Provider for pending invitations.
final _invitationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, groupId) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getInvitations(groupId);
});

class InviteScreen extends ConsumerStatefulWidget {
  final String groupId;

  const InviteScreen({super.key, required this.groupId});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  String? _inviteUrl;
  bool _isGenerating = false;

  Future<void> _generateInvite() async {
    setState(() => _isGenerating = true);

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final functionsUrl =
          '${client.rest.url.replaceAll('/rest/v1', '')}/functions/v1';

      final response = await http.post(
        Uri.parse('$functionsUrl/invite-create'),
        headers: {
          'Authorization': 'Bearer ${session!.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'group_id': widget.groupId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _inviteUrl = data['invite_url'] as String? ??
              'https://carp.network/invite/${data['token']}';
        });
        ref.invalidate(_invitationsProvider(widget.groupId));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to create invite');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _shareInvite() {
    if (_inviteUrl != null) {
      Share.share('Join my fishing group on Carp.Network! $_inviteUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitations = ref.watch(_invitationsProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Generate invite section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invite a member',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate a unique link to share with a friend.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_inviteUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mist.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _inviteUrl!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: AppColors.deepLake,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _shareInvite,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Link'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _isGenerating ? null : _generateInvite,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: const Text('Generate Invite Link'),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Pending invitations
          Text(
            'Pending Invitations',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),

          invitations.when(
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No pending invitations',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return Column(
                children: list.map((inv) {
                  final createdAt =
                      DateTime.tryParse(inv['created_at'] as String? ?? '');
                  final expiresAt =
                      DateTime.tryParse(inv['expires_at'] as String? ?? '');
                  final status = inv['status'] as String? ?? 'pending';
                  final invitedBy =
                      inv['users'] as Map<String, dynamic>?;

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        status == 'pending'
                            ? Icons.hourglass_empty
                            : status == 'accepted'
                                ? Icons.check_circle
                                : Icons.cancel,
                        color: status == 'pending'
                            ? AppColors.goldenHour
                            : status == 'accepted'
                                ? AppColors.success
                                : AppColors.alertRed,
                      ),
                      title: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (createdAt != null)
                            Text(
                                'Created ${DateFormat.MMMd().add_Hm().format(createdAt)}'),
                          if (expiresAt != null)
                            Text(
                              'Expires ${DateFormat.MMMd().add_Hm().format(expiresAt)}',
                              style: TextStyle(
                                color: expiresAt.isBefore(DateTime.now())
                                    ? AppColors.alertRed
                                    : null,
                              ),
                            ),
                          if (invitedBy != null)
                            Text(
                                'By ${invitedBy['full_name'] ?? 'Unknown'}'),
                        ],
                      ),
                      trailing: status == 'pending'
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.alertRed),
                              onPressed: () => _cancelInvite(inv['id'] as String),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('Error loading invitations: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await Supabase.instance.client
          .from('invitations')
          .update({'status': 'cancelled'}).eq('id', inviteId);
      ref.invalidate(_invitationsProvider(widget.groupId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    }
  }
}
