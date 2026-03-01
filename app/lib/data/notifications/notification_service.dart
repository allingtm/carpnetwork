import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level background message handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Silent push for photo upload
  if (message.data['action'] == 'upload_photos') {
    // Workmanager will handle photo uploads on next scheduled run.
    // Direct trigger from background isolate is not reliable.
  }
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static GoRouter? _router;

  /// Call once from main.dart after Firebase.initializeApp().
  static Future<void> initialize({GoRouter? router}) async {
    _router = router;

    // Request permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configure local notifications for foreground display
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'carp_network',
            'Carp.Network',
            description: 'Catch reports, messages, and group updates',
            importance: Importance.high,
          ),
        );

    // Get and register FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _upsertToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_upsertToken);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Background message tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated-state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  /// Upsert the FCM token into user_devices.
  static Future<void> _upsertToken(String token) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.from('user_devices').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'last_active_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
  }

  /// Show a local notification while app is in foreground.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'carp_network',
          'Carp.Network',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _buildPayload(message.data),
    );
  }

  /// Handle notification tap (from background state).
  static void _handleNotificationTap(RemoteMessage message) {
    final route = _routeFromData(message.data);
    if (route != null) {
      _router?.go(route);
    }
  }

  /// Handle notification tap (from local notification).
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length >= 2) {
      final type = parts[0];
      final groupId = parts[1];
      final itemId = parts.length > 2 ? parts[2] : null;

      final route = _routeForType(type, groupId, itemId);
      if (route != null) {
        _router?.go(route);
      }
    }
  }

  static String _buildPayload(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final groupId = data['group_id'] as String? ?? '';
    final itemId = data['catch_report_id'] ?? data['session_id'] ?? '';
    return '$type|$groupId|$itemId';
  }

  static String? _routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final groupId = data['group_id'] as String?;
    final itemId = data['catch_report_id'] ?? data['session_id'];

    if (groupId == null) return null;
    return _routeForType(type, groupId, itemId as String?);
  }

  static String? _routeForType(String? type, String groupId, String? itemId) {
    switch (type) {
      case 'new_catch':
        if (itemId != null) return '/groups/$groupId/catch/$itemId';
        return '/groups/$groupId';
      case 'new_message':
        return '/groups/$groupId/chat';
      case 'session_invite':
        if (itemId != null) return '/groups/$groupId/sessions/$itemId';
        return '/groups/$groupId';
      default:
        return '/groups/$groupId';
    }
  }

  /// Delete current device token on sign out.
  static Future<void> cleanUpOnSignOut() async {
    final token = await _messaging.getToken();
    if (token == null) return;

    try {
      await Supabase.instance.client
          .from('user_devices')
          .delete()
          .eq('fcm_token', token);
    } catch (_) {
      // Best effort — user may already be signed out
    }

    await _messaging.deleteToken();
  }

  /// Update the router reference (e.g. after GoRouter recreation).
  static void setRouter(GoRouter router) {
    _router = router;
  }
}
