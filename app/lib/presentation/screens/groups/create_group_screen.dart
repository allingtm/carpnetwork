import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/group_providers.dart';
import '../../theme/app_theme.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedRuleSetId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _selectedRuleSetId == null) {
      if (_selectedRuleSetId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rule set')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(groupRepositoryProvider);
      final group = await repo.createGroup(
        name: _nameController.text.trim(),
        ruleSetId: _selectedRuleSetId!,
      );

      ref.invalidate(myGroupsProvider);

      if (mounted) {
        context.go('/groups/${group['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ruleSets = ref.watch(ruleSetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. The Lake Legends',
              ),
              maxLength: 100,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            Text('Rule Set', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            ruleSets.when(
              data: (list) => Column(
                children: list.map((rs) {
                  final id = rs['id'] as String;
                  final isSelected = _selectedRuleSetId == id;
                  final rules = rs['rules'] as Map<String, dynamic>?;

                  return Card(
                    color: isSelected
                        ? AppColors.deepLake.withValues(alpha: 0.05)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.deepLake
                            : AppColors.mist,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          setState(() => _selectedRuleSetId = id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rs['name'] as String? ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle,
                                      color: AppColors.deepLake),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rs['description'] as String? ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (rules != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Max ${rules['max_members'] ?? 20} members',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.reedGreen),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading rule sets: $e'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
