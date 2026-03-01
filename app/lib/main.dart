import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth/secure_local_storage.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: SecureLocalStorage(),
    ),
  );

  // Firebase and RevenueCat will be initialised in later steps
  // await Firebase.initializeApp();
  // await Purchases.configure(PurchasesConfiguration('...'));
  // Workmanager().initialize(callbackDispatcher);

  runApp(
    const ProviderScope(
      child: CarpNetworkApp(),
    ),
  );
}
