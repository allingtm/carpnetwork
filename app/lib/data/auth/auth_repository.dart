import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/notification_service.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signInWithMagicLink({required String email}) {
    return _client.auth.signInWithOtp(email: email);
  }

  /// Sign out: cleans up FCM token, then signs out of Supabase.
  Future<void> signOut() async {
    await NotificationService.cleanUpOnSignOut();
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;
}
