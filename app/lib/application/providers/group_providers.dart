import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/groups/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

/// User's groups for the dashboard.
final myGroupsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getMyGroups();
});

/// Single group details.
final groupDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, groupId) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getGroup(groupId);
});

/// Members list for a group.
final groupMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, groupId) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getGroupMembers(groupId);
});

/// Current user's role in a group.
final myRoleProvider =
    FutureProvider.family<String?, String>((ref, groupId) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getMyRole(groupId);
});

/// Available rule sets for group creation.
final ruleSetsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getRuleSets();
});
