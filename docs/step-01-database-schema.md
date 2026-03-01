# Carp.Network — Step 01: Database Schema

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 2.0 through 2.18  
**Depends on:** Step 00 complete  
**Commit after completion:** `git commit -m "Step 01: Database schema — UUID v7, 17 tables, indexes, seed data"`

---

## Context

This is the most critical step in the entire build. Every Flutter screen, Edge Function, and RLS policy depends on the database being exactly right. Take your time. Follow the spec precisely.

---

## Task 1: UUID v7 Migration Function

Create `supabase/migrations/00001_uuid_v7_function.sql`.

Copy the exact `uuid_generate_v7()` function from **Spec Section 2.0** verbatim. This must be the first migration — every table's DEFAULT clause depends on it.

Include the migration path comment about PostgreSQL 18.

**Validation:** `supabase db reset` runs without error. `SELECT uuid_generate_v7();` returns a valid UUID.

---

## Task 2: Core Schema Tables

Create `supabase/migrations/00002_core_schema.sql`.

Create all 17 tables in this exact order (foreign key dependencies require this order):

1. **users** (Spec Section 2.1) — extends auth.users. Note: the `fcm_token` and `platform` columns do NOT go here — they live in `user_devices` (table 17). Include `stripe_customer_id` with UNIQUE constraint, `subscription_status` defaulting to 'inactive', `subscription_period_end`, `subscription_grace_until`.
2. **stripe_events** (Section 2.2) — PK is `event_id` (text), not UUID.
3. **rule_sets** (Section 2.6) — includes `rules` JSONB column.
4. **groups** (Section 2.3) — FK to rule_sets and users. `member_count` with DEFAULT 1.
5. **group_memberships** (Section 2.4) — FK to groups and users. UNIQUE(group_id, user_id). `successor_user_id` nullable FK to users.
6. **invitations** (Section 2.5) — UNIQUE on invite_token. `expires_at` NOT NULL.
7. **venues** (Section 2.9) — UNIQUE(name, location_lat, location_lng). No group scope.
8. **catch_reports** (Section 2.7) — FK to groups, users, venues. `venue_id` FK has NO ON DELETE CASCADE. `fish_weight_oz` CHECK(0–15). `deleted_at` for soft delete.
9. **catch_report_photos** (Section 2.8) — FK to catch_reports (CASCADE) and groups (CASCADE).
10. **venue_notes** (Section 2.10) — UNIQUE(group_id, venue_id). `version` for optimistic locking.
11. **sessions** (Section 2.11) — FK to groups, users, venues. `venue_id` NO ON DELETE CASCADE.
12. **session_attendees** (Section 2.12) — UNIQUE(session_id, user_id).
13. **messages** (Section 2.13) — `reply_to_id` self-referencing FK. `deleted_at` for soft delete.
14. **ai_intelligence_items** (Section 2.14) — nullable FKs to venues and sessions.
15. **removed_members** (Section 2.15) — `export_available_until` NOT NULL.
16. **exports** (Section 2.16) — `status` defaults to 'pending'.
17. **user_devices** (Section 2.17) — UNIQUE on `fcm_token`. `last_active_at` defaults to now().

**For every table:**
- All PKs use `DEFAULT uuid_generate_v7()` (except stripe_events which uses text PK)
- Include all CHECK constraints
- Include all UNIQUE constraints
- Include all FK constraints with correct ON DELETE behaviour
- Include `created_at timestamptz NOT NULL DEFAULT now()` where specified
- Include `updated_at timestamptz NOT NULL DEFAULT now()` where specified

**Also create:**
- A trigger function `update_updated_at()` that sets `updated_at = now()` on UPDATE. Apply it to all tables that have an `updated_at` column.
- A trigger on `group_memberships` that increments/decrements `groups.member_count` on INSERT/DELETE (not UPDATE — membership uses hard deletes per Section 2.4.1).

**Reference:** Spec Sections 2.1–2.17, 2.4.1

**Validation:** `supabase db reset` succeeds. `SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';` returns 17.

---

## Task 3: Indexes

Create `supabase/migrations/00003_indexes.sql`.

Copy ALL indexes from **Spec Section 2.18** verbatim, including the comment headers. These are:

- RLS-critical indexes (group_memberships user_id, group_user composite)
- Feed and timeline ordering indexes (messages, catch_reports, ai_intelligence_items — all with WHERE deleted_at IS NULL partial indexes where applicable)
- Foreign key indexes (every FK column)
- Invitation token lookup (unique partial index on pending only)
- Repository search indexes
- Push notification token lookup (user_devices)

**Reference:** Spec Section 2.18

**Validation:** `supabase db reset` succeeds. Verify index count matches the spec.

---

## Task 4: Seed Data

Create `supabase/seed.sql`.

Insert 3–4 rule_set records representing common fishing group configurations:

1. **"Standard"** — admin_only invites, venue_and_swim location detail, photos allowed, external sharing prohibited, named fish logging enabled, no removal vote, max 20 members
2. **"Syndicate"** — admin_only invites, venue_only location detail, photos allowed, external sharing prohibited, named fish logging enabled, no removal vote, max 12 members
3. **"Casual"** — admin_only invites, venue_and_swim location detail, photos allowed, external sharing with permission, named fish logging disabled, no removal vote, max 20 members
4. **"Strict Privacy"** — admin_only invites, venue_only, photo backgrounds restricted, external sharing prohibited, named fish logging enabled, no removal vote, max 8 members

Use `uuid_generate_v7()` for IDs. Match the JSONB structure from **Spec Section 2.6.1**.

**Reference:** Spec Sections 2.6, 2.6.1

**Validation:** `supabase db reset` succeeds. `SELECT count(*) FROM rule_sets;` returns 4. `SELECT name, rules->>'max_members' FROM rule_sets;` returns correct values.

---

## Final Validation

Run `supabase db reset` one final time. Everything should apply cleanly with zero errors. This is the foundation — if anything is wrong here, everything built on top will break.
