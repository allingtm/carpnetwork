import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../domain/enums/subscription_status.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      _nameController.text = metadata?['full_name'] as String? ?? '';
      _locationController.text = metadata?['location'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
          },
        ),
      );

      // Also update the users table
      await Supabase.instance.client.from('users').update({
        'full_name': _nameController.text.trim(),
      }).eq('id', Supabase.instance.client.auth.currentUser!.id);

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm != true) return;

    // Sign out via auth repository (handles FCM cleanup internally)
    final authRepo = AuthRepository();
    await authRepo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveProfile,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.deepLake.withValues(alpha: 0.1),
                  child: Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepLake,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isEditing)
                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : 'No name set',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // User info section
          if (_isEditing) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user?.email ?? 'Unknown',
                    ),
                    if (_locationController.text.isNotEmpty)
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: _locationController.text,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Subscription section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subscription',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(subscription)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _statusLabel(subscription),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(subscription),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Opens platform subscription management
                      // (App Store / Play Store)
                    },
                    child: const Text('Manage Subscription'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats section
          Card(
            child: FutureBuilder<Map<String, int>>(
              future: _loadStats(),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {};
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stats',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.group,
                        label: 'Groups',
                        value: '${stats['groups'] ?? 0}',
                      ),
                      _InfoRow(
                        icon: Icons.phishing,
                        label: 'Total catches',
                        value: '${stats['catches'] ?? 0}',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Sign out
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.alertRed,
              side: const BorderSide(color: AppColors.alertRed),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<Map<String, int>> _loadStats() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return {};

    final client = Supabase.instance.client;

    final groups = await client
        .from('group_memberships')
        .select('id')
        .eq('user_id', userId);

    final catches = await client
        .from('catch_reports')
        .select('id')
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    return {
      'groups': (groups as List).length,
      'catches': (catches as List).length,
    };
  }

  Color _statusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return AppColors.success;
      case SubscriptionStatus.pastDue:
        return AppColors.goldenHour;
      case SubscriptionStatus.inactive:
        return AppColors.alertRed;
    }
  }

  String _statusLabel(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.pastDue:
        return 'Expiring Soon';
      case SubscriptionStatus.inactive:
        return 'Inactive';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
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
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.slate.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
