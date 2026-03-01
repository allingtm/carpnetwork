import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/enums/subscription_status.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

final subscriptionProvider = Provider<SubscriptionStatus>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (state) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return SubscriptionStatus.inactive;

      final jwt = _decodeJwt(session.accessToken);
      final appMetadata = jwt['app_metadata'] as Map<String, dynamic>?;
      final status = appMetadata?['subscription_status'] as String?;
      final graceUntil = appMetadata?['subscription_grace_until'] as String?;

      if (status == 'active') return SubscriptionStatus.active;
      if (status == 'past_due' && _isBeforeNow(graceUntil)) {
        return SubscriptionStatus.pastDue;
      }
      return SubscriptionStatus.inactive;
    },
    loading: () => SubscriptionStatus.active,
    error: (_, __) => SubscriptionStatus.inactive,
  );
});

Map<String, dynamic> _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return {};
  final payload = parts[1];
  final normalized = base64Url.normalize(payload);
  final decoded = utf8.decode(base64Url.decode(normalized));
  return json.decode(decoded) as Map<String, dynamic>;
}

bool _isBeforeNow(String? dateString) {
  if (dateString == null) return false;
  final date = DateTime.tryParse(dateString);
  if (date == null) return false;
  return date.isAfter(DateTime.now());
}
