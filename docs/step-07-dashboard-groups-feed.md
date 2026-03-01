# Carp.Network — Step 07: Dashboard, Groups, Feed, and Members

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 6.1, 6.2, 9.2, 2.3, 2.4  
**Depends on:** Step 03 (routing, theme), Step 06 (Brick models, catch repository)  
**Commit after completion:** `git commit -m "Step 07: Dashboard, groups, feed, members screens"`

---

## Context

This step builds the main navigation experience: the dashboard (list of groups), group creation, the group feed (unified activity stream), and the members screen with admin actions.

---

## Task 1: Dashboard Screen

Create `lib/presentation/screens/dashboard/dashboard_screen.dart`:

- Displays the user's groups as cards
- Each card shows: group name, member count, last activity timestamp, rule_set name
- Tap a card → navigate to `/groups/:groupId` (group feed)
- "Create Group" floating action button
- Empty state: "You're not in any groups yet. Ask a friend for an invite, or create your own."
- Pull-to-refresh triggers Brick sync

Create `lib/data/groups/group_repository.dart`:
- `getMyGroups()` — queries local Brick DB for groups where user has membership
- `createGroup(name, ruleSetId)` — creates group via Supabase, auto-creates admin membership for creator
- `getGroup(groupId)` — single group details
- `getGroupMembers(groupId)` — list of members with roles

Create `lib/application/providers/group_providers.dart`:
- `myGroupsProvider` — watches Brick for user's groups
- `groupDetailProvider(groupId)` — single group
- `groupMembersProvider(groupId)` — members list

**Reference:** Spec Sections 6.1, 2.3, 2.4

---

## Task 2: Create Group Screen

Create `lib/presentation/screens/groups/create_group_screen.dart`:

- Group name text field (required, max 100 chars)
- Rule set selector — dropdown loading from rule_sets table. Show name and key settings (max_members, location detail level)
- "Create" button:
  1. Insert into `groups` table (via repository)
  2. Insert into `group_memberships` with role: 'admin' for the creator
  3. Navigate to the new group's feed

**Reference:** Spec Sections 2.3, 2.6

---

## Task 3: Group Feed Screen

Create `lib/presentation/screens/groups/group_feed_screen.dart`:

This is the unified activity stream showing all group activity in reverse chronological order.

**Content types to render (Spec Section 6.2):**
- **CatchCard** — species icon (coloured by species), weight, venue, member name, caught_at, photo thumbnails
- **MessageBubble** — sender, content, timestamp, reply indicator
- **SessionCard** — session title, venue, date, attendee count
- **IntelligenceCard** — AI insight category icon, title, summary (Phase 2, but stub the widget now)

**Performance (Spec Section 6.2):**
- Wrap complex card widgets in `RepaintBoundary`
- Use `const` constructors on static child widgets
- Paginate: load 20 items initially, fetch more on scroll via `ScrollController` with threshold trigger
- Read from local Brick DB (instant rendering)

**Real-time updates:**
- Subscribe to Supabase Broadcast channel `group:{groupId}` on screen enter
- Handle events: `new_catch`, `new_message`, `photo_ready`
- **Clean up channel on dispose** (Spec Section 9.2):
  ```dart
  ref.onDispose(() async {
    await Supabase.instance.client.removeChannel(channel);
  });
  ```

Create widget files:
- `lib/presentation/widgets/catch_card.dart`
- `lib/presentation/widgets/message_bubble.dart`
- `lib/presentation/widgets/session_card.dart`
- `lib/presentation/widgets/intelligence_card.dart` (stub)

**Reference:** Spec Sections 6.2, 9.2

---

## Task 4: Group Chat Screen

Create `lib/presentation/screens/groups/group_chat_screen.dart`:

- Message list in reverse chronological order (newest at bottom)
- Text input with send button
- Send calls the `send-message` Edge Function (Spec Section 7.1)
- Live updates via Broadcast subscription (same channel as feed, listen for `new_message` event)
- Soft-deleted messages show "[Message deleted]" placeholder
- Reply support: long-press a message to reply, shows replied-to preview in input area
- Clean up Broadcast channel on dispose

Create `lib/data/messages/message_repository.dart`:
- `sendMessage(groupId, content, replyToId?)` — calls send-message Edge Function
- `getMessages(groupId, {before, limit})` — reads from local Brick DB, paginated
- `softDeleteMessage(messageId)` — sets deleted_at

**Reference:** Spec Sections 9.1, 9.2, 2.13

---

## Task 5: Members Screen

Create `lib/presentation/screens/groups/members_screen.dart`:

- List of group members with: name, role badge (admin/member), joined_at
- Current user's role determines available actions:

**Admin actions (shown if current user is admin):**
- "Invite" button → navigates to invite screen
- Per-member actions (long press or overflow menu):
  - Promote to admin (update role via Supabase)
  - Remove member (calls member-remove Edge Function)
  - Nominate as successor
- "Step Down" option for the admin themselves (if 2+ admins exist)

**All members see:**
- Member list with roles
- Group settings summary (rule set details)

**Reference:** Spec Sections 6.1, 2.4.1, 11

---

## Task 6: Invite Screen

Create `lib/presentation/screens/groups/invite_screen.dart`:

- "Generate Invite Link" button → calls invite-create Edge Function
- Displays the invite URL
- Share button using platform share sheet (`Share.share()` from share_plus)
- Shows pending invitations list with: invited date, expires date, status
- Admin can cancel pending invitations

**Reference:** Spec Sections 2.5, 7.1

---

## Task 7: Catch Detail Screen

Create `lib/presentation/screens/catches/catch_detail_screen.dart`:

- Full catch report display with all fields
- Photo gallery (swipeable, using `CachedNetworkImage`)
- Edit button (only if user is the catch author)
- Delete button (soft delete, only if user is the catch author)
- Weather and moon phase display
- Venue link

**Image cache performance (Spec Section 4.4):**
- Use `CachedNetworkImage` with `memCacheHeight: 400` and `memCacheWidth: 400` for grid thumbnails
- Use `fadeInDuration: Duration.zero` for fast scrolling contexts
- Full-resolution images only on detail/zoom views

**Reference:** Spec Sections 6.1, 4.4

---

## Task 8: Repository Screen

Create `lib/presentation/screens/catches/repository_screen.dart`:

- Table/list view of catch reports for the group
- Search: text search across species, venue name, bait, member name
- Sort: by date (default), weight (heaviest first)
- Filter chips: species, venue, date range
- Tap a row → navigate to catch detail
- Use `itemExtent` on `ListView.builder` for fixed-height rows (performance)
- Reads from local Brick database (instant rendering)
- Paginated: load 50, then more on scroll

**Reference:** Spec Sections 6.1, 6.2

---

## Validation

1. `flutter analyze` — zero errors
2. Dashboard shows groups (or empty state)
3. Can create a group and it appears on dashboard
4. Group feed shows catch cards and messages in reverse chronological order
5. Chat sends and receives messages
6. Broadcast channel subscribes on enter and disposes on leave (check no channel leak)
7. Members screen shows member list with correct roles
8. Invite flow generates a shareable link
9. Repository search and filter works against local data
10. Catch detail screen displays all fields and photos
