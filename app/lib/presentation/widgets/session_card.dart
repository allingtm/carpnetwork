import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback? onTap;

  const SessionCard({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = session['title'] as String? ?? 'Fishing Session';
    final venue = session['venues'] as Map<String, dynamic>?;
    final startsAt = DateTime.tryParse(session['starts_at'] as String? ?? '');
    final durationType = session['duration_type'] as String?;

    return Card(
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
                  color: AppColors.reedGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today,
                    size: 20, color: AppColors.reedGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (startsAt != null)
                          Text(
                            DateFormat.MMMd().format(startsAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (durationType != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            durationType.replaceAll('_', ' '),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.reedGreen),
                          ),
                        ],
                      ],
                    ),
                    if (venue != null)
                      Text(
                        venue['name'] as String? ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mist),
            ],
          ),
        ),
      ),
    );
  }
}
