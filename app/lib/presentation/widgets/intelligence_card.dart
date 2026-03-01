import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stub card for AI intelligence items (Phase 2).
class IntelligenceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const IntelligenceCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = item['category'] as String? ?? 'pattern';
    final title = item['title'] as String? ?? '';
    final highlight = item['highlight'] as String? ?? '';

    return RepaintBoundary(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.goldenHour.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForCategory(category),
                      size: 20, color: AppColors.goldenHour),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.goldenHour.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldenHour,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                      if (highlight.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          highlight,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconForCategory(String category) {
    switch (category) {
      case 'pattern':
        return Icons.auto_graph;
      case 'venue':
        return Icons.water;
      case 'briefing':
        return Icons.assignment;
      case 'product':
        return Icons.shopping_bag;
      default:
        return Icons.lightbulb;
    }
  }
}
