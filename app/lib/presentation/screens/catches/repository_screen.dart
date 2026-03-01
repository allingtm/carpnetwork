import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/catch_providers.dart';
import '../../../brick/models/catch_report.model.dart';
import '../../theme/app_theme.dart';

class RepositoryScreen extends ConsumerStatefulWidget {
  final String groupId;

  const RepositoryScreen({super.key, required this.groupId});

  @override
  ConsumerState<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends ConsumerState<RepositoryScreen> {
  final _searchController = TextEditingController();
  String? _speciesFilter;
  String _sortBy = 'date';
  String _searchQuery = '';

  static const _speciesOptions = [
    'common',
    'mirror',
    'leather',
    'grass',
    'fully_scaled',
    'ghost',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catchesAsync = ref.watch(catchesProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Repository')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search catches...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Filter & sort chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Sort chip
                ChoiceChip(
                  label: Text(_sortBy == 'date' ? 'Newest' : 'Heaviest'),
                  selected: true,
                  onSelected: (_) {
                    setState(() {
                      _sortBy = _sortBy == 'date' ? 'weight' : 'date';
                    });
                  },
                ),
                const SizedBox(width: 8),

                // Species filter
                FilterChip(
                  label: Text(_speciesFilter != null
                      ? _capitalize(_speciesFilter!.replaceAll('_', ' '))
                      : 'Species'),
                  selected: _speciesFilter != null,
                  onSelected: (_) => _showSpeciesFilter(),
                ),
                const SizedBox(width: 8),

                // Clear filters
                if (_speciesFilter != null)
                  ActionChip(
                    label: const Text('Clear'),
                    onPressed: () =>
                        setState(() => _speciesFilter = null),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: catchesAsync.when(
              data: (catches) {
                var filtered = catches.toList();

                // Apply search
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((c) {
                    return c.fishSpecies.toLowerCase().contains(q) ||
                        (c.fishName?.toLowerCase().contains(q) ?? false) ||
                        (c.baitType?.toLowerCase().contains(q) ?? false) ||
                        (c.baitBrand?.toLowerCase().contains(q) ?? false) ||
                        (c.swim?.toLowerCase().contains(q) ?? false) ||
                        (c.notes?.toLowerCase().contains(q) ?? false);
                  }).toList();
                }

                // Apply species filter
                if (_speciesFilter != null) {
                  filtered = filtered
                      .where((c) => c.fishSpecies == _speciesFilter)
                      .toList();
                }

                // Apply sort
                if (_sortBy == 'weight') {
                  filtered.sort((a, b) {
                    final aWeight =
                        a.fishWeightLb * 16 + a.fishWeightOz;
                    final bWeight =
                        b.fishWeightLb * 16 + b.fishWeightOz;
                    return bWeight.compareTo(aWeight);
                  });
                }
                // date sort is already default from the provider

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty || _speciesFilter != null
                          ? 'No catches match your filters'
                          : 'No catches logged yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemExtent: 64,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    return _CatchRow(
                      catchReport: c,
                      onTap: () => context
                          .go('/groups/${widget.groupId}/catch/${c.id}'),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeciesFilter() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter by species',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ..._speciesOptions.map((species) => ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.forSpecies(species),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(_capitalize(species.replaceAll('_', ' '))),
                  trailing: _speciesFilter == species
                      ? const Icon(Icons.check, color: AppColors.reedGreen)
                      : null,
                  onTap: () {
                    setState(() => _speciesFilter = species);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _CatchRow extends StatelessWidget {
  final CatchReport catchReport;
  final VoidCallback? onTap;

  const _CatchRow({required this.catchReport, this.onTap});

  @override
  Widget build(BuildContext context) {
    final species = catchReport.fishSpecies;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.forSpecies(species),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                '${catchReport.fishWeightLb}lb ${catchReport.fishWeightOz}oz',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _capitalize(species.replaceAll('_', ' ')),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.forSpecies(species),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                catchReport.baitType ?? '',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.mist),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
