# Carp.Network — Step 03: Flutter App Foundation

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 5.1, 5.3, 6.1, 15.1, 15.2, 15.3  
**Depends on:** Step 00 (Flutter project exists), Step 02 (database with JWT hook)  
**Commit after completion:** `git commit -m "Step 03: Flutter app foundation — auth, theme, routing, providers"`

---

## Context

This step builds the Flutter app skeleton: initialisation, secure storage, authentication, theme, routing, and the core Riverpod providers. Every screen in future steps plugs into this foundation.

---

## Task 1: SecureLocalStorage

Create `lib/data/auth/secure_local_storage.dart`.

This overrides Supabase's default SharedPreferences token storage with Keychain (iOS) / Keystore (Android). Copy the implementation from **Spec Section 5.1** exactly:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureLocalStorage extends LocalStorage {
  final _storage = const FlutterSecureStorage();
  static const _key = 'supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String value) =>
      _storage.write(key: _key, value: value);
}
```

**Reference:** Spec Section 5.1

---

## Task 2: App Entry Point

Create `lib/main.dart`:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Initialise Supabase with SecureLocalStorage and PKCE:
   ```dart
   await Supabase.initialize(
     url: const String.fromEnvironment('SUPABASE_URL'),
     anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
     authOptions: FlutterAuthClientOptions(
       authFlowType: AuthFlowType.pkce,
       localStorage: SecureLocalStorage(),
     ),
   );
   ```
3. Initialise Firebase: `await Firebase.initializeApp()`
4. Initialise RevenueCat with platform-specific API keys (from `--dart-define-from-file`)
5. Initialise Workmanager: `Workmanager().initialize(callbackDispatcher)`
6. Wrap the app in `ProviderScope` and run `CarpNetworkApp`

**Reference:** Spec Sections 5.1, 14.1

---

## Task 3: Core Riverpod Providers

Create `lib/application/providers/auth_providers.dart`:

**authStateProvider** — StreamProvider watching Supabase auth state changes:
```dart
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
```

**subscriptionProvider** — MUST derive from authStateProvider so it recomputes when the JWT refreshes. Copy the reactive implementation from **Spec Section 5.3** exactly. Do NOT create a static Provider that reads the session once — it must watch the auth state stream.

**currentUserProvider** — Provider that reads the current Supabase user (nullable).

Create `lib/domain/enums/subscription_status.dart` with enum: `active`, `pastDue`, `inactive`.

**Reference:** Spec Section 5.3

---

## Task 4: Theme and Design System

Create `lib/presentation/theme/app_theme.dart`.

Implement the complete Material 3 theme from the spec:

**Colour palette (Spec Section 15.1):**
- Primary: Deep Lake `#1B3A4B`
- Secondary: Reed Green `#4A7C59`
- Tertiary: Golden Hour `#D4A843`
- Surface: Pale Mist `#F5F5F0`
- Background: White `#FFFFFF`
- Error: Alert Red `#C62828`
- Success: Landed `#2E7D32`

**Typography (Spec Section 15.2):**
- Body and headings: Inter (use Google Fonts package or bundle)
- Weights and measurements: JetBrains Mono (monospaced for alignment in tables/stats)

**Fish species colour map (Spec Section 15.3):**
- Common Carp → Deep Lake
- Mirror Carp → Golden Hour
- Leather Carp → Reed Green
- Grass Carp → a lighter green
- Linear Carp → a distinct colour

Create `ThemeData` for light mode using `ColorScheme.fromSeed` with the Deep Lake primary, then override specifics.

**Reference:** Spec Sections 15.1, 15.2, 15.3

---

## Task 5: GoRouter Configuration

Create `lib/presentation/routing/app_router.dart`.

Set up GoRouter with:

**Auth redirect:** Unauthenticated users → `/login`  
**Subscription redirect:** Inactive subscription → `/subscription`  
**Use `ref.watch(authStateProvider)` and `ref.watch(subscriptionProvider)` for guards.**

**Route structure (Spec Section 6.1):**

```
/login                        ← Login screen
/register                     ← Registration (via invite only)
/invite/:token                ← Invite landing (deep link)
/auth/callback                ← Magic link callback
/subscription                 ← Paywall

ShellRoute (with NavigationBar — 5 tabs):
  /dashboard                  ← My Groups
  /groups/:groupId            ← Group feed
  /groups/:groupId/chat       ← Group chat
  /groups/:groupId/members    ← Members list
  /groups/:groupId/repository ← Catch history
  /groups/:groupId/catch/new  ← Log catch form
  /groups/:groupId/catch/:id  ← Catch detail
  /groups/:groupId/settings   ← Group settings
  /repository                 ← Repository (global)
  /profile                    ← Profile & settings
```

**NavigationBar tabs:** Dashboard, Feed, Log Catch (FAB), Repository, Profile

**Create stub screens** for every route — just a `Scaffold` with `AppBar(title: Text('Screen Name'))` and `body: Center(child: Text('Route name'))`. This lets navigation compile and be tested before real screens are built.

**Reference:** Spec Section 6.1

---

## Task 6: App Widget

Create `lib/presentation/app.dart`:

```dart
class CarpNetworkApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Carp.Network',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

---

## Task 7: Authentication Screens

Create basic but functional auth screens:

**`lib/presentation/screens/auth/login_screen.dart`:**
- Email + password text fields
- "Sign In" button calling Supabase `signInWithPassword`
- "Send Magic Link" button calling Supabase `signInWithOtp`
- "Don't have an account? Get an invite" text

**`lib/presentation/screens/auth/register_screen.dart`:**
- Email, password, full_name fields
- "Create Account" button calling Supabase `signUp` with full_name in user metadata
- Only accessible via invite flow (pass invite token as route parameter)

**`lib/presentation/screens/auth/invite_landing_screen.dart`:**
- Receives `:token` from route parameter
- Displays loading state while validating token
- On success: shows group name and inviter, "Join" button → register or login
- On failure: shows error message

**`lib/data/auth/auth_repository.dart`:**
- Wraps Supabase auth methods: `signIn`, `signUp`, `signOut`, `signInWithMagicLink`
- Follows 4-layer architecture: screens → providers → repository → Supabase

**Reference:** Spec Sections 5.1, 6.1

---

## Validation

1. `cd app && flutter analyze` — zero errors
2. `flutter run` launches and shows login screen
3. GoRouter redirects correctly: unauthenticated → login
4. All stub screens are reachable via GoRouter (test with go('/dashboard'), go('/profile'), etc.)
5. Theme colours match the spec (visual check — Deep Lake primary in AppBar)
