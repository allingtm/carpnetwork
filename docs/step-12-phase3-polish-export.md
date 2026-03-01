# Carp.Network — Step 12: Phase 3 — Polish and Export

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 11, 12, 4.4, 9.5  
**Depends on:** Step 11 (Phase 2 complete)  
**Commit after each sub-task. Final:** `git commit -m "Step 12: Phase 3 complete — export, succession, photo library, polish"`

---

## Context

Phase 3 adds data export, admin succession automation, the photo library, typing indicators, advanced filtering, and performance polish. After this, the app is ready for App Store / Google Play submission.

---

## Task 12.1: Data Export System

**`supabase/functions/export-request/index.ts`:**
- Auth: JWT required
- Creates an `exports` record with status `pending`
- Dispatches Inngest job `export/generate`
- Returns 202 with export_id

**`inngest/src/functions/export-generate.ts`:**
- Queries all catch_reports, photos, messages for the user's group (or for a specific removed member)
- Generates a ZIP file containing:
  - `catches.csv` — all catch data
  - `photos/` — downloaded from R2
  - `messages.csv` — message history
- Uploads ZIP to R2
- Updates `exports` table with status `complete` and download URL
- Sends push notification: "Your export is ready"

**Removed member export window (Spec Section 12):**
- Removed members have 30 days to request an export
- Check `removed_members.export_available_until` before allowing
- After 30 days, export returns 403

**Flutter screen:**
- `lib/presentation/screens/export/export_screen.dart` — request export, show progress, download link

**Reference:** Spec Sections 7.1, 12, 2.15, 2.16

---

## Task 12.2: Admin Succession Automation

**`supabase/functions/cron-succession-check/index.ts`:**
- Auth: CRON_SECRET
- Runs daily
- Queries groups where ALL admins have `last_sign_in_at` older than the succession threshold (e.g. 90 days)
- For each qualifying group:
  - If a successor is nominated → promote successor to admin, send push notification
  - If no successor → identify most senior active member → promote, send push notification
  - If no active members → mark group as dormant

**Flutter UI (already partially built in Step 07):**
- Succession nomination in members screen
- Admin step-down option
- Succession alert banner on group feed when triggered

**Reference:** Spec Section 11

---

## Task 12.3: Photo Library Screen

Create `lib/presentation/screens/photos/photo_library_screen.dart`:

- Grid view of all catch photos for the group
- Use `SliverGrid` with `addAutomaticKeepAlives: false` for memory efficiency
- `CachedNetworkImage` with `memCacheHeight: 400`, `memCacheWidth: 400`
- `fadeInDuration: Duration.zero` for fast scrolling
- Configure `DefaultCacheManager` with 200MB max disk cache
- Tap photo → full-resolution view with pinch-to-zoom
- Filter by: species, venue, date range, member
- Sort by: date, weight of associated catch

**Reference:** Spec Sections 4.4, 6.1

---

## Task 12.4: Typing Indicators (Presence)

Implement Supabase Presence for the group chat:

```dart
final channel = Supabase.instance.client.channel('group:$groupId');

// Track presence
await channel.track({
  'user_id': currentUserId,
  'typing': false,
});

// Update typing state
await channel.track({
  'user_id': currentUserId,
  'typing': true,
});

// Listen for presence changes
channel.onPresenceSync((payload) {
  final typingUsers = payload.currentPresences
    .where((p) => p.payload['typing'] == true)
    .map((p) => p.payload['user_id'])
    .where((id) => id != currentUserId)
    .toList();
  // Update UI: "John is typing..."
});
```

Show typing indicator below the message input: "{name} is typing..." or "{name1} and {name2} are typing..."

Debounce typing state: set `typing: true` on keypress, set `typing: false` after 3 seconds of no input.

**Reference:** Spec Section 9.5

---

## Task 12.5: Advanced Repository Filtering

Enhance the repository screen from Step 07:

- Multi-field combined filters (species AND venue AND date range AND weight range)
- Date range picker (from/to)
- Weight range slider (min/max)
- Venue multi-select
- Species multi-select
- Bait type filter
- "Clear all filters" button
- Filter count badge on filter button
- Save favourite filter combinations (local storage)

**Reference:** Spec Section 6.1

---

## Task 12.6: Cloudflare Image Resizing

Configure Cloudflare Image Resizing for thumbnail delivery:

- Update image URLs to use Cloudflare transform parameters:
  ```
  {R2_PUBLIC_URL}/{key}?width=400&height=400&fit=cover&format=auto
  ```
- Grid thumbnails: 400×400 cover
- Feed cards: 800×600 contain
- Full resolution: original size
- `format=auto` delivers WebP to supported clients, JPEG fallback

Update `CachedNetworkImage` URLs in all widgets to use transformed URLs for thumbnails.

**Reference:** Spec Section 4.4

---

## Task 12.7: Performance Profiling

Use Flutter DevTools to profile and optimise:

- [ ] Feed scrolls at 60fps with 100+ items
- [ ] No memory leaks (check for undisposed Broadcast channels)
- [ ] Image cache stays within 200MB disk limit
- [ ] Catch form opens in < 500ms
- [ ] App launch to dashboard in < 2 seconds (from warm cache)
- [ ] Background photo upload doesn't cause UI jank
- [ ] No unnecessary rebuilds (check with `RepaintBoundary` debug mode)

Fix any issues found.

---

## Task 12.8: App Store Preparation

- iOS: App Store Connect setup, screenshots (6.5" and 5.5"), app description, keywords, privacy nutrition labels
- Android: Google Play Console setup, feature graphic, screenshots, app description, content rating questionnaire
- Both: App review guidelines compliance check (subscription disclosure, privacy policy link, data deletion capability)

**Build commands:**
```bash
# iOS
cd app && flutter build ios --dart-define-from-file=.env.json --obfuscate --split-debug-info=build/symbols

# Android
cd app && flutter build appbundle --dart-define-from-file=.env.json --obfuscate --split-debug-info=build/symbols
```

**Reference:** Spec Section 14.1

---

## Validation

1. `flutter analyze` — zero errors
2. Export generates ZIP and sends notification
3. Removed member can export within 30 days, blocked after
4. Succession auto-promotes after admin inactivity
5. Photo library scrolls smoothly with 200+ photos
6. Typing indicators appear in chat
7. Advanced filters combine correctly
8. Image resizing URLs serve correct dimensions
9. DevTools shows 60fps scrolling, no memory leaks
10. App builds for release on both platforms

---

## Final Signoff

```bash
git add .
git commit -m "Phase 3 complete: export, succession, photo library, typing, advanced filters, performance"
git tag v1.0-release-candidate
```

The app is ready for beta testing and App Store / Google Play submission.
