# Carp.Network — Step 06: Offline-First Architecture + Catch Logging

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 2.7, 4.2, 6.1, 8.3, 10.1, 10.2, 10.3  
**Depends on:** Step 03 (Flutter foundation), Step 05 (photo Edge Functions)  
**Commit after completion:** `git commit -m "Step 06: Offline-first Brick models, catch form, photo capture, weather/moon"`

---

## Context

This is the most important feature in the app. The core use case is: angler on the bank at 4am, poor or zero connectivity, catches a fish, needs to log it instantly and reliably. The catch must save to local SQLite immediately, sync to Supabase when connectivity resumes, and photos upload in the background.

---

## Task 1: Brick Offline Models

Set up Brick with the `brick_offline_first_with_supabase` adapter. Create Brick models for the primary entities:

**`lib/data/catches/models/catch_report.model.dart`:**
- All fields from Spec Section 2.7
- Brick annotations mapping to Supabase table `catch_reports`
- Include: species, fish_weight_lb, fish_weight_oz, named_fish, bait_type, bait_description, hookbait, rig_type, rig_description, distance_from_bank, swim_number, notes, caught_at, air_pressure_mb, temperature_c, wind_mph, wind_direction, weather_conditions, moon_phase

**`lib/data/catches/models/venue.model.dart`:**
- Fields from Spec Section 2.9
- name, location_lat, location_lng, location_description, water_type

**`lib/data/messages/models/message.model.dart`:**
- Fields from Spec Section 2.13
- group_id, user_id, content, reply_to_id, deleted_at

**Configure sync scoping per Spec Section 10.2:**
- `catch_reports`: filter by `group_id IN (user's groups)` AND `created_at > 90 days ago`
- `venues`: filter by venues referenced by user's groups
- `messages`: filter by `group_id IN (user's groups)` AND `created_at > 30 days ago`

**Conflict resolution (Spec Section 10.3):** Last-write-wins on `updated_at`.

Run `dart run build_runner build` to generate Brick adapters.

**Reference:** Spec Sections 10.1, 10.2, 10.3

---

## Task 2: Catch Repository

Create `lib/data/catches/catch_repository.dart`:

- `saveCatch(CatchReport)` — writes to local Brick/Drift database immediately. Returns instantly. Brick handles sync to Supabase in the background.
- `getCatchesForGroup(groupId, {offset, limit})` — reads from local SQLite (instant rendering). Paginated.
- `getCatch(id)` — single catch by ID from local DB.
- `updateCatch(CatchReport)` — optimistic update to local DB.
- `softDeleteCatch(id)` — sets deleted_at locally, syncs.
- `searchCatches(groupId, {species, venue, bait, dateRange})` — local search with filters.

Create `lib/application/providers/catch_providers.dart`:
- `catchesProvider(groupId)` — watches Brick for changes, returns live list
- `catchDetailProvider(catchId)` — single catch

**Reference:** Spec Sections 10.1, 10.2

---

## Task 3: Catch Logging Form

Create `lib/presentation/screens/catches/catch_form_screen.dart`.

This is the core screen. It must work with ZERO connectivity.

**Form fields (all from Spec Section 2.7):**

| Field | Widget | Notes |
|---|---|---|
| Species | Dropdown | Common, Mirror, Leather, Grass, Linear, Other |
| Weight (lb) | Number input | Whole pounds |
| Weight (oz) | Number input | 0–15, CHECK constraint |
| Named fish | Text (optional) | Only if rule_set allows |
| Venue | Dropdown/search | From locally cached venues |
| Swim number | Text (optional) | Only if rule_set location detail = venue_and_swim |
| Bait type | Dropdown | Boilie, Pellet, Particle, Natural, Other |
| Bait description | Text (optional) | Free text |
| Hookbait | Text (optional) | Free text |
| Rig type | Dropdown | Ronnie, Chod, German, D-rig, Other |
| Rig description | Text (optional) | Free text |
| Distance from bank | Text (optional) | In yards |
| Notes | Multiline text | Free text |
| Caught at | DateTime picker | Defaults to now() |
| Photos | Camera/gallery | Via photo capture widget |
| Weather | Auto-populated | From weather API if online, null if offline |
| Moon phase | Auto-populated | Calculated locally from date (no network needed) |

**Save behaviour:**
- On "Save", write the catch report to local Brick/Drift database **immediately**
- Show "Saved ✓" confirmation
- Navigate back to feed — catch appears instantly with photo "Uploading..." placeholders
- Brick syncs the data record to Supabase in the background
- Photos queue separately via PendingUpload records (see Task 5)

**Reference:** Spec Sections 2.7, 6.1, 10.1

---

## Task 4: Weather and Moon Phase Services

**`lib/application/services/weather_service.dart`:**
- Calls weather API (e.g. OpenWeatherMap) with venue lat/lng
- Returns: air_pressure_mb, temperature_c, wind_mph, wind_direction, weather_conditions
- Returns null gracefully if offline or API fails (catch still saves)
- Cache last result per venue for 30 minutes

**`lib/application/services/moon_phase_service.dart`:**
- Pure Dart calculation — no network required
- Takes a DateTime, returns moon phase string: New, Waxing Crescent, First Quarter, Waxing Gibbous, Full, Waning Gibbous, Last Quarter, Waning Crescent
- Use the standard astronomical calculation (synodic period = 29.53058770576 days)

**Reference:** Spec Section 8.3

---

## Task 5: Photo Capture Widget

Create `lib/presentation/widgets/photo_capture_widget.dart`:

1. Uses `image_picker` for camera capture or gallery selection
2. **Runs image resize on a separate isolate** to avoid UI jank:
   ```dart
   final resizedBytes = await Isolate.run(() {
     final image = img.decodeImage(rawBytes)!;
     final resized = img.copyResize(image, width: 2048);
     return img.encodeJpg(resized, quality: 85);
   });
   ```
3. Saves processed image to app temp directory
4. Creates a `PendingUpload` record in the local Drift database with status: `pending`
5. Shows thumbnail preview in the form with "Pending upload" indicator
6. Allows multiple photos (up to 5 per catch)

Create `lib/domain/models/pending_upload.dart` — Drift table:
- id, catch_report_id, group_id, local_file_path, status (pending/uploading/complete/failed), retry_count, created_at

**Reference:** Spec Section 4.2 (steps 1–3)

---

## Task 6: Background Photo Upload Service

Create `lib/data/photos/photo_upload_service.dart`:

- Processes ONE PendingUpload at a time (small and idempotent)
- Flow: query pending uploads → check connectivity → call photos-presign Edge Function → upload to R2 via presigned URL → call photos-confirm → update PendingUpload status to `complete` → delete temp file
- On failure: increment retry_count, set status back to `pending`. After 5 failures, set status to `failed`.
- Each invocation handles exactly one photo, then returns

Create `lib/data/photos/background_upload_worker.dart`:

- Workmanager callback function
- Queries Drift for pending uploads, processes one
- **Android:** Register as periodic task with `NetworkType.connected` constraint (minimum 15-minute interval)
- **iOS:** Register as one-off task. Triggered by connectivity change events AND by silent push notifications (`content-available: 1`)

Register in `main.dart`:
```dart
Workmanager().registerPeriodicTask(
  "photo-upload",
  "photo-upload-task",
  constraints: Constraints(networkType: NetworkType.connected),
  frequency: const Duration(minutes: 15),
);
```

Handle silent push for iOS in the notification service (Step 08): on receipt of `action: upload_photos`, trigger the upload worker.

**Reference:** Spec Section 4.2.1

---

## Task 7: Connectivity Banner

Create `lib/presentation/widgets/connectivity_banner.dart`:

- Uses `connectivity_plus` to monitor network state
- Shows a subtle "You're offline — catches save locally" banner at top of screen when disconnected
- Auto-hides with animation when connectivity resumes
- Shows "Back online — syncing..." briefly on reconnection

Add to the ShellRoute scaffold so it appears on all main screens.

**Reference:** Spec Section 15.3

---

## Validation

1. `dart run build_runner build` — Brick adapters generate without error
2. `flutter analyze` — zero errors
3. Catch form renders with all fields
4. Can fill in a catch and save it (to local DB) with airplane mode ON
5. Saved catch appears in feed immediately
6. Photo capture resizes image without UI jank
7. PendingUpload record created for each photo
8. Moon phase calculates correctly (verify against a known date)
9. Connectivity banner appears when offline, hides when online
