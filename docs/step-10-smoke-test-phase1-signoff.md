# Carp.Network — Step 10: End-to-End Smoke Test and Phase 1 Signoff

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 16, 17  
**Depends on:** Steps 00–09 all complete  
**Commit after completion:** `git commit -m "Step 10: Phase 1 complete — smoke test passed"`

---

## Context

This is the final Phase 1 step. No new features — this is pure verification. Walk through every user journey end-to-end, document any issues, and fix them. The goal is a working MVP that handles the core use case: anglers logging catches offline, syncing when connected, communicating in real-time, and managing groups with subscription billing.

---

## Smoke Test Checklist

Work through each test sequentially. If any test fails, fix the issue before moving on.

### Infrastructure

- [ ] `supabase db reset` — all migrations apply cleanly (zero errors)
- [ ] `supabase start` — local Supabase runs
- [ ] `cd inngest && npm run dev` — Inngest dev server runs
- [ ] `cd app && flutter run` — app launches on iOS simulator
- [ ] `cd app && flutter run` — app launches on Android emulator
- [ ] `cd marketing && npm run dev` — marketing site serves

### Authentication

- [ ] Login screen renders with email/password fields and magic link option
- [ ] Can register a new user with email + password
- [ ] User record created in `users` table with correct defaults
- [ ] Can sign out and sign back in
- [ ] GoRouter redirects unauthenticated users to `/login`
- [ ] Magic link sends email and completes auth flow via deep link

### Subscription

- [ ] New user (no subscription) is redirected to paywall screen
- [ ] Paywall shows RevenueCat offering with correct price
- [ ] "Restore Purchases" button works
- [ ] After simulating subscription activation (manually update `users.subscription_status` to `active`), user can access dashboard
- [ ] `subscriptionProvider` reacts to JWT refresh — no app restart needed
- [ ] GoRouter subscription guard blocks access when status = `inactive`

### Groups

- [ ] Dashboard shows empty state for new user
- [ ] Can create a group with name and rule set selection
- [ ] New group appears on dashboard with correct member count (1)
- [ ] Group feed shows empty state
- [ ] Can generate an invite link
- [ ] Invite URL opens correctly via deep link (test on device)
- [ ] Second user can redeem invite and join the group
- [ ] Member count updates to 2
- [ ] Members screen shows both members with correct roles

### Catch Logging (Online)

- [ ] "Log Catch" button navigates to catch form
- [ ] All form fields render correctly
- [ ] Species dropdown has correct options
- [ ] Weight validation works (oz must be 0–15)
- [ ] Venue selector shows available venues
- [ ] Weather auto-populates when online
- [ ] Moon phase displays for selected date
- [ ] Can capture a photo from camera
- [ ] Photo resizes without UI jank (isolate)
- [ ] Save creates catch report in database
- [ ] Catch appears in group feed immediately
- [ ] Photo uploads via background queue
- [ ] Photo placeholder updates to real image after processing
- [ ] Catch detail screen shows all fields correctly

### Catch Logging (Offline) — THE CRITICAL TEST

- [ ] Enable airplane mode on device
- [ ] Can still open catch form
- [ ] All local data (venues, species) available offline
- [ ] Weather fields show "Offline — will backfill when connected"
- [ ] Moon phase still calculates (pure Dart, no network)
- [ ] Can fill in all fields and save
- [ ] "Saved ✓" confirmation appears
- [ ] Catch appears in local feed immediately
- [ ] Photo shows "Pending upload" indicator
- [ ] Disable airplane mode
- [ ] Catch syncs to Supabase (verify in database)
- [ ] Photo uploads via background queue (may take up to 15 mins on Android, or triggered by silent push on iOS)
- [ ] Weather backfill Edge Function populates weather data
- [ ] Other group members see the catch in their feed

### Messaging

- [ ] Can send a message in group chat
- [ ] Message appears immediately for sender
- [ ] Message appears in real-time for other connected members (Broadcast)
- [ ] Push notification received on other members' devices
- [ ] Tapping push notification navigates to group chat
- [ ] Can reply to a message
- [ ] Soft-deleted messages show "[Message deleted]"

### Repository

- [ ] Repository screen shows catch history
- [ ] Search works (by species, venue, bait)
- [ ] Sort by date works
- [ ] Sort by weight works
- [ ] Filter chips work
- [ ] Tap catch → catch detail screen

### Admin Actions

- [ ] Admin can promote member to admin
- [ ] Admin can remove member (calls member-remove Edge Function)
- [ ] Removed member loses access immediately
- [ ] Removed member record exists in `removed_members` table
- [ ] Admin can nominate successor
- [ ] Admin can step down (if 2+ admins)

### Push Notifications

- [ ] FCM token saved to `user_devices` on launch
- [ ] Push received for new catch in group
- [ ] Push received for new message in group
- [ ] Notification tap navigates to correct screen
- [ ] Token refresh updates `user_devices`

### Profile

- [ ] Profile screen shows user info
- [ ] Can edit display name
- [ ] Subscription status displays correctly
- [ ] Sign out clears session and navigates to login

### Error Handling (Spec Section 16)

- [ ] Subscription lapse: user redirected to paywall mid-session
- [ ] Failed photo upload: error shown in-app after 5 retries
- [ ] Concurrent editing: optimistic locking rejects stale updates
- [ ] Network timeout: appropriate error messages, no crashes

### Security (Spec Section 17)

- [ ] Service role key is NOT in the Flutter binary (grep the build output)
- [ ] Only anon key in `--dart-define-from-file`
- [ ] RLS prevents cross-group data access (test with SQL: user A cannot SELECT user B's group data)
- [ ] PKCE flow active for magic link auth
- [ ] SecureLocalStorage persists sessions to Keychain/Keystore (not SharedPreferences)

---

## Performance Quick Check

- [ ] Feed scrolls at 60fps (check with Flutter DevTools)
- [ ] Catch form opens instantly (no network wait)
- [ ] Photo capture + resize completes in < 3 seconds
- [ ] Dashboard loads in < 1 second from local data
- [ ] No memory warnings on feed with 50+ items

---

## Issues Found

Document any issues here and fix before signing off:

| # | Issue | Severity | Status |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Phase 1 Signoff

When all checks pass:

```bash
git add .
git commit -m "Phase 1 complete: MVP with offline catch logging, real-time messaging, groups, subscriptions"
git tag v1.0-phase1
```

Phase 1 is complete. Proceed to Phase 2 (Intelligence) only when this is solid.
