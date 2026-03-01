import 'package:supabase_flutter/supabase_flutter.dart';

class GroupRepository {
  final SupabaseClient _client;

  GroupRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get groups where current user has a membership.
  Future<List<Map<String, dynamic>>> getMyGroups() async {
    final userId = _client.auth.currentUser!.id;

    final memberships = await _client
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId);

    if (memberships.isEmpty) return [];

    final groupIds =
        memberships.map((m) => m['group_id'] as String).toList();

    final groups = await _client
        .from('groups')
        .select('*, rule_sets(name)')
        .inFilter('id', groupIds)
        .order('created_at', ascending: false);

    return groups;
  }

  /// Create a new group and add the creator as admin.
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String ruleSetId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final group = await _client
        .from('groups')
        .insert({
          'name': name,
          'rule_set_id': ruleSetId,
          'created_by': userId,
        })
        .select()
        .single();

    // Create admin membership for the creator
    await _client.from('group_memberships').insert({
      'group_id': group['id'],
      'user_id': userId,
      'role': 'admin',
    });

    return group;
  }

  /// Get single group details.
  Future<Map<String, dynamic>?> getGroup(String groupId) async {
    final result = await _client
        .from('groups')
        .select('*, rule_sets(name, description, rules)')
        .eq('id', groupId)
        .maybeSingle();

    return result;
  }

  /// Get members of a group with user details.
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final members = await _client
        .from('group_memberships')
        .select('*, users(id, full_name, avatar_url, email)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    return members;
  }

  /// Get current user's role in a group.
  Future<String?> getMyRole(String groupId) async {
    final userId = _client.auth.currentUser!.id;

    final membership = await _client
        .from('group_memberships')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    return membership?['role'] as String?;
  }

  /// Promote a member to admin.
  Future<void> promoteMember(String groupId, String userId) async {
    await _client
        .from('group_memberships')
        .update({'role': 'admin'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Get available rule sets.
  Future<List<Map<String, dynamic>>> getRuleSets() async {
    return await _client
        .from('rule_sets')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
  }

  /// Get pending invitations for a group.
  Future<List<Map<String, dynamic>>> getInvitations(String groupId) async {
    return await _client
        .from('invitations')
        .select('*, users:invited_by(full_name)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
  }
}
