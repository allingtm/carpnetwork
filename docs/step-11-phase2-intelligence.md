# Carp.Network — Step 11: Phase 2 — Intelligence

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 8, 2.10, 2.11, 2.12, 2.14  
**Depends on:** Step 10 (Phase 1 complete and signed off)  
**Commit after each sub-task. Final:** `git commit -m "Step 11: Phase 2 complete — AI intelligence, venue notes, sessions, stats"`

---

## Context

Phase 2 adds the intelligence layer: AI-powered insights, venue notes with collaborative editing, session planning, and personal/group stats. Only begin this after Phase 1 is fully working and signed off.

---

## Task 11.1: Venue Notes Screens

Create the venue notes feature with collaborative editing and optimistic locking.

**Screens:**
- `lib/presentation/screens/venues/venue_notes_screen.dart` — list of venue notes for a group
- `lib/presentation/screens/venues/venue_note_editor_screen.dart` — rich text editor for a single venue note

**Key details:**
- Each `venue_notes` record has a `version` integer column
- On save, the UPDATE query includes `WHERE version = {current_version}`
- If the WHERE clause matches 0 rows → another user edited first → show conflict dialog
- Conflict resolution: show both versions, let user choose or merge

**Repository:**
- `lib/data/venues/venue_notes_repository.dart` — CRUD with version-aware updates

**Reference:** Spec Sections 2.10, 10.3

---

## Task 11.2: Inngest AI Fan-Out Infrastructure

Set up the AI background processing pipeline.

**`supabase/functions/cron-ai-processing/index.ts`:**
- Auth: `CRON_SECRET` header
- Runs every 15 minutes
- Queries groups with `subscription_status = 'active'` that have new activity since last run
- For each qualifying group, dispatches an Inngest event `ai/process-group`

**`inngest/src/functions/ai-process-group.ts`:**
- Receives group_id
- Assembles context: recent catches, venue data, weather history, member activity (Spec Section 8.2)
- Implements map-reduce for large groups: split context into chunks, process each, merge results
- Calls the Anthropic Claude API with the assembled context and system prompt
- Parses structured AI output
- Inserts results into `ai_intelligence_items` table

**AI system prompt structure (Spec Section 8.2):**
- Group context: member count, active venues, recent catches
- Analysis categories: pattern recognition, session briefings, product intelligence, venue conditions

**Reference:** Spec Sections 8.1, 8.2, 8.4, 7.2

---

## Task 11.3: AI Intelligence Screen

Create `lib/presentation/screens/intelligence/intelligence_screen.dart`:

- Grid of AI insight cards grouped by category (Spec Section 8.4):
  - Pattern Analysis (catch trends, species patterns, bait effectiveness)
  - Session Briefings (pre-session preparation advice)
  - Product Intelligence (tackle/bait recommendations based on group data)
  - Venue Conditions (water temp, pressure, wind analysis)
- Each card shows: category icon, title, summary, generated_at timestamp
- Tap card → expanded view with full analysis text
- Pull-to-refresh shows latest insights
- Empty state: "Intelligence generates automatically as your group logs more catches"

**Reference:** Spec Sections 8.4, 6.1

---

## Task 11.4: Session Planning

Create session planning screens:

**`lib/presentation/screens/sessions/session_create_screen.dart`:**
- Form: title, venue (dropdown), start date/time, end date/time, notes
- Creates `sessions` record

**`lib/presentation/screens/sessions/session_detail_screen.dart`:**
- Session info with venue details
- Attendee list with RSVP status
- "RSVP" button: attending / not attending / maybe
- Swim preferences (if venue_and_swim detail level)
- Weather forecast for session date (if available)

**`lib/presentation/screens/sessions/sessions_list_screen.dart`:**
- Calendar view showing upcoming sessions
- Past sessions with attendance summary
- Filter: upcoming / past

**Repository:**
- `lib/data/sessions/session_repository.dart` — CRUD for sessions and session_attendees

**Reference:** Spec Sections 2.11, 2.12, 6.1

---

## Task 11.5: Personal Stats Screen

Create `lib/presentation/screens/stats/personal_stats_screen.dart`:

- Total catches count
- Personal best (heaviest catch) by species
- Favourite venue (most catches)
- Catches per month chart (use recharts equivalent — `fl_chart`)
- Species breakdown (pie chart)
- Average weight by species
- Most productive bait
- Best conditions (weather pattern correlation)

All data sourced from local Brick database — no network needed for rendering.

**Reference:** Spec Section 6.1

---

## Task 11.6: Group Stats Summary

Create `lib/presentation/screens/stats/group_stats_screen.dart`:

- Group total catches
- Group PBs by species (heaviest per species across all members)
- Most active member
- Most popular venues
- Species distribution chart
- Monthly activity chart
- Leaderboard (top catchers by count and by weight)

**Reference:** Spec Section 6.1

---

## Validation

1. `flutter analyze` — zero errors
2. Venue notes save with version tracking, conflict detected on stale edit
3. AI cron dispatches processing jobs for active groups
4. AI insights appear in intelligence screen after processing
5. Session creation and RSVP flow works
6. Personal stats display correctly from local data
7. Group stats aggregate across all members
8. All new screens accessible via GoRouter navigation
