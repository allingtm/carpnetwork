# Carp.Network — Step 08: Push Notifications, Subscription, and Profile

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 5.2, 5.3, 9.3, 2.17, 6.1  
**Depends on:** Step 03 (auth providers, routing), Step 04 (push-send Edge Function)  
**Commit after completion:** `git commit -m "Step 08: Push notifications, RevenueCat paywall, profile screen"`

---

## Context

This step wires up the three remaining Flutter systems: push notification handling, RevenueCat subscription management with the paywall screen, and the user profile. After this, the app has all Phase 1 features.

---

## Task 1: Push Notification Service

Create `lib/data/notifications/notification_service.dart`:

**Initialisation (called from main.dart):**
1. Request notification permissions via `firebase_messaging`
2. Get the FCM token
3. Upsert the token into `user_devices` table:
   ```dart
   await Supabase.instance.client.from('user_devices').upsert({
     'user_id': currentUserId,
     'fcm_token': token,
     'platform': Platform.isIOS ? 'ios' : 'android',
     'last_active_at': DateTime.now().toIso8601String(),
   }, onConflict: 'fcm_token');
   ```
4. Register token refresh listener — on refresh, upsert the new token

**Foreground message handling:**
- Display a local notification using `flutter_local_notifications`
- Parse the `data` payload for navigation info (group_id, catch_report_id, etc.)

**Background message handling:**
- Register `FirebaseMessaging.onBackgroundMessage(backgroundHandler)` — must be a top-level function
- For silent push (`content-available: 1` with `action: upload_photos`): trigger the photo upload worker

**Notification tap handling:**
- `FirebaseMessaging.onMessageOpenedApp.listen((message) { ... })`
- Parse the data payload and navigate via GoRouter:
  - `type: "new_catch"` → `/groups/{groupId}/catch/{catchId}`
  - `type: "new_message"` → `/groups/{groupId}/chat`
  - `type: "session_invite"` → `/groups/{groupId}/sessions/{sessionId}`

**Clean up on sign out:**
- Delete the current device's token from `user_devices`
- Unsubscribe from FCM topics if any

**Reference:** Spec Sections 9.3, 2.17, 4.2.1

---

## Task 2: Subscription Repository

Create `lib/data/subscription/subscription_repository.dart`:

- Wraps the RevenueCat SDK (`purchases_flutter`)
- **Configure on app launch** (from main.dart):
  ```dart
  await Purchases.configure(PurchasesConfiguration(
    Platform.isIOS
      ? const String.fromEnvironment('REVENUCAT_APPLE_API_KEY')
      : const String.fromEnvironment('REVENUCAT_GOOGLE_API_KEY'),
  )..appUserID = supabaseUserId);
  ```
  The `appUserID` MUST be the Supabase user UUID so RevenueCat webhooks can map events back to the correct user.

- `getOfferings()` — fetch available subscription packages from RevenueCat
- `purchase(package)` — initiate purchase flow (handles App Store / Google Play native billing)
- `restorePurchases()` — restore previous purchases (important for device transfers)
- `getCustomerInfo()` — current subscription status from RevenueCat

**Reference:** Spec Section 5.2

---

## Task 3: Paywall Screen

Create `lib/presentation/screens/subscription/paywall_screen.dart`:

- Displayed when GoRouter's subscription guard detects `SubscriptionStatus.inactive`
- Shows:
  - App value proposition (brief)
  - Price: £4.99/month (fetched from RevenueCat offerings, not hardcoded)
  - "Subscribe" button → calls `subscriptionRepository.purchase()`
  - "Restore Purchases" button → calls `subscriptionRepository.restorePurchases()`
  - "Maybe Later" / sign out option
- After successful purchase:
  - RevenueCat sends webhook to `revenucat-webhook` Edge Function
  - Edge Function updates `users.subscription_status` to `active`
  - Supabase refreshes the JWT (with new claims from custom access token hook)
  - The reactive `subscriptionProvider` detects the JWT change
  - GoRouter guard allows navigation to the dashboard

**Handle edge cases:**
- Purchase cancelled: stay on paywall
- Purchase failed: show error, allow retry
- Already subscribed (restore): navigate to dashboard

**Reference:** Spec Sections 5.2, 5.3, 6.1

---

## Task 4: Profile Screen

Create `lib/presentation/screens/profile/profile_screen.dart`:

- **User info section:**
  - Display name (editable)
  - Email (read-only)
  - Location (editable, optional)
  
- **Subscription section:**
  - Current status (Active / Expiring / Inactive)
  - Renewal date
  - "Manage Subscription" → opens App Store / Play Store subscription management
  
- **App section:**
  - Groups count
  - Total catches logged
  
- **Actions:**
  - "Sign Out" button → clears session, deletes device token from user_devices, navigates to login
  
Create `lib/data/auth/auth_repository.dart` (update from Step 03):
- Add `signOut()` method that:
  1. Deletes current device's FCM token from `user_devices`
  2. Calls `Supabase.instance.client.auth.signOut()`
  3. Clears any local Brick/Drift data if needed

**Reference:** Spec Section 6.1

---

## Task 5: Group Settings Screen

Create `lib/presentation/screens/groups/group_settings_screen.dart`:

- Displays the group's rule set configuration in a readable format
- Shows: max members, location detail level, photo rules, sharing rules, named fish logging
- Only admins see edit options (future: rule set customisation)
- "Leave Group" button (for non-admin members)
- Admin-specific: succession nomination, group name edit

**Reference:** Spec Sections 2.6, 2.6.1, 11

---

## Validation

1. `flutter analyze` — zero errors
2. FCM token is saved to `user_devices` on app launch
3. Push notifications received when another user sends a message (test with two devices/simulators)
4. Tapping a notification navigates to the correct screen
5. Silent push triggers photo upload worker on iOS
6. Paywall screen displays RevenueCat offering
7. After simulated subscription activation, subscription provider updates and dashboard becomes accessible
8. Profile screen shows correct user info
9. Sign out clears session and navigates to login
10. Token refresh callback updates `user_devices`
