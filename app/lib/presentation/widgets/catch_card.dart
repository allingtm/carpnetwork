import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CatchCard extends StatelessWidget {
  final Map<String, dynamic> catchData;
  final VoidCallback? onTap;

  const CatchCard({super.key, required this.catchData, this.onTap});

  @override
  Widget build(BuildContext context) {
    final species = catchData['fish_species'] as String? ?? 'common';
    final weightLb = catchData['fish_weight_lb'] as int? ?? 0;
    final weightOz = catchData['fish_weight_oz'] as int? ?? 0;
    final fishName = catchData['fish_name'] as String?;
    final baitType = catchData['bait_type'] as String?;
    final venue = catchData['venues'] as Map<String, dynamic>?;
    final user = catchData['users'] as Map<String, dynamic>?;
    final photos = catchData['catch_report_photos'] as List?;

    return RepaintBoundary(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Species colour bar
                Container(
                  width: 4,
                  color: AppColors.forSpecies(species),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: weight + species
                        Row(
                          children: [
                            Text(
                              '${weightLb}lb ${weightOz}oz',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppColors.slate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.forSpecies(species)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _capitalize(species.replaceAll('_', ' ')),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forSpecies(species),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (fishName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '"$fishName"',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],

                        const SizedBox(height: 6),

                        // Venue + member
                        Row(
                          children: [
                            if (venue != null) ...[
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: AppColors.reedGreen),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  venue['name'] as String? ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (user != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.person_outline,
                                  size: 14, color: AppColors.slate),
                              const SizedBox(width: 2),
                              Text(
                                user['full_name'] as String? ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),

                        // Bait
                        if (baitType != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phishing_outlined,
                                  size: 14, color: AppColors.goldenHour),
                              const SizedBox(width: 4),
                              Text(baitType,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Photo thumbnail
                if (photos != null && photos.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: photos.first['url'] as String? ?? '',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheHeight: 400,
                      memCacheWidth: 400,
                      fadeInDuration: Duration.zero,
                      placeholder: (_, __) => Container(
                        width: 80,
                        height: 80,
                        color: AppColors.mist,
                        child: const Icon(Icons.photo, color: Colors.white54),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: AppColors.mist,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
