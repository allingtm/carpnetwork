import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionRepository {
  /// Configure RevenueCat. Call once from main.dart.
  static Future<void> configure({required String supabaseUserId}) async {
    final apiKey = Platform.isIOS
        ? const String.fromEnvironment('REVENUCAT_APPLE_API_KEY')
        : const String.fromEnvironment('REVENUCAT_GOOGLE_API_KEY');

    if (apiKey.isEmpty) return;

    final config = PurchasesConfiguration(apiKey)..appUserID = supabaseUserId;
    await Purchases.configure(config);
  }

  /// Fetch available subscription offerings from RevenueCat.
  Future<Offerings> getOfferings() async {
    return await Purchases.getOfferings();
  }

  /// Initiate a purchase flow for the given package.
  Future<PurchaseResult> purchase(Package package) async {
    return await Purchases.purchase(PurchaseParams.package(package));
  }

  /// Restore previous purchases (device transfer / reinstall).
  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }

  /// Get current customer info from RevenueCat.
  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }
}
