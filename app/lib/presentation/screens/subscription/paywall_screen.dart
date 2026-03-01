import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/subscription/subscription_repository.dart';
import '../../theme/app_theme.dart';

final _subscriptionRepoProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final _offeringsProvider = FutureProvider<Offerings>((ref) async {
  final repo = ref.watch(_subscriptionRepoProvider);
  return repo.getOfferings();
});

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isPurchasing = false;
  String? _error;

  Future<void> _purchase(Package package) async {
    setState(() {
      _isPurchasing = true;
      _error = null;
    });

    try {
      final repo = ref.read(_subscriptionRepoProvider);
      await repo.purchase(package);
      // After successful purchase, RevenueCat webhook updates Supabase.
      // The JWT refreshes, subscriptionProvider detects the change,
      // and GoRouter guard navigates away from the paywall.
    } catch (e) {
      if (e is PlatformException) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
          // User cancelled — stay on paywall
          setState(() => _isPurchasing = false);
          return;
        }
      }
      setState(() => _error = 'Purchase failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isPurchasing = true;
      _error = null;
    });

    try {
      final repo = ref.read(_subscriptionRepoProvider);
      await repo.restorePurchases();
      // If active subscription found, same JWT refresh flow applies
    } catch (e) {
      setState(() => _error = 'Could not restore purchases.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(_offeringsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // App icon / branding
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.deepLake.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.phishing,
                    size: 40, color: AppColors.deepLake),
              ),
              const SizedBox(height: 24),

              Text(
                'Carp.Network',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Your private fishing group companion',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Value propositions
              _FeatureRow(
                  icon: Icons.cloud_off,
                  text: 'Log catches offline — syncs automatically'),
              const SizedBox(height: 12),
              _FeatureRow(
                  icon: Icons.group,
                  text: 'Private groups with custom rules'),
              const SizedBox(height: 12),
              _FeatureRow(
                  icon: Icons.analytics,
                  text: 'AI-powered fishing intelligence'),
              const SizedBox(height: 12),
              _FeatureRow(
                  icon: Icons.photo_library,
                  text: 'Unlimited catch photos with cloud storage'),

              const Spacer(),

              // Price & purchase
              offeringsAsync.when(
                data: (offerings) {
                  final monthly =
                      offerings.current?.monthly;

                  if (monthly == null) {
                    return const Text('No subscription available');
                  }

                  return Column(
                    children: [
                      Text(
                        '${monthly.storeProduct.priceString}/month',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepLake,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _isPurchasing ? null : () => _purchase(monthly),
                          child: _isPurchasing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Subscribe'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load offerings: $e'),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.alertRed)),
              ],

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isPurchasing ? null : _restore,
                child: const Text('Restore Purchases'),
              ),

              TextButton(
                onPressed: () {
                  // Sign out and go to login
                  // The auth state change will trigger GoRouter redirect
                  Supabase.instance.client.auth.signOut();
                },
                child: const Text('Maybe Later'),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.reedGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
