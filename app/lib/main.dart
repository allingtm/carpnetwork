import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'application/services/weather_service.dart';
import 'brick/repository.dart';
import 'data/auth/secure_local_storage.dart';
import 'data/notifications/notification_service.dart';
import 'data/photos/background_upload_worker.dart';
import 'data/subscription/subscription_repository.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: SecureLocalStorage(),
    ),
  );

  // Initialize Brick offline-first repository
  await Repository.configure(databaseFactory);

  // Configure weather service
  const weatherKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  if (weatherKey.isNotEmpty) {
    WeatherService.configure(apiKey: weatherKey);
  }

  // Initialize Workmanager for background photo uploads
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await registerBackgroundUploadTask();

  // Initialize push notifications
  await NotificationService.initialize();

  // Configure RevenueCat subscription management
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null) {
    await SubscriptionRepository.configure(supabaseUserId: userId);
  }

  runApp(
    const ProviderScope(
      child: CarpNetworkApp(),
    ),
  );
}
