# Carp.Network — Technical Design Specification

**Version:** 1.5 — Final  
**Date:** March 2026  
**Author:** Solve with Software Ltd  
**Status:** Final — approved for development  

**Change log:**
- **v1.0** — Initial specification (Next.js web app)
- **v1.1** — Incorporated 47 findings from first security, performance, and best-practice review
- **v1.2** — Incorporated 12 findings from second-pass review. Self-contained document.
- **v1.3** — Incorporated external technical assessment. Final web-based specification.
- **v1.4** — Architecture pivot to Flutter mobile app (iOS + Android). Replaced Next.js frontend with Flutter + Riverpod + GoRouter. Replaced Vercel API routes with Supabase Edge Functions. Added offline-first catch logging via Brick + SQLite. Added push notifications via FCM/APNs. Added RevenueCat for in-app subscription management.
- **v1.5** — Flutter design review: 14 findings incorporated. Replaced deprecated FCM Server Key with FCM HTTP v1 API + service account JSON. Replaced sharp EXIF stripping in Edge Functions with Inngest Node.js background job (sharp has native C bindings incompatible with Deno). Added iOS silent push fallback for background photo uploads. Added concrete SecureLocalStorage implementation. Reactive subscription provider. Image resize on isolates. Multi-device push token support via user_devices table. Realtime channel cleanup. Brick sync scoping. Weather backfill trigger. Feed and image cache performance guidance.

---

## 1. Technology Stack

### 1.1 Mobile Application

| Layer | Technology | Purpose |
|---|---|---|
| Framework | Flutter (latest stable) | Cross-platform iOS + Android from single codebase |
| State management | Riverpod (with code generation) | Reactive state management, dependency injection, caching |
| Navigation | GoRouter | Declarative routing with deep link support for invite tokens and auth callbacks |
| Architecture | 4-layer (presentation → application → domain → data) | Separation of concerns, testability, maintainability |
| UI framework | Material 3 with custom Carp.Network theme | Native-feeling UI with consistent brand identity |
| Local database | Drift (SQLite) via Brick | Offline-first catch logging, local caching, sync queue |
| Offline sync | Brick (`brick_offline_first_with_supabase`) | Automatic bidirectional sync between SQLite and Supabase |
| Secure storage | `flutter_secure_storage` | JWT tokens, session data stored in Keychain (iOS) / Keystore (Android) |
| Image handling | `image_picker` + `image` package | Camera capture, gallery selection, client-side resize |
| Push notifications | Firebase Cloud Messaging (FCM) + APNs | Real-time alerts for catches, messages, session invites |
| In-app purchases | RevenueCat (`purchases_flutter`) | Subscription management via App Store / Google Play billing |
| HTTP client | Supabase Dart client (`supabase_flutter`) | Direct database queries, auth, realtime, storage, edge function invocation |
| Deep links | App Links (Android) + Universal Links (iOS) | Invite token handling, auth callbacks, magic link flow |
| Background work | `workmanager` | Background photo upload sync, offline queue processing |
| Connectivity | `connectivity_plus` | Network state detection for sync triggers |

### 1.2 Backend Services

| Layer | Technology | Purpose |
|---|---|---|
| Database and auth | Supabase (PostgreSQL 17) with `supabase_flutter` | Database, authentication, real-time subscriptions, Row Level Security |
| Server-side logic | Supabase Edge Functions (Deno) | Webhook handlers, photo processing, presigned URLs, cron triggers, server-side Broadcast |
| Object storage | Cloudflare R2 | Photo and file storage (EXIF-stripped images, data exports). Zero egress fees. |
| Payments (server) | Stripe (webhook-driven) | Server-side subscription lifecycle management via Edge Functions |
| Payments (client) | RevenueCat | Client-side subscription purchase via native App Store / Google Play billing |
| Weather API | Met Office DataHub or OpenWeatherMap | Automated weather data for catch reports |
| Moon phase | Calculated in Dart | Lunar phase computation from date (no external API needed) |
| AI layer | Anthropic Claude API (via Inngest or QStash fan-out) | Background intelligence processing for each group |
| Email | Resend | Transactional emails (invitations, succession alerts, export links) |
| EXIF stripping | Inngest background job (Node.js + sharp) | Strip all EXIF/GPS/XMP/IPTC metadata from photos before permanent R2 storage. **Sharp has native C bindings incompatible with Deno — must run in Node.js, not Edge Functions.** |
| Rate limiting | Supabase Edge Function middleware + Upstash Redis | Rate limiting on auth, upload, invite redemption |
| Input validation | Zod (Edge Functions) + Dart model validation | Schema validation on all inputs |
| Background jobs | Inngest (or Upstash QStash) | Fan-out AI processing, async data exports, admin succession checks |
| Push delivery | Supabase Edge Function → FCM HTTP v1 API | Server-side push notification dispatch via OAuth2 service account credentials |

### 1.3 Marketing Website

| Layer | Technology | Purpose |
|---|---|---|
| Framework | Next.js (static export) or Astro | SEO landing page, invite landing, app store links |
| Hosting | Cloudflare Pages (free tier) or Vercel (free tier) | Static site hosting, edge delivery |
| Pages | Landing (`/`), Invite landing (`/invite/[token]`), Privacy, Terms | Public-facing web presence (5 pages maximum) |

The marketing site is intentionally minimal. Its only role is SEO, the invite token landing flow (which redirects to the mobile app via deep link or to the app store), and legal pages. No authenticated functionality lives on the web.

---

## 2. Database Schema

All tables live in the Supabase PostgreSQL database. Row Level Security (RLS) policies enforce data isolation between groups. Every table that contains group-scoped data must have RLS enabled with policies that restrict access to active members of that group with an active subscription.

**Soft deletes:** Tables where data may need recovery (messages, catch_reports) include a `deleted_at` column with partial indexes scoped to `WHERE deleted_at IS NULL`. RLS policies automatically filter deleted rows.

### 2.0 UUID v7 Implementation

All primary keys use UUID v7 (time-ordered) via `uuid_generate_v7()` instead of `gen_random_uuid()`. UUID v7 provides time-ordered insertion which eliminates B-tree page splits, reduces index fragmentation by ~26%, and provides 4x faster point lookups at scale compared to random UUID v4.

**The `pg_uuidv7` extension is NOT available on Supabase hosted instances.** Supabase is currently on PostgreSQL 17. Native `uuidv7()` is only available in PostgreSQL 18, which Supabase has not yet adopted. The following pure SQL function must be created as the **first migration** before any table creation:

```sql
-- Migration: 00001_uuid_v7_function.sql
-- Creates a drop-in uuid_generate_v7() function for Supabase (PostgreSQL 17)
-- Replace with native uuidv7() when Supabase upgrades to PostgreSQL 18
-- RFC 9562 compliant. Performance is comparable to gen_random_uuid().

CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS uuid
AS $$
DECLARE
  timestamp bytea;
  output bytea;
BEGIN
  -- Get milliseconds since epoch (48-bit big-endian)
  timestamp := substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3);

  -- Take random bytes from built-in v4 generator
  output := uuid_send(gen_random_uuid());

  -- Overlay timestamp into first 6 bytes
  output := overlay(output placing timestamp from 1 for 6);

  -- Set version bits to 0111 (v7)
  output := set_byte(output, 6, (get_byte(output, 6) & 15) | 112);

  -- Set variant bits to 10 (RFC 4122/9562)
  output := set_byte(output, 8, (get_byte(output, 8) & 63) | 128);

  RETURN output::uuid;
END;
$$ LANGUAGE plpgsql VOLATILE;
```

**Migration path:** When Supabase upgrades to PostgreSQL 18, run:
```sql
DROP FUNCTION IF EXISTS uuid_generate_v7();
-- Native uuidv7() is now available. Update all DEFAULT clauses:
-- ALTER TABLE groups ALTER COLUMN id SET DEFAULT uuidv7();
-- (repeat for all tables)
```

### 2.1 users

Extends Supabase `auth.users`. This table stores profile and subscription data.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, references auth.users(id) | User ID from Supabase Auth |
| email | text | NOT NULL, UNIQUE | User email address |
| full_name | text | NOT NULL | Display name |
| avatar_url | text | NULLABLE | Profile photo URL (Cloudflare R2) |
| location | text | NULLABLE | Optional location (e.g. "Essex") |
| stripe_customer_id | text | NULLABLE, UNIQUE | Stripe customer ID (mapped from RevenueCat). **The UNIQUE constraint implicitly creates a B-tree index**, required for webhook handler lookups. |
| subscription_status | text | NOT NULL, DEFAULT 'inactive' | One of: active, past_due, cancelled, inactive |
| subscription_period_end | timestamptz | NULLABLE | When current billing period ends |
| subscription_grace_until | timestamptz | NULLABLE | 3 days past period_end for past_due tolerance |
| fcm_token | — | — | **Moved to `user_devices` table (Section 2.17)** to support multi-device push notifications. |
| platform | — | — | **Moved to `user_devices` table (Section 2.17).** |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Account creation date |
| updated_at | timestamptz | NOT NULL, DEFAULT now() | Last profile update |

### 2.2 stripe_events

Idempotency tracking for Stripe/RevenueCat webhook processing.

| Column | Type | Constraints | Description |
|---|---|---|---|
| event_id | text | PK | Webhook event ID (RevenueCat event ID or Stripe event ID) |
| event_type | text | NOT NULL | Event type (e.g. INITIAL_PURCHASE, RENEWAL, CANCELLATION) |
| processed_at | timestamptz | NOT NULL, DEFAULT now() | When this event was processed |

Unique constraint on event_id ensures each webhook event is processed exactly once. Before processing any webhook, check for existing record. If found, return 200 immediately (idempotent no-op).

**Retention policy:** Prune records older than 90 days via the daily cron job. This keeps the table and its primary key index lean.

### 2.3 groups

Each group is a private repository container.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Group ID |
| name | text | NOT NULL | Group display name |
| rule_set_id | uuid | NOT NULL, FK → rule_sets(id) | Selected standard rule set |
| created_by | uuid | NOT NULL, FK → users(id) | Creator (first admin) |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Creation date |
| member_count | integer | NOT NULL, DEFAULT 1 | Denormalised member count, maintained by trigger |

The `member_count` is maintained by a database trigger on `group_memberships` INSERT and DELETE. See Section 2.4.1 for the membership lifecycle that governs this trigger. A periodic reconciliation query via `pg_cron` (daily) corrects any drift.

### 2.4 group_memberships

Links users to groups with role information.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Membership ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group reference |
| user_id | uuid | NOT NULL, FK → users(id) | Member reference |
| role | text | NOT NULL, DEFAULT 'member' | One of: admin, member |
| successor_user_id | uuid | NULLABLE, FK → users(id) | Admin succession nominee (admins only) |
| joined_at | timestamptz | NOT NULL, DEFAULT now() | When member joined |
| UNIQUE | | (group_id, user_id) | One membership per user per group |

#### 2.4.1 Membership Lifecycle

Membership uses **hard deletes, not soft deletes**. There is no `status` column on `group_memberships`. The lifecycle is:

1. **Join:** INSERT into `group_memberships` → trigger increments `groups.member_count`
2. **Leave voluntarily:** Within a single transaction: INSERT audit record into `removed_members` (reason: 'left_voluntarily'), then DELETE from `group_memberships` → trigger decrements `groups.member_count`
3. **Removed by admin:** Within a single transaction: INSERT audit record into `removed_members` (reason: 'removed', removed_by set), then DELETE from `group_memberships` → trigger decrements `groups.member_count`. **Must call `supabase.auth.admin.signOut(userId)` to immediately invalidate the removed user's sessions** (see Section 5.3.1).

Because membership removal is always a hard DELETE, the `member_count` trigger only needs INSERT and DELETE handlers — no UPDATE handling is required. The `removed_members` table (Section 2.15) serves as the audit trail and controls the 30-day data export window.

### 2.5 invitations

Tracks pending invitations to groups.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Invitation ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group being invited to |
| invited_by | uuid | NOT NULL, FK → users(id) | Admin who sent the invitation |
| invite_token | text | NOT NULL, UNIQUE | **128-bit token generated via `crypto.randomBytes(16)` encoded as base64url.** Must be cryptographically random, 22+ characters. Short or sequential tokens are brute-forceable. |
| invited_email | text | NULLABLE | Email address if sent to specific person |
| status | text | NOT NULL, DEFAULT 'pending' | One of: pending, accepted, expired, revoked |
| created_at | timestamptz | NOT NULL, DEFAULT now() | When invitation was created |
| expires_at | timestamptz | NOT NULL | Expiry date (14 days from creation) |

### 2.6 rule_sets

Pre-defined rule templates that groups select at creation.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Rule set ID |
| name | text | NOT NULL | Display name (e.g. "Standard", "Syndicate", "Strict Privacy") |
| description | text | NOT NULL | Human-readable summary of what this rule set entails |
| rules | jsonb | NOT NULL | Structured rule definitions (see Section 2.6.1) |
| is_active | boolean | NOT NULL, DEFAULT true | Whether this rule set is available for new groups |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Creation date |

#### 2.6.1 rules JSONB Structure

```json
{
  "invitation_policy": "admin_only | group_vote",
  "location_detail": "venue_only | venue_and_swim",
  "photo_backgrounds": "allowed | restricted",
  "external_sharing": "prohibited | with_permission",
  "named_fish_logging": "enabled | disabled",
  "removal_vote_required": false,
  "max_members": 20
}
```

No GIN index on the rules JSONB column. The rule_sets table is tiny (fewer than 20 rows) and only read at group creation.

### 2.7 catch_reports

The core data table — structured catch records within a group repository.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Catch report ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group repository this belongs to |
| user_id | uuid | NOT NULL, FK → users(id) | Member who logged this catch |
| venue_id | uuid | NOT NULL, FK → venues(id) | Venue reference. **No ON DELETE CASCADE** — venues must not be deleted if catch reports reference them. See Section 2.9. |
| fish_species | text | NOT NULL | One of: common, mirror, leather, ghost, fully_scaled, grass |
| fish_weight_lb | integer | NOT NULL | Weight in whole pounds |
| fish_weight_oz | integer | NOT NULL, CHECK (fish_weight_oz >= 0 AND fish_weight_oz <= 15) | Weight in remaining ounces |
| fish_name | text | NULLABLE | Named fish identifier if known |
| swim | text | NULLABLE | Swim number or name |
| casting_distance_wraps | integer | NULLABLE | Casting distance in wraps |
| bait_type | text | NULLABLE | E.g. pop-up, bottom bait, wafter, pellet, tiger nut |
| bait_brand | text | NULLABLE | E.g. Mainline, Sticky Baits, Nash |
| bait_product | text | NULLABLE | E.g. Cell, Krill, Pacific Tuna |
| bait_size_mm | integer | NULLABLE | Boilie/pellet size in mm |
| bait_colour | text | NULLABLE | Bait colour |
| rig_name | text | NULLABLE | E.g. Ronnie, chod, German, blowback, zig |
| hook_size | integer | NULLABLE | Hook size number |
| hooklink_material | text | NULLABLE | E.g. fluorocarbon, braid, coated braid |
| hooklink_length_inches | integer | NULLABLE | Hooklink length |
| lead_arrangement | text | NULLABLE | E.g. inline, helicopter, chod |
| air_pressure_mb | numeric(6,1) | NULLABLE | Air pressure at time of catch (auto-populated) |
| wind_direction | text | NULLABLE | Wind direction (auto-populated) |
| wind_speed_mph | integer | NULLABLE | Wind speed (auto-populated) |
| air_temp_c | numeric(4,1) | NULLABLE | Air temperature (auto-populated) |
| water_temp_c | numeric(4,1) | NULLABLE | Water temperature (manual entry) |
| cloud_cover | text | NULLABLE | Cloud cover description |
| rain | text | NULLABLE | Rain description |
| moon_phase | text | NULLABLE | Moon phase (auto-calculated in Dart) |
| caught_at | timestamptz | NOT NULL | Date and time of catch |
| notes | text | NULLABLE | Free text notes |
| deleted_at | timestamptz | NULLABLE | Soft delete timestamp (NULL = active) |
| created_at | timestamptz | NOT NULL, DEFAULT now() | When report was logged |
| updated_at | timestamptz | NOT NULL, DEFAULT now() | Last edit |

### 2.8 catch_report_photos

Photos attached to catch reports.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Photo ID |
| catch_report_id | uuid | NOT NULL, FK → catch_reports(id) ON DELETE CASCADE | Parent catch report |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group reference (for RLS) |
| storage_key | text | NOT NULL | Cloudflare R2 object key |
| url | text | NOT NULL | Signed URL or public URL for the image |
| width | integer | NULLABLE | Image width in pixels |
| height | integer | NULLABLE | Image height in pixels |
| display_order | integer | NOT NULL, DEFAULT 0 | Ordering within the catch report |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Upload date |

### 2.9 venues

Shared venue reference table. Venues are not group-scoped — the same venue can be referenced by multiple groups. However, venue_notes (Section 2.10) are group-scoped.

**Venues must never be deleted once referenced by catch reports or sessions.** The foreign keys from `catch_reports.venue_id` and `sessions.venue_id` intentionally omit ON DELETE CASCADE. Attempting to delete a referenced venue will fail with a foreign key violation. If a venue needs to be "retired", add an `is_active` flag in a future migration rather than deleting the record.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Venue ID |
| name | text | NOT NULL | Venue name |
| location_lat | numeric(10,7) | NULLABLE | Latitude |
| location_lng | numeric(10,7) | NULLABLE | Longitude |
| county | text | NULLABLE | County |
| country | text | NOT NULL, DEFAULT 'UK' | Country |
| venue_type | text | NULLABLE | One of: day_ticket, syndicate, club, free |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Creation date |
| UNIQUE | | (name, location_lat, location_lng) | Prevent duplicates |

### 2.10 venue_notes

Group-specific collaborative notes for each venue.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Venue note ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group repository |
| venue_id | uuid | NOT NULL, FK → venues(id) | Venue reference |
| content | jsonb | NOT NULL | Structured note content (rich text as JSON) |
| ai_populated_content | jsonb | NULLABLE | AI-sourced baseline content (displayed separately/below group notes) |
| last_edited_by | uuid | NULLABLE, FK → users(id) | Last human editor |
| last_ai_update | timestamptz | NULLABLE | Last AI enrichment |
| version | integer | NOT NULL, DEFAULT 1 | Optimistic concurrency version counter |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Creation date |
| updated_at | timestamptz | NOT NULL, DEFAULT now() | Last update |
| UNIQUE | | (group_id, venue_id) | One note document per venue per group |

The `version` column enables optimistic locking for concurrent venue note editing. UPDATE queries must include `WHERE version = {expected_version}`. If no rows are affected, the client must re-fetch and retry.

### 2.11 sessions

Planned fishing sessions within a group.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Session ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group reference |
| created_by | uuid | NOT NULL, FK → users(id) | Session creator |
| venue_id | uuid | NOT NULL, FK → venues(id) | Venue. **No ON DELETE CASCADE** — see Section 2.9. |
| title | text | NULLABLE | Optional session title |
| starts_at | timestamptz | NOT NULL | Session start date/time |
| ends_at | timestamptz | NULLABLE | Session end date/time |
| duration_type | text | NULLABLE | E.g. day_session, overnighter, 48_hour, weekend |
| notes | text | NULLABLE | Session planning notes |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Creation date |

### 2.12 session_attendees

Members attending a planned session.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Attendee record ID |
| session_id | uuid | NOT NULL, FK → sessions(id) ON DELETE CASCADE | Session reference |
| user_id | uuid | NOT NULL, FK → users(id) | Attending member |
| status | text | NOT NULL, DEFAULT 'going' | One of: going, maybe, declined |
| preferred_swim | text | NULLABLE | Swim preference |
| created_at | timestamptz | NOT NULL, DEFAULT now() | When they responded |
| UNIQUE | | (session_id, user_id) | One response per member per session |

### 2.13 messages

Real-time group messages.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Message ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group reference |
| user_id | uuid | NOT NULL, FK → users(id) | Sender |
| content | text | NOT NULL | Message text |
| reply_to_id | uuid | NULLABLE, FK → messages(id) | Thread reply reference |
| deleted_at | timestamptz | NULLABLE | Soft delete timestamp (NULL = active) |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Send time |

### 2.14 ai_intelligence_items

AI-generated insights and briefings stored per group.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Item ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group reference |
| category | text | NOT NULL | One of: pattern, venue, briefing, product |
| title | text | NOT NULL | Display title |
| highlight | text | NOT NULL | One-line key takeaway |
| content | text | NOT NULL | Full analysis text |
| related_venue_id | uuid | NULLABLE, FK → venues(id) | Related venue if applicable |
| related_session_id | uuid | NULLABLE, FK → sessions(id) | Related session if applicable |
| metadata | jsonb | NULLABLE | Additional structured data (charts, stats) |
| created_at | timestamptz | NOT NULL, DEFAULT now() | When AI generated this |

### 2.15 removed_members

Tracks removed or departed members and their export window.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Record ID |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group reference |
| user_id | uuid | NOT NULL, FK → users(id) | Removed member |
| removed_by | uuid | NULLABLE, FK → users(id) | Admin who removed them (NULL if voluntary) |
| reason | text | NOT NULL | One of: removed, left_voluntarily |
| export_available_until | timestamptz | NOT NULL | 30 days from removal date |
| export_downloaded | boolean | NOT NULL, DEFAULT false | Whether they downloaded their data |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Removal date |

### 2.16 exports

Tracks asynchronous data export jobs.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Export ID |
| user_id | uuid | NOT NULL, FK → users(id) | Requesting user |
| group_id | uuid | NOT NULL, FK → groups(id) ON DELETE CASCADE | Group being exported |
| status | text | NOT NULL, DEFAULT 'pending' | One of: pending, processing, complete, failed |
| download_url | text | NULLABLE | Signed R2 URL when complete |
| error_message | text | NULLABLE | Error details if failed |
| expires_at | timestamptz | NULLABLE | When the download URL expires (24 hours from completion) |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Request time |
| completed_at | timestamptz | NULLABLE | Completion time |

RLS: SELECT only where `user_id = (SELECT auth.uid())`.

### 2.17 user_devices

Tracks FCM push notification tokens per device. Supports multi-device push delivery (e.g. phone and tablet).

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, DEFAULT uuid_generate_v7() | Device record ID |
| user_id | uuid | NOT NULL, FK → users(id) ON DELETE CASCADE | User reference |
| fcm_token | text | NOT NULL, UNIQUE | FCM device token. UNIQUE prevents duplicate registrations. |
| platform | text | NOT NULL | One of: ios, android |
| last_active_at | timestamptz | NOT NULL, DEFAULT now() | Last token refresh. Updated on each app launch. |

RLS: SELECT, INSERT, UPDATE, DELETE only where `user_id = (SELECT auth.uid())`.

On each app launch, the app upserts the current FCM token (insert or update `last_active_at`). The `push-send` Edge Function queries all tokens for the target user(s). A cron job prunes tokens not refreshed in 60+ days (stale devices).

### 2.18 Required Indexes

The following indexes are critical for RLS policy performance and query speed. Without these, RLS policies cause sequential full-table scans.

```sql
-- RLS-critical indexes (without these, RLS causes full table scans)
CREATE INDEX idx_group_memberships_user_id ON group_memberships (user_id);
CREATE INDEX idx_group_memberships_group_user ON group_memberships (group_id, user_id);

-- Feed and timeline ordering
CREATE INDEX idx_messages_group_created ON messages (group_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_catch_reports_group_created ON catch_reports (group_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_ai_intel_group_created ON ai_intelligence_items (group_id, created_at DESC);
CREATE INDEX idx_ai_intel_group_cat_created ON ai_intelligence_items (group_id, category, created_at DESC);

-- Foreign key indexes (every FK column must be indexed for join performance)
CREATE INDEX idx_catch_reports_user ON catch_reports (user_id);
CREATE INDEX idx_catch_reports_venue ON catch_reports (venue_id);
CREATE INDEX idx_messages_user ON messages (user_id);
CREATE INDEX idx_catch_report_photos_report ON catch_report_photos (catch_report_id);
CREATE INDEX idx_catch_report_photos_group ON catch_report_photos (group_id);
CREATE INDEX idx_sessions_group ON sessions (group_id);
CREATE INDEX idx_session_attendees_session ON session_attendees (session_id);
CREATE INDEX idx_invitations_group ON invitations (group_id);
CREATE INDEX idx_exports_user ON exports (user_id);

-- Invitation token lookup (single-use, active only)
CREATE UNIQUE INDEX idx_invitations_token_active ON invitations (invite_token) WHERE status = 'pending';

-- Repository search and filtering
CREATE INDEX idx_catch_reports_group_venue ON catch_reports (group_id, venue_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_catch_reports_group_bait ON catch_reports (group_id, bait_brand) WHERE deleted_at IS NULL;

-- Push notification token lookup (multi-device)
CREATE INDEX idx_user_devices_user ON user_devices (user_id);
CREATE INDEX idx_user_devices_stale ON user_devices (last_active_at) WHERE last_active_at < now() - interval '60 days';
```

**Note:** `users.stripe_customer_id` has a UNIQUE constraint which implicitly creates a B-tree index. This index is required for webhook handler lookups. `user_devices.fcm_token` has a UNIQUE constraint which implicitly creates a B-tree index for token deduplication.

Do NOT add GIN indexes on JSONB columns (rules, metadata, content) at this stage. GIN indexes have significant write overhead and are only beneficial for large tables with frequent containment (`@>`) queries.

---

## 3. Row Level Security Policies

RLS is the primary security boundary for Carp.Network. Even if application code has a bug that omits a group_id filter, the database must reject the query via RLS policy.

### 3.1 Core RLS Pattern — Set-Based Policies

**CRITICAL: Do NOT use a helper function that accepts `group_id` as a parameter.** A function like `is_active_group_member(group_id)` creates a correlated subquery that executes per row, causing N+1 performance degradation.

Instead, use **set-based policies** that query the user's group memberships once per statement:

```sql
-- CORRECT: Set-based pattern — runs once, returns set of group_ids
CREATE POLICY "Members can view group catches"
  ON catch_reports FOR SELECT
  TO authenticated
  USING (
    group_id IN (
      SELECT gm.group_id FROM group_memberships gm
      WHERE gm.user_id = (SELECT auth.uid())
    )
    AND deleted_at IS NULL
  );
```

**Key performance rules:**

1. **Always wrap `auth.uid()` in `(SELECT auth.uid())`** — this triggers PostgreSQL's initPlan optimizer, caching the result per-statement instead of evaluating per-row. Measured improvement: 57–61%.
2. **Always specify `TO authenticated`** on all policies — this short-circuits evaluation for the anon role.
3. **Every column referenced in a USING clause must have a B-tree index** — the indexes in Section 2.18 cover all RLS-referenced columns.
4. **Never check subscription status in RLS policies** — this adds a cross-table join to every single query. Instead, enforce subscription status in the application layer using the JWT custom claims (see Section 5.3).

### 3.2 Security Definer Helper Function

For policies that need multi-table lookups, create a SECURITY DEFINER function in a **non-exposed schema**:

```sql
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.user_group_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT gm.group_id
  FROM public.group_memberships gm
  WHERE gm.user_id = (SELECT auth.uid())
$$;
```

**CRITICAL:** The function must be in a non-public schema. Functions in the `public` schema are callable via Supabase's RPC endpoint — a SECURITY DEFINER function accepting arbitrary parameters would allow any authenticated user to enumerate group memberships.

### 3.3 Policies by Table

**group_memberships:** SELECT where `group_id IN (SELECT private.user_group_ids())`. INSERT restricted to admins via application logic (checked server-side, not in RLS). DELETE by admins only for non-admin members.

**catch_reports:** SELECT, INSERT for active group members. UPDATE, DELETE only where `user_id = (SELECT auth.uid())`. All SELECT/UPDATE/DELETE policies include `AND deleted_at IS NULL`.

**catch_report_photos:** Same as catch_reports — scoped to group membership via `group_id IN (SELECT private.user_group_ids())`, write limited to the uploader.

**venue_notes:** SELECT, UPDATE for active group members. INSERT limited to group members. UPDATE must include `WITH CHECK` clause ensuring `group_id` cannot be changed.

**sessions:** SELECT, INSERT for active group members. UPDATE, DELETE by session creator only.

**session_attendees:** SELECT for active group members. INSERT, UPDATE, DELETE for the attending user only (`user_id = (SELECT auth.uid())`).

**messages:** SELECT, INSERT for active group members. SELECT includes `WHERE deleted_at IS NULL`. No UPDATE allowed. Soft-delete (setting deleted_at) by message author only.

**ai_intelligence_items:** SELECT for active group members. INSERT restricted to service role only (AI background job — bypasses RLS). No UPDATE or DELETE by users.

**removed_members:** SELECT only where `user_id = (SELECT auth.uid())`. INSERT restricted to application logic.

**exports:** SELECT only where `user_id = (SELECT auth.uid())`. INSERT via application logic. UPDATE restricted to service role.

### 3.4 RLS Safety Checklist

- Every group-scoped table has RLS enabled
- No table has a permissive `USING (true)` policy
- All UPDATE policies include a `WITH CHECK` clause preventing group_id/user_id modification
- Views use `security_invoker = true` (PostgreSQL 15+)
- RLS policies never reference `user_metadata` — use `app_metadata` if custom claims needed
- Testing is done via the client SDK, not the SQL Editor (SQL Editor runs as superuser, bypassing all RLS)

---

## 4. Cloudflare R2 Storage

### 4.1 Bucket Structure

```
carp-network-media/
  photos/
    {group_id}/
      {catch_report_id}/
        {uuid_filename}.jpg     ← UUID-renamed, never original filename
  avatars/
    {user_id}.jpg
  exports/
    {user_id}/
      {export_id}.zip
```

All uploaded files are renamed to UUID-based filenames to prevent path traversal attacks.

### 4.2 Photo Upload Pipeline — Offline-Aware Presigned URL Pattern

**Architecture: Client-side capture and resize, background upload, server-side EXIF verification.**

The angler is on a bank, often with poor connectivity. The upload pipeline must be resilient to intermittent signal and work seamlessly when offline.

**Upload flow:**

1. User captures photo via `image_picker` (camera or gallery)
2. **Client-side preprocessing (immediate, before any network):**
   - Resize to max 2048px on longest edge using the `image` package
   - **Run in a separate isolate** to avoid UI jank — image decoding and resizing are CPU-intensive:
     ```dart
     final resizedBytes = await Isolate.run(() {
       final image = img.decodeImage(rawBytes)!;
       final resized = img.copyResize(image, width: 2048);
       return img.encodeJpg(resized, quality: 85);
     });
     ```
   - Save processed image to app-local storage (temp directory)
   - Create a local `PendingUpload` record in the Drift/Brick local database with status: `pending`
3. **If online** — proceed immediately to step 4. **If offline** — the `PendingUpload` record persists. The `workmanager` background task retries when connectivity resumes (see Section 4.2.1).
4. App calls the `photos-presign` Edge Function with catch_report_id, group_id, file_type, file_size
5. Edge Function validates auth, group membership, file size (<4MB), and generates:
   - A presigned PutObject URL for R2 (5-minute expiry)
   - A unique R2 key (UUID-based)
   - **Stores the issued R2 key in Upstash Redis** with a 10-minute TTL, keyed by `presign:{user_id}:{r2_key}`
6. App uploads the resized image directly to R2 via the presigned URL
7. App calls the `photos-confirm` Edge Function with the R2 key
8. **Edge Function validates the R2 key** against the Redis presign record. Rejects if no matching record exists.
9. Edge Function dispatches an **Inngest background job** (`photo-process`) with the R2 key, catch_report_id, and group_id. Returns 202 (accepted) to the app immediately. **Sharp has native C bindings (libvips) that are incompatible with Deno — EXIF stripping must run in a Node.js environment, not in Edge Functions.**
10. The Inngest `photo-process` job (Node.js runtime) downloads the uploaded file from R2. **On download, captures the `ETag` header** for later verification.
11. Processes the downloaded file with sharp:
    - `sharp(buffer).rotate()` — **must call `.rotate()` first** to physically apply EXIF orientation before stripping
    - Strip all EXIF, XMP, IPTC, GPS data, and embedded thumbnails
    - Keep ICC colour profile only (`.keepIccProfile()`) — contains no personal data
    - Re-encode to JPEG at 85% quality
    - **Client-side EXIF stripping is NOT trusted** — the server performs authoritative stripping regardless
12. Upload the processed image back to R2, replacing the original. **Verify the ETag captured in step 10 has not changed before overwriting.**
13. **Verify** the processed image has no metadata: `sharp(processedBuffer).metadata()` confirms `.exif`, `.xmp`, `.iptc` are all undefined
14. Delete the Redis presign record
15. Create the `catch_report_photos` database record with the R2 key and URL
16. Send a Broadcast event to the group channel so connected clients update the photo placeholder to the final image

#### 4.2.1 Background Upload Queue

**Android:** The `workmanager` package runs periodic background tasks (minimum 15-minute interval). Register a periodic task with `networkType: NetworkType.connected` constraint so Android only triggers it when online.

**iOS: `workmanager` maps to `BGTaskScheduler` which gives iOS full discretion over scheduling.** Background tasks may not run for hours, and periodic tasks (as supported on Android) are not available via `workmanager` on iOS. iOS may also terminate tasks after approximately 30 seconds of execution.

**iOS fallback — silent push notifications:** When an offline catch report syncs to Supabase (via Brick), a database trigger or webhook fires the `push-silent-upload` Edge Function. This sends a silent push (`content-available: 1`) back to the originating device. iOS wakes the app for approximately 30 seconds on receipt — sufficient to upload one pre-resized photo (~200KB–1MB). For catches with multiple photos, the app uploads one photo per silent push wake cycle, with the server sending subsequent silent pushes until all pending uploads for that device are complete.

**Upload task design — small and idempotent:**
- Process **one photo per task invocation** (not a batch)
- Each task is resumable on interruption — if killed mid-upload, the next invocation retries the same photo
- On failure (network error, timeout), increment retry counter. After 5 failures, set status to `failed` and show error in-app
- On success, update status to `complete` and clean up temp file

**Test on real iOS devices** — the iOS simulator does not accurately reproduce BGTaskScheduler behaviour. Use Xcode's `Simulate Background Fetch` for initial testing, but validate scheduling patterns on physical hardware.

**Critical:** The catch report itself is synced to Supabase immediately (or queued via Brick if offline). Photos are uploaded separately. The user sees their catch report in the feed immediately — photo slots show an "Uploading..." placeholder until the upload completes.

**R2 CORS configuration** must be set via Wrangler CLI:

```json
{
  "AllowedOrigins": ["*"],
  "AllowedMethods": ["GET", "PUT"],
  "AllowedHeaders": ["Content-Type"],
  "MaxAgeSeconds": 3600
}
```

Note: R2 CORS for mobile apps requires `"*"` origin since mobile HTTP clients do not send an Origin header. Security is enforced via the presigned URL expiry and Redis key validation, not CORS.

### 4.3 Data Export Pipeline — Async via Background Job

**Data exports must NOT be generated synchronously.** Large exports with photos will exceed function timeout and memory limits.

1. User requests data export in-app
2. App calls the `export-request` Edge Function
3. Edge Function creates an `exports` record (status: pending) and dispatches an async background job via Inngest/QStash
4. Background job queries all catch_reports, catch_report_photos where user_id = requesting user AND group_id = specified group
5. Compile catch reports as JSON/CSV
6. Stream photos from R2 and package into ZIP using streaming archiver (constant memory)
7. Upload ZIP to R2 in the exports/ prefix
8. Generate a signed URL with 24-hour expiry
9. Update the `exports` record with status: complete, download_url, expires_at, completed_at
10. Send push notification to user's device and email via Resend

### 4.4 Image Delivery Optimisation

For the Photo Library grid view, serving full 2048px images for thumbnail cards wastes bandwidth. Implement delivery optimisation via Cloudflare:

- **Option A (recommended): Cloudflare Image Resizing** — If using a Cloudflare-proxied custom domain for R2, enable Image Resizing. Construct URLs like `https://media.carp.network/cdn-cgi/image/width=400,quality=80/{r2_key}`. Cloudflare resizes on the edge, caches the result.
- **Option B: Cloudflare Worker** — Deploy a lightweight Worker in front of R2 that accepts `width` and `quality` query parameters, resizes via the `cf.image` binding.

The Flutter app uses `CachedNetworkImage` with thumbnail URLs for grid views and full-resolution URLs for detail views.

**Image cache performance:**
- Set `memCacheHeight` and `memCacheWidth` on grid thumbnails to match display pixel dimensions (e.g. 400px). This prevents Flutter from decoding full-resolution images into GPU memory for thumbnail display.
- Use `fadeInDuration: Duration.zero` for grid thumbnails to avoid animation overhead during fast scrolling.
- Configure `DefaultCacheManager` with a max disk cache size of 200MB to prevent unbounded disk usage on devices with limited storage.
- For the Photo Library screen (potentially hundreds of images), use `SliverGrid` with `addAutomaticKeepAlives: false` to allow off-screen images to be garbage collected.

---

## 5. Authentication and Subscription Flow

### 5.1 Authentication

Use Supabase Auth with email + password or magic link via `supabase_flutter`. No social logins at launch.

**Supabase client initialisation:**

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  authOptions: FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce, // PKCE is more secure for mobile
    localStorage: SecureLocalStorage(), // Override default SharedPreferences
  ),
);
```

**CRITICAL security rules for Flutter:**
- **Never embed the service role key in the mobile app.** The anon key is the only key that ships in the binary. Service role operations happen exclusively in Edge Functions.
- **Use `flutter_secure_storage` to override the default session persistence.** The default `supabase_flutter` storage uses `SharedPreferences` which is plaintext on some Android OEMs. Pass a custom `LocalStorage` implementation backed by Keychain (iOS) / Keystore (Android):

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

- **PKCE flow is mandatory** for all auth flows involving deep links (magic link, OAuth). PKCE prevents authorization code interception attacks on mobile.

**Auth state management with Riverpod:**

```dart
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
```

GoRouter uses `authStateProvider` to redirect unauthenticated users to the login screen and handle deep link callbacks for magic links and invite tokens.

**Deep link configuration:**
- **Android:** App Links with `https://carp.network/.well-known/assetlinks.json` served from the marketing site
- **iOS:** Universal Links with `https://carp.network/.well-known/apple-app-site-association` served from the marketing site
- **Scheme:** `carp://` as fallback for development
- **Paths:** `carp.network/invite/{token}` (invite flow), `carp.network/auth/callback` (magic link)

Registration flow:
1. User receives invitation link (via email, SMS, or shared in person)
2. Tapping the link opens the app via deep link (or redirects to app store if not installed)
3. App extracts the invite_token from the deep link
4. If not authenticated, app shows registration screen
5. On registration, Supabase creates the auth.users record
6. App creates the users record with subscription_status = 'inactive'
7. App presents the RevenueCat paywall for subscription purchase (see Section 5.2)
8. On successful purchase, RevenueCat webhook fires → Edge Function updates subscription_status
9. App creates the group_memberships record for the invited group
10. Invitation status is updated to 'accepted'

### 5.2 Subscription Management — RevenueCat

**Product:** Carp.Network Membership — £4.99/month recurring via App Store / Google Play.

**Why RevenueCat instead of direct Stripe:** Mobile app subscriptions must go through the platform's native billing (Apple/Google require this for digital content). RevenueCat abstracts both platforms into a single SDK, handles receipt validation, and provides server-side webhooks for backend state management.

**Client-side (Flutter):**

```dart
// Initialise RevenueCat
await Purchases.configure(
  PurchasesConfiguration(Platform.isIOS ? appleApiKey : googleApiKey)
    ..appUserID = supabaseUserId,
);

// Present paywall
final offerings = await Purchases.getOfferings();
// Display offering.current.monthly to user

// Purchase
final purchaserInfo = await Purchases.purchasePackage(monthlyPackage);
```

**Server-side (Edge Function webhook):**

RevenueCat sends webhook events to a Supabase Edge Function (`revenucat-webhook`). The Edge Function:

1. Verifies the webhook authorization header against a shared secret
2. Checks idempotency via the `stripe_events` table (using RevenueCat's event ID)
3. Maps RevenueCat events to subscription state changes:

| RevenueCat Event | Action |
|---|---|
| INITIAL_PURCHASE | Set subscription_status = 'active', store subscription_period_end |
| RENEWAL | Update subscription_period_end to next billing period |
| CANCELLATION | Set subscription_status = 'cancelled' (access continues until period_end) |
| BILLING_ISSUE | Set subscription_status = 'past_due', set grace_until = period_end + 3 days |
| EXPIRATION | Set subscription_status = 'inactive' |

4. Updates the Custom Access Token Hook claims (see Section 5.3)

**Grace period:** When a subscription enters 'past_due' status, set `subscription_grace_until = subscription_period_end + 3 days`. Access is maintained until `subscription_grace_until` passes. After that, status moves to 'inactive'. If the user is an admin and their status remains inactive for 30 days, the admin succession process triggers automatically.

### 5.3 Subscription Enforcement — JWT Custom Claims

**Do NOT check subscription status via database queries on every request.** This adds a round-trip to every operation.

Instead, embed subscription status in JWT custom claims via Supabase's **Custom Access Token Hook**:

1. Create a PostgreSQL function that Supabase calls when minting JWTs
2. The function adds `subscription_status` and `subscription_period_end` to the JWT's `app_metadata`
3. The Flutter app reads these claims from the local JWT with zero network overhead
4. When RevenueCat webhooks update subscription status, the next token refresh picks up the new claims

**App-level subscription check (Riverpod provider):**

The subscription provider must derive from the auth state stream so it recomputes whenever the JWT refreshes (e.g. after a RevenueCat webhook updates claims and the token is renewed):

```dart
final subscriptionProvider = Provider<SubscriptionStatus>((ref) {
  // Watch auth state to react to token refreshes
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (state) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return SubscriptionStatus.inactive;
      
      final jwt = _decodeJwt(session.accessToken);
      final status = jwt['app_metadata']?['subscription_status'];
      final graceUntil = jwt['app_metadata']?['subscription_grace_until'];
      
      if (status == 'active') return SubscriptionStatus.active;
      if (status == 'past_due' && _isBeforeNow(graceUntil)) {
        return SubscriptionStatus.pastDue;
      }
      return SubscriptionStatus.inactive;
    },
    loading: () => SubscriptionStatus.active, // Assume active during refresh
    error: (_, __) => SubscriptionStatus.inactive,
  );
});
```

GoRouter guards use this provider to redirect inactive users to the paywall screen.

#### 5.3.1 JWT Staleness Window

Supabase access tokens have a configurable expiry (default: 1 hour). After a webhook updates `subscription_status` to 'cancelled', the user's existing JWT still contains 'active' claims until it expires. During this staleness window (up to 1 hour), the user retains full access.

**This is an accepted trade-off** for this application's scale (small angler groups, not financial transactions).

**Exception — member removal:** Member removal is a deliberate security action. A removed admin with a stale JWT could take destructive actions during the staleness window. The member removal Edge Function **must** call `supabase.auth.admin.signOut(userId)` immediately to invalidate all sessions.

**Phase 3 enhancement:** Add immediate session invalidation for subscription expiration.

---

## 6. App Screens and Navigation

### 6.1 Navigation Structure

**Bottom navigation bar** (persistent, 5 tabs):

| Tab | Icon | Screen | Description |
|---|---|---|---|
| Dashboard | Home | Group list | User's groups as cards. Create Group button. |
| Feed | Activity | Group feed | Unified timeline (requires group selection) |
| Log Catch | Camera (FAB) | Catch form | Floating action button, prominent. Opens catch logging form. |
| Repository | Database | Catch table | Searchable, filterable catch history |
| Profile | Person | User profile | Settings, stats, subscription, export |

**Stack navigation** (within tabs):

| Screen | Route | Description |
|---|---|---|
| Group list | `/dashboard` | Cards showing group name, member count, last activity |
| Create group | `/groups/new` | Group name, rule set selection |
| Group feed | `/groups/:id` | Unified feed: catch cards, messages, sessions, AI insights. Real-time via Broadcast. |
| Catch form | `/groups/:id/catches/new` | All structured fields. Camera capture. Auto-populates weather + moon phase. **Works offline.** |
| Catch detail | `/groups/:id/catches/:catchId` | Full catch report with photos, weather, conditions. Edit/delete for author. |
| Repository | `/groups/:id/repository` | Table view with search, sort, filter (species, venue, bait, date, weight, member) |
| Venue list | `/groups/:id/venues` | Cards with catch counts and last activity |
| Venue detail | `/groups/:id/venues/:venueId` | Venue notes, catch history, stats. AI content displayed separately. |
| Sessions | `/groups/:id/sessions` | Calendar view with RSVP status |
| Plan session | `/groups/:id/sessions/new` | Venue, dates, title, notes |
| Session detail | `/groups/:id/sessions/:sessionId` | Info, attendees, swim preferences, AI briefing |
| AI intelligence | `/groups/:id/intelligence` | Grid of insight cards by category |
| Members | `/groups/:id/members` | Member list. Admin actions: invite, promote, remove, succession. |
| Photo library | `/groups/:id/photos` | Grid view. Filter by venue, member, date. |
| Group stats | `/groups/:id/stats` | Top baits, best venues, species breakdown, seasonal trends, PB leaderboard |
| Group settings | `/groups/:id/settings` | Group name, rule set view, admin tools |
| User profile | `/profile` | Edit name, location, avatar. Subscription status. |
| Personal stats | `/profile/stats` | Personal PBs, total catches, favourite venues |
| Subscription | `/subscription` | RevenueCat paywall or management screen |
| Data export | `/export` | Request export, view status, download links |
| Login | `/login` | Email + password or magic link |
| Register | `/register` | Only via invite flow |
| Invite landing | `/invite/:token` | Validates token, shows group name and inviter |

### 6.2 Group Feed — Content Rendering

The group feed is a unified, reverse-chronological timeline. Each item is rendered as a card widget:

- **CatchCard:** Species colour-coded left border, weight (monospace), venue, photo thumbnails, bait summary, conditions icons. Tap to expand.
- **MessageBubble:** Sender avatar, name, content, timestamp. Reply threading. Soft-deleted messages show "[Message deleted]".
- **SessionCard:** Calendar icon, venue, date range, attendee avatars. RSVP actions inline.
- **IntelligenceCard:** Category badge, title, one-line highlight. Tap to expand full analysis.

**Real-time delivery uses Supabase Broadcast.** See Section 9.

**Feed performance:**
- Wrap complex card widgets (`CatchCard`, `IntelligenceCard`) in `RepaintBoundary` to isolate repaints — prevents a single card animation from repainting the entire list.
- Use `const` constructors on all static child widgets within cards (icons, labels, borders) to enable the framework's widget identity caching.
- For the repository table view (which may contain hundreds of rows), set `itemExtent` on `ListView.builder` for fixed-height rows to enable O(1) scroll offset calculations.
- Paginate the feed — load 20 items initially, then fetch more on scroll via `ScrollController` with a threshold trigger. Never load the full history into memory.

---

## 7. Supabase Edge Functions

Edge Functions (Deno/TypeScript) replace Vercel API routes as the server-side logic layer. They run on Supabase's global edge network with low-latency execution.

**Security model:** Edge Functions require a valid JWT in the Authorization header by default. Functions that handle external webhooks (RevenueCat, Stripe) are configured with `verify_jwt = false` in `config.toml` and implement their own signature verification.

**Input validation:** All request bodies are validated with Zod schemas using `.strict()` to prevent mass assignment attacks. Edge Functions always use the parsed Zod output, never the raw body.

**Group ID consistency check:** For all group-scoped functions, validate that any `group_id` in the request body matches the user's memberships **before** the database query executes.

### 7.1 Edge Function Inventory

| Function | Auth | Purpose |
|---|---|---|
| `photos-presign` | JWT required | Generate presigned PutObject URL for R2. Validates group membership. Stores key in Redis. |
| `photos-confirm` | JWT required | Validate R2 key against Redis. Dispatch `photo-process` Inngest job. Returns 202 accepted. |
| `photo-process` | Inngest job (Node.js) | Download from R2, strip EXIF with sharp, re-upload, create DB record, send Broadcast. **Runs in Node.js, not Deno.** |
| `revenucat-webhook` | Webhook secret | Process RevenueCat subscription events. Idempotent via stripe_events table. |
| `export-request` | JWT required | Create exports record, dispatch background job. |
| `send-message` | JWT required | Insert message, send Broadcast event, trigger push notification. |
| `invite-create` | JWT required | Generate 128-bit invite token. Admin only. Rate limited. |
| `invite-redeem` | JWT required | Validate token, create membership, update invitation status. Rate limited. |
| `member-remove` | JWT required | Remove member, create audit record, invalidate sessions. Admin only. |
| `weather-backfill` | Database webhook | Backfill weather data for catch reports synced with null weather fields. Triggered by pg_net on INSERT. |
| `push-silent-upload` | Service role | Send silent push to originating device to trigger pending photo uploads (iOS background wake). |
| `cron-ai-processing` | CRON_SECRET | Dispatch AI processing jobs for active groups via Inngest/QStash. |
| `cron-succession-check` | CRON_SECRET | Check for lapsed admins, trigger succession. Daily. |
| `cron-reconcile` | CRON_SECRET | Reconcile member_count, prune stripe_events >90 days, prune stale user_devices >60 days. Daily. |
| `push-send` | Service role | Internal function called by other functions to send FCM/APNs notifications. |

### 7.2 Cron Scheduling

Supabase supports cron scheduling via `pg_cron` (database-level) or by calling Edge Functions on a schedule via an external cron service (Inngest, QStash, or GitHub Actions).

| Schedule | Function | Description |
|---|---|---|
| Every 2–4 hours | `cron-ai-processing` | Dispatch AI jobs for active groups |
| Daily at 03:00 UTC | `cron-succession-check` | Check for lapsed admins |
| Daily at 04:00 UTC | `cron-reconcile` | Reconcile counts, prune old events, prune stale device tokens |

### 7.3 Rate Limiting

Rate limiting is enforced within Edge Functions using Upstash Redis + `@upstash/ratelimit`:

| Endpoint category | Rate limit |
|---|---|
| Auth (login, register) | 5 requests per IP per 15 minutes |
| Invitation redemption | 5 attempts per IP per 15 minutes |
| Photo upload | 10 requests per user per hour |
| Message sending | 30 requests per user per minute |
| Catch report creation | 20 requests per user per hour |

---

## 8. AI Background Processing

### 8.1 Architecture — Fan-Out Pattern

**Do NOT process all groups in a single function.** One slow Claude API call blocks the entire batch. Use a fan-out architecture:

**Recommended: Inngest** (100K free executions/month). Step functions with individual retries, throttling, and concurrency limits.

**Alternative: Upstash QStash** (~$1 per 100K requests). Publish one message per group, automatic retries and dead letter queue.

**Process:**

1. Cron triggers `cron-ai-processing` Edge Function
2. Function queries for active groups with recent activity
3. For each group, dispatches an Inngest event (or QStash message)
4. Each group processing function runs independently
5. Assembles context: recent catch reports (last 30 days), venue notes, upcoming sessions, message topic summaries
6. **Context window management:** For highly active groups, use map-reduce. Summarise messages into topic clusters first, then pass summaries alongside structured catch data to the main intelligence prompt.
7. Calls the Claude API with a system prompt defining its role as the group's intelligence analyst
8. AI response is structured JSON with categorised intelligence items
9. Each item is written to `ai_intelligence_items`
10. Venue notes `ai_populated_content` is updated if new public venue information is found
11. **Push notification** sent to group members: "New intelligence available for [Group Name]"
12. On failure, automatic retries with backoff. Failed groups do not block other groups.

### 8.2 AI System Prompt Structure

The system prompt defines Claude as the group's intelligence analyst. It receives: the group's recent catch reports with full structured data, venue notes and historical data per venue, upcoming session details, summarised message topics, and seasonal context. The prompt instructs Claude to output structured JSON with categorised intelligence items. **The system prompt must not include data from other groups.**

### 8.3 Weather Data Integration

On catch report creation, the app auto-populates weather fields:
- Call Met Office DataHub (or OpenWeatherMap) with venue coordinates and catch timestamp
- Populate: air_pressure_mb, wind_direction, wind_speed_mph, air_temp_c, cloud_cover, rain
- **Moon phase is calculated locally in Dart** from the catch date (no API needed)
- Water temperature is manual entry only
- **Offline behaviour:** If no connectivity, weather fields are left null. When the catch syncs online, the `weather-backfill` Edge Function is triggered automatically:
  - A Supabase Database Webhook fires on INSERT to `catch_reports` where `air_pressure_mb IS NULL AND caught_at IS NOT NULL`
  - Alternatively, use a PostgreSQL trigger that calls `pg_net` (Supabase's HTTP extension) to invoke the Edge Function
  - The Edge Function calls the weather API with the venue's coordinates and the catch's `caught_at` timestamp, then updates the weather fields
  - If the weather API cannot provide historical data for the catch timestamp (too far in the past), the fields remain null

### 8.4 AI Intelligence Categories

| Category | Description | Example |
|---|---|---|
| pattern | Bait, rig, condition, or swim patterns | "Bottom baits outperforming pop-ups by 3:1 in March" |
| venue | Venue-specific intelligence, swims, seasonal notes | "Swim 7 at Berners Hall — 8 of last 12 captures during SW winds" |
| briefing | Pre-session briefing combining weather forecast, venue history, recent form | "Pressure dropping through Saturday — historically your best conditions here" |
| product | Product intelligence — trending baits, rigs, tackle | "Three members switched to Krill this month with immediate results" |

---

## 9. Real-Time Messaging and Push Notifications

### 9.1 Architecture — Broadcast, Not Postgres Changes

**CRITICAL: Supabase Realtime does NOT guarantee message delivery.** Design the chat feature with the assumption that messages will be missed during disconnections.

**Use Supabase Broadcast as the notification layer, not Postgres Changes.** Postgres Changes processes changes on a single thread and triggers N reads per subscriber for RLS authorization. Broadcast sends directly to connected clients without database overhead.

**Pattern: Persist first, broadcast second, push third.**

1. App sends message content to the `send-message` Edge Function
2. Edge Function inserts message into PostgreSQL
3. After successful insert, Edge Function sends a Broadcast event to the group's channel:

```typescript
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const channel = supabase.channel(`group:${groupId}`);
await channel.send({
  type: 'broadcast',
  event: 'new_message',
  payload: {
    id: message.id,
    user_id: message.user_id,
    content: message.content,
    created_at: message.created_at,
    user_name: user.full_name,
    user_avatar: user.avatar_url,
  },
});
await supabase.removeChannel(channel);
```

4. All connected clients receive the Broadcast event and append the message locally
5. Edge Function also sends a push notification to group members who are **not** currently connected (detected via Supabase Presence)
6. If Broadcast delivery fails, the message is in the database and will appear on next fetch

### 9.2 Client Subscription (Flutter)

```dart
final channel = Supabase.instance.client.channel('group:$groupId');

channel.onBroadcast(event: 'new_message', callback: (payload) {
  // Append message to local state
  ref.read(messagesProvider(groupId).notifier).addMessage(payload);
});

await channel.subscribe();
```

**Channel cleanup — every `subscribe()` must have a corresponding `removeChannel()`.** Without cleanup, channels accumulate and waste connections against the Supabase Realtime connection limit. In Riverpod:

```dart
ref.onDispose(() async {
  await Supabase.instance.client.removeChannel(channel);
});
```

If using a `StatefulWidget`, call `removeChannel()` in `dispose()`. The group feed screen is the primary consumer — subscribe on enter, dispose on leave.

**Reconnection:** On channel status change to `SUBSCRIBED` after a disconnection, immediately re-fetch messages from the database with `created_at > lastSeenTimestamp` to catch missed messages. Show a "Catching up..." indicator during sync.

**Background handling:** When the app is backgrounded, the Realtime connection will eventually drop. Push notifications cover this gap — the user sees a notification and tapping it reopens the app which reconnects and syncs.

### 9.3 Push Notifications

**Architecture:** Edge Functions send push notifications via the **FCM HTTP v1 API** (`https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`). The legacy FCM Server Key API was shut down in July 2024 — **do not use `FCM_SERVER_KEY`**.

The `push-send` Edge Function authenticates to FCM using a Firebase service account private key (stored as `FCM_SERVICE_ACCOUNT_JSON` in Supabase secrets). It generates a short-lived OAuth2 access token from the service account credentials, then sends the push request. The HTTP v1 API uses short-lived tokens (1 hour) instead of a static server key, which is more secure. APNs delivery for iOS is handled by FCM automatically when the iOS APNs key is configured in the Firebase project.

**Notification triggers:**

| Event | Notification | Recipients |
|---|---|---|
| New message | "{sender} in {group}: {preview}" | Group members not currently connected (via Presence check) |
| New catch report | "{sender} landed a {weight} {species} at {venue}" | All group members except the author |
| Session created | "New session planned at {venue} on {date}" | All group members |
| AI intelligence | "New insights available for {group}" | All group members |
| Export ready | "Your data export is ready to download" | Requesting user only |
| Succession alert | "You've been promoted to admin of {group}" | New admin only |
| Invitation | "You've been invited to join {group}" | Invited user (via email, not push) |

**FCM token management:** The app registers/updates the FCM token on each launch by upserting into the `user_devices` table (Section 2.17). On upsert, `last_active_at` is updated. The `push-send` Edge Function queries all active tokens for the target user(s) from `user_devices`, delivering notifications to all registered devices. Tokens not refreshed in 60+ days are pruned by the daily `cron-reconcile` job (stale device cleanup).

### 9.4 Supabase Realtime Limits

On Pro plan with spend cap removed: 10,000 concurrent connections, 2,500 messages/second. A message broadcast to a group of 8 costs 9 message units (1 sent + 8 received). Monitor usage via Supabase dashboard.

### 9.5 Presence (Typing Indicators)

Use Supabase Presence for typing indicators and online status. Presence provides automatic join/leave tracking. Throttle typing indicator broadcasts to max 1 per 2 seconds per user.

---

## 10. Offline-First Architecture

### 10.1 Offline Catch Logging

The core use case — logging a catch on the bank — must work with zero connectivity. This is implemented using **Brick** (`brick_offline_first_with_supabase`) which provides automatic bidirectional sync between a local Drift (SQLite) database and Supabase.

**Tables synced offline:**
- `catch_reports` — full offline create, edit, delete. Syncs on connectivity.
- `venues` — cached locally for offline venue selection in the catch form.
- `messages` — cached for offline reading. New messages queued for sync.

**Tables NOT synced offline (online-only):**
- `group_memberships` — changes require server-side validation
- `invitations` — token validation requires server
- `ai_intelligence_items` — generated server-side only
- `exports` — server-side processing only

### 10.2 Sync Strategy

**Read path (Supabase → Local):**
- On app launch, Brick syncs recent data from Supabase to local SQLite
- **Sync scoping is critical for performance.** Brick queries pass through RLS, but relying solely on RLS to scope the sync is inefficient — it forces PostgreSQL to evaluate RLS policies across all rows before filtering. Always include explicit filters in Brick's remote queries:
  - `catch_reports`: filter by `group_id IN (user's groups)` AND `created_at > (90 days ago)`. Older data is loaded on-demand when the user scrolls into the repository history.
  - `venues`: filter by venues referenced by the user's groups (via a join or subquery on catch_reports/sessions).
  - `messages`: filter by `group_id IN (user's groups)` AND `created_at > (30 days ago)`.
- Supabase Realtime (Broadcast) provides live updates while connected
- Local SQLite is the primary read source for all UI queries — instant rendering

**Write path (Local → Supabase):**
- All writes go to local SQLite first (immediate UI feedback)
- Brick maintains a sync queue for pending writes
- `connectivity_plus` detects network state changes
- On connectivity, Brick processes the queue in order, uploading to Supabase
- Conflicts resolved by `updated_at` timestamp (last-write-wins for this app's concurrency model — small group editing is low-conflict)

### 10.3 Conflict Resolution

For catch reports (the primary offline-editable entity), last-write-wins based on `updated_at` is acceptable because:
- Each catch report has a single author
- Only the author can edit their own catch (RLS enforced)
- Concurrent editing of the same catch report is extremely unlikely

For venue notes (collaborative editing), optimistic locking via the `version` column is used regardless of offline status. If a sync attempt fails due to version mismatch, the user is prompted to re-fetch and merge.

---

## 11. Admin Succession System

### 11.1 Succession Nomination

Each admin can nominate a successor by setting `successor_user_id` on their `group_memberships` record. The nominee must be an existing active member.

### 11.2 Automatic Succession Trigger

The `cron-succession-check` Edge Function runs daily and checks for admins whose `subscription_status` has been 'inactive' for 30+ continuous days. When found:

1. If the admin has a `successor_user_id` set, promote that member to admin
2. If no successor is nominated, promote the longest-tenured active member
3. If no other active members, the group enters "dormant" state
4. Send push notification and email to the new admin
5. The original admin's membership is preserved

### 11.3 Manual Admin Actions

Admins can: promote a member to admin, step down (must nominate replacement first), remove a non-admin member (creates removed_members audit record, invalidates their sessions immediately).

---

## 12. Data Export System

### 12.1 Export Contents

Each export contains: all catch reports by the requesting user in the specified group (CSV and JSON), all attached photos, venue notes, session attendance records, messages (text only, no other members' messages), and export metadata.

### 12.2 Export Generation — Async Background Job

Exports are generated asynchronously via Inngest/QStash. The `export-request` Edge Function creates an `exports` record and dispatches a background job. See Section 4.3 for the full pipeline. The user receives a push notification when the export is ready.

### 12.3 Removed Member Export

When a member is removed or leaves voluntarily, a `removed_members` record is created with `export_available_until` set to 30 days from removal. During this window, the removed user can still request an export. After 30 days, export access is revoked. The data itself remains part of the group repository.

---

## 13. Development Phases

### Phase 1 — Foundation (MVP)

**Goal:** Core platform with groups, catch logging (offline-capable), messaging, and subscription billing.

**Deliverables:**
- Supabase project setup: UUID v7 migration function, all schema tables, RLS policies (set-based pattern), indexes
- Supabase Edge Functions: photos-presign, photos-confirm, revenucat-webhook, send-message, invite-create, invite-redeem, member-remove, weather-backfill, push-silent-upload
- Inngest `photo-process` background job (Node.js + sharp) for server-side EXIF stripping
- RevenueCat integration with iOS App Store and Google Play billing
- Custom Access Token Hook for subscription status in JWT claims
- Flutter app with 4-layer architecture, Riverpod state management, GoRouter navigation
- Authentication flow via `supabase_flutter` with PKCE, magic link, deep link handling
- Offline-first catch logging via Brick + Drift (SQLite)
- Background photo upload queue via `workmanager`
- Dashboard showing user's groups
- Group creation with rule set selection
- Invitation system (128-bit tokens, deep link flow, rate-limited redemption)
- Admin model (promote, remove, step down, succession nomination)
- Catch report logging form with all structured fields — **works offline**
- Weather API integration for auto-populating conditions
- Moon phase calculation (Dart, local)
- Photo capture and upload with client-side resize, presigned URL pattern, server-side EXIF stripping
- Group feed rendering all content types
- Real-time messaging via Supabase Broadcast
- Push notifications via FCM/APNs
- Basic repository view (catch table with search and filter)
- Group members page with admin actions
- Rate limiting via Upstash on all Edge Functions
- Zod validation on all Edge Function inputs
- Marketing site: landing page, invite landing, app store links, privacy policy, terms

### Phase 2 — Intelligence

**Goal:** AI layer, venue notes, session planning, and pattern insights.

**Deliverables:**
- Venue notes screens with collaborative editing (optimistic locking)
- Inngest/QStash setup for background job fan-out
- AI background job infrastructure with per-group processing and map-reduce context management
- AI venue auto-population on first venue addition
- AI intelligence screen within each group
- AI pattern analysis, session briefings, product intelligence
- Session planning with calendar view and RSVP
- Personal stats screen with PB tracking
- Repository stats summary (group-level aggregates)

### Phase 3 — Polish and Export

**Goal:** Data export, advanced features, and UX refinement.

**Deliverables:**
- Async data export system via background job with `exports` table tracking
- 30-day removed member export window
- Advanced repository filtering (multi-field, date ranges, weight ranges)
- Photo library with grid view and filtering
- Venue stats screens
- Admin succession automation (daily cron job)
- Supabase Presence for typing indicators
- Immediate session invalidation for subscription expiration
- Cloudflare Image Resizing for thumbnail delivery
- App Store / Google Play optimisation (screenshots, descriptions, ASO)
- Performance profiling and optimisation

---

## 14. Environment Configuration

### 14.1 Flutter App (Compile-Time)

Sensitive values are injected via `--dart-define-from-file=.env.json` at build time, never hardcoded in source. The `.env.json` file is added to `.gitignore`. For CI/CD, the file is generated from pipeline secrets.

```json
// .env.json (NOT committed to version control)
{
  "SUPABASE_URL": "https://xxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ...",
  "REVENUCAT_APPLE_API_KEY": "appl_xxx",
  "REVENUCAT_GOOGLE_API_KEY": "goog_xxx"
}
```

```bash
# Build command
flutter build ios --dart-define-from-file=.env.json --obfuscate --split-debug-info=build/symbols
```

**Security note:** Values injected via `--dart-define` (or `--dart-define-from-file`) are compiled into the Dart binary and **can be extracted via reverse engineering** (decompilation, string analysis). This is an accepted trade-off for the following keys, all of which are designed for client-side use and have their own server-side validation:
- `SUPABASE_ANON_KEY` — public by design, scoped by RLS
- `REVENUCAT_APPLE_API_KEY` / `REVENUCAT_GOOGLE_API_KEY` — public API keys, receipt validation happens server-side

**No privileged keys** (service role, webhook secrets, API secrets) are ever in `--dart-define-from-file`. The `--obfuscate` flag makes extraction harder but not impossible.

| Variable | Description |
|---|---|
| SUPABASE_URL | Supabase project URL |
| SUPABASE_ANON_KEY | Supabase anonymous (public) key. **This is the ONLY Supabase key in the app binary.** |
| REVENUCAT_APPLE_API_KEY | RevenueCat Apple API key |
| REVENUCAT_GOOGLE_API_KEY | RevenueCat Google API key |

### 14.2 Supabase Edge Functions (Runtime Secrets)

Stored via `supabase secrets set` and accessed via `Deno.env.get()`:

| Variable | Description |
|---|---|
| SUPABASE_SERVICE_ROLE_KEY | Service role key. **Never in the mobile app.** |
| REVENUCAT_WEBHOOK_SECRET | Shared secret for RevenueCat webhook verification |
| CLOUDFLARE_R2_ACCESS_KEY_ID | R2 access key |
| CLOUDFLARE_R2_SECRET_ACCESS_KEY | R2 secret key |
| CLOUDFLARE_R2_BUCKET_NAME | R2 bucket name |
| CLOUDFLARE_R2_ENDPOINT | R2 S3-compatible endpoint URL |
| CLOUDFLARE_R2_PUBLIC_URL | Public URL prefix for R2 assets |
| ANTHROPIC_API_KEY | Claude API key for AI background jobs |
| WEATHER_API_KEY | Met Office DataHub or OpenWeatherMap API key |
| RESEND_API_KEY | Email service API key |
| CRON_SECRET | Secret token for cron job authentication |
| UPSTASH_REDIS_REST_URL | Upstash Redis URL |
| UPSTASH_REDIS_REST_TOKEN | Upstash Redis token |
| INNGEST_SIGNING_KEY | Inngest signing key |
| FCM_SERVICE_ACCOUNT_JSON | Firebase service account private key JSON for FCM HTTP v1 API. **Not the legacy FCM_SERVER_KEY (shut down July 2024).** |

---

## 15. Design System

### 15.1 Colour Palette

| Name | Hex | Usage |
|---|---|---|
| Deep Lake | #1B3A4B | Primary. App bar, nav, buttons. |
| Reed Green | #4A7C59 | Secondary. Success states, positive indicators. |
| Golden Hour | #D4A843 | Accent. Highlights, badges, CTAs. |
| Chalk White | #F5F5F0 | Background. Main content area. |
| Slate | #2C3E50 | Body text. |
| Mist | #E8ECEF | Borders, dividers, subtle backgrounds. |
| Dawn | #FFF8F0 | Card backgrounds, warm contrast areas. |
| Alert Red | #C0392B | Errors, destructive actions. |

### 15.2 Typography

- **Headings:** Inter (weight 600–700). H1: 28px, H2: 22px, H3: 18px.
- **Body:** Inter (weight 400). 16px, line-height 1.5.
- **Captions:** Inter (weight 400). 13px. Timestamps, metadata.
- **Monospace:** JetBrains Mono. Weights, measurements, technical data.

### 15.3 Component Patterns (Material 3)

- **Cards:** `Card` widget with 1px Mist border, 8px border-radius, 16px padding. Elevation 0, subtle shadow on pressed.
- **Catch cards:** Species colour-coded left border via `Container` decoration (Common: Deep Lake, Mirror: Golden Hour, Leather: Reed Green). Weight prominent (monospace, 20px). Photo thumbnails right-aligned via `CachedNetworkImage`.
- **Buttons:** `FilledButton` (Deep Lake), `OutlinedButton` (secondary), `FilledButton.tonal` (destructive with Alert Red). 8px border-radius.
- **Forms:** `TextFormField` with `OutlineInputBorder`, Mist border, 12px content padding. Labels above inputs. Validation errors in Alert Red.
- **Feed items:** `ListView.builder` with date separators. Each content type uses a distinct card widget.
- **Navigation:** `NavigationBar` (Material 3 bottom nav) on mobile. 5 destinations.
- **Empty states:** Illustrated `Column` with SVG asset and action button.
- **Offline indicator:** `ConnectivityBanner` widget at top of screen when offline, auto-hides on reconnection.

---

## 16. Error Handling and Edge Cases

### 16.1 Subscription Lapses

- Active: Full access
- Past due (within grace period): Full access with payment warning banner
- Inactive (grace period expired): No group access. Show paywall. Data preserved.
- If admin, succession timer starts at 30 days inactive

### 16.2 Group Deletion

Groups are never hard-deleted. If all members leave, the group enters "dormant" state. Data preserved indefinitely. Reactivation via support.

### 16.3 Concurrent Venue Note Editing

Optimistic locking via `version` column. If update fails (version mismatch), client re-fetches and presents merge prompt.

### 16.4 Failed Photo Uploads

Catch report saved immediately (offline or online). Photos upload separately via background queue. Failed uploads retry 5 times. User sees "Upload failed" indicator and can retry manually.

### 16.5 AI Job Failures

Automatic retries via Inngest/QStash with exponential backoff. Failed groups don't block others. Intelligence screen shows last successful update timestamp.

### 16.6 Invitation Expiry

14-day expiry. Generic error for nonexistent/expired/used tokens (prevents enumeration). Admin can create new invitation.

### 16.7 Offline Sync Conflicts

Last-write-wins for catch reports (single-author, low-conflict). Version-based for venue notes. Sync failures queued for retry. User notified of conflicts requiring manual resolution.

### 16.8 App Backgrounding

When backgrounded: Realtime connection drops, push notifications cover the gap, `workmanager` handles pending photo uploads, Brick sync queue persists across app restarts.

### 16.9 Export Job Failures

`exports` record updated with status: 'failed' and error message. User notified via push. Can retry. For exports >500 photos, split into multiple ZIPs.

---

## 17. Security Considerations

### 17.1 Data Isolation

RLS is the primary security boundary. All group-scoped tables use set-based RLS policies (Section 3). All group-scoped tables must have RLS enabled.

### 17.2 Mobile App Security

- **No service role key in the app binary.** The anon key is the only Supabase key shipped. All privileged operations happen in Edge Functions.
- **Token storage:** Use `flutter_secure_storage` backed by Keychain (iOS) / Keystore (Android). Never use `SharedPreferences` for auth tokens.
- **Certificate pinning:** Consider implementing certificate pinning for the Supabase API endpoint in production to prevent MITM attacks.
- **Code obfuscation:** Enable `--obfuscate` and `--split-debug-info` flags in release builds.
- **Root/jailbreak detection:** Consider adding `flutter_jailbreak_detection` for additional protection against reverse engineering.

### 17.3 Edge Function Security

Edge Functions require valid JWT by default. Webhook functions disable JWT verification and implement their own signature checks. All inputs validated with Zod `.strict()`. Group ID consistency validated before database queries.

### 17.4 Photo Privacy

EXIF stripping is enforced server-side in the `photo-process` Inngest background job (Node.js + sharp). The `photos-confirm` Edge Function validates the upload and dispatches the processing job — the upload pipeline never stores an unprocessed image permanently once the job completes. GPS coordinates in metadata can reveal fishing locations. After processing, verify that `.exif`, `.xmp`, `.iptc` fields are absent via `sharp(buffer).metadata()`.

### 17.5 Invitation Security

128-bit entropy tokens. Single-use, 14-day expiry. Generic errors. Rate limited: 5 attempts per IP per 15 minutes.

### 17.6 Webhook Verification

RevenueCat webhooks verified via shared secret in Authorization header. If using Stripe directly, verify via `Stripe-Signature`. Reject events with invalid signatures.

### 17.7 R2 Access Control

R2 bucket not publicly listed. Presigned URLs for uploads (5-minute expiry). Presign keys tracked in Redis and validated on confirm. Signed URLs for downloads.

### 17.8 AI Data Boundaries

AI background job uses service role key (bypasses RLS). Only data from a single group per AI prompt — never mix groups. AI responses validated (JSON parsed, schema-checked) before database writes.

### 17.9 Input Validation

Zod `.strict()` on all Edge Function inputs. Dart model validation on all client-side inputs. Group ID consistency check on all group-scoped operations.

### 17.10 File Upload Security

- Validate MIME types via magic bytes (not Content-Type header)
- UUID-based file naming (prevents path traversal)
- Size limits: 10MB raw, 4MB after client resize, enforced at presign
- Presigned URLs expire after 5 minutes
- Redis key validation on confirm

### 17.11 Deep Link Security

- App Links (Android) and Universal Links (iOS) use HTTPS verification via `.well-known` files
- Fallback `carp://` scheme only enabled in debug builds
- Invite tokens extracted from deep links are validated server-side before any action
- Auth callback deep links use PKCE to prevent authorization code interception

### 17.12 Environment Variable Security

Service role key, webhook secrets, API keys, and cron secrets are stored as Supabase Edge Function secrets. Never embedded in the mobile app. Compile-time `--dart-define` values for the app must not include any privileged keys.
