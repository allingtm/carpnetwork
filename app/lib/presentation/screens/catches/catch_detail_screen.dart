import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/catch_providers.dart';
import '../../theme/app_theme.dart';

class CatchDetailScreen extends ConsumerWidget {
  final String groupId;
  final String catchId;

  const CatchDetailScreen({
    super.key,
    required this.groupId,
    required this.catchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catchAsync = ref.watch(catchDetailProvider(catchId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catch Detail'),
        actions: [
          catchAsync.whenOrNull(
                data: (c) {
                  if (c == null || c.userId != currentUserId) return null;
                  return PopupMenuButton<String>(
                    onSelected: (action) => _handleAction(
                        context, ref, action, c.id),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: AppColors.alertRed)),
                      ),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: catchAsync.when(
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Catch not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo gallery
                _PhotoGallery(catchId: c.id),

                // Weight & Species header
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.forSpecies(c.fishSpecies),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.fishWeightLb}lb ${c.fishWeightOz}oz',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: AppColors.slate,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.forSpecies(c.fishSpecies)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _capitalize(
                                c.fishSpecies.replaceAll('_', ' ')),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  AppColors.forSpecies(c.fishSpecies),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (c.fishName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '"${c.fishName}"',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: 24),

                // Catch details
                _DetailRow(
                  icon: Icons.access_time,
                  label: 'Caught',
                  value: DateFormat.yMMMd().add_Hm().format(c.caughtAt),
                ),

                if (c.swim != null)
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Swim',
                    value: c.swim!,
                  ),

                if (c.castingDistanceWraps != null)
                  _DetailRow(
                    icon: Icons.straighten,
                    label: 'Casting distance',
                    value: '${c.castingDistanceWraps} wraps',
                  ),

                const SizedBox(height: 16),

                // Bait section
                if (c.baitType != null) ...[
                  Text('Bait',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.phishing_outlined,
                            label: 'Type',
                            value: c.baitType!,
                          ),
                          if (c.baitBrand != null)
                            _DetailRow(
                              icon: Icons.sell_outlined,
                              label: 'Brand',
                              value: c.baitBrand!,
                            ),
                          if (c.baitProduct != null)
                            _DetailRow(
                              icon: Icons.inventory_2_outlined,
                              label: 'Product',
                              value: c.baitProduct!,
                            ),
                          if (c.baitSizeMm != null)
                            _DetailRow(
                              icon: Icons.straighten,
                              label: 'Size',
                              value: '${c.baitSizeMm}mm',
                            ),
                          if (c.baitColour != null)
                            _DetailRow(
                              icon: Icons.palette_outlined,
                              label: 'Colour',
                              value: c.baitColour!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Rig section
                if (c.rigName != null) ...[
                  Text('Rig',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.settings_outlined,
                            label: 'Rig',
                            value: c.rigName!,
                          ),
                          if (c.hookSize != null)
                            _DetailRow(
                              icon: Icons.anchor,
                              label: 'Hook size',
                              value: '#${c.hookSize}',
                            ),
                          if (c.hooklinkMaterial != null)
                            _DetailRow(
                              icon: Icons.link,
                              label: 'Hooklink',
                              value: c.hooklinkMaterial!,
                            ),
                          if (c.hooklinkLengthInches != null)
                            _DetailRow(
                              icon: Icons.straighten,
                              label: 'Hooklink length',
                              value: '${c.hooklinkLengthInches}"',
                            ),
                          if (c.leadArrangement != null)
                            _DetailRow(
                              icon: Icons.line_weight,
                              label: 'Lead',
                              value: c.leadArrangement!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Weather section
                if (c.airPressureMb != null ||
                    c.windDirection != null ||
                    c.moonPhase != null) ...[
                  Text('Conditions',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          if (c.airPressureMb != null)
                            _DetailRow(
                              icon: Icons.speed,
                              label: 'Pressure',
                              value: '${c.airPressureMb} mb',
                            ),
                          if (c.windDirection != null)
                            _DetailRow(
                              icon: Icons.air,
                              label: 'Wind',
                              value:
                                  '${c.windDirection} ${c.windSpeedMph ?? 0} mph',
                            ),
                          if (c.airTempC != null)
                            _DetailRow(
                              icon: Icons.thermostat,
                              label: 'Air temp',
                              value: '${c.airTempC}°C',
                            ),
                          if (c.waterTempC != null)
                            _DetailRow(
                              icon: Icons.water,
                              label: 'Water temp',
                              value: '${c.waterTempC}°C',
                            ),
                          if (c.cloudCover != null)
                            _DetailRow(
                              icon: Icons.cloud_outlined,
                              label: 'Cloud',
                              value: '${c.cloudCover}%',
                            ),
                          if (c.moonPhase != null)
                            _DetailRow(
                              icon: Icons.nightlight_round,
                              label: 'Moon',
                              value: c.moonPhase!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes
                if (c.notes != null && c.notes!.isNotEmpty) ...[
                  Text('Notes',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(c.notes!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String catchId,
  ) async {
    switch (action) {
      case 'edit':
        context.go('/groups/$groupId/catch/new');
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete catch'),
            content: const Text(
                'Are you sure? This catch report will be permanently removed.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.alertRed),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;

        final repo = ref.read(catchRepositoryProvider);
        await repo.softDeleteCatch(catchId);
        if (context.mounted) context.pop();
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _PhotoGallery extends StatelessWidget {
  final String catchId;

  const _PhotoGallery({required this.catchId});

  @override
  Widget build(BuildContext context) {
    // Photos will be loaded from Supabase catch_report_photos table
    // For now, query the photos for this catch
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('catch_report_photos')
          .select()
          .eq('catch_report_id', catchId)
          .order('sort_order', ascending: true),
      builder: (context, snapshot) {
        final photos = snapshot.data;
        if (photos == null || photos.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            SizedBox(
              height: 240,
              child: PageView.builder(
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final url = photos[index]['url'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.mist,
                          child: const Center(
                              child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.mist,
                          child: const Icon(Icons.broken_image,
                              color: Colors.white54, size: 48),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (photos.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${photos.length} photos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
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
