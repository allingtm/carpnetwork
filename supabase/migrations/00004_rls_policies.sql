-- =============================================================
-- Private schema and security definer helper
-- =============================================================
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

-- =============================================================
-- Enable RLS on all tables
-- =============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE stripe_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE catch_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE catch_report_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_intelligence_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE removed_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- =============================================================
-- POLICIES: users
-- =============================================================
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()));

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

-- =============================================================
-- POLICIES: stripe_events (service role only, no user policies)
-- =============================================================

-- =============================================================
-- POLICIES: rule_sets
-- =============================================================
CREATE POLICY "All authenticated users can view rule sets"
  ON rule_sets FOR SELECT TO authenticated
  USING (true);

-- =============================================================
-- POLICIES: groups
-- =============================================================
CREATE POLICY "Members can view their groups"
  ON groups FOR SELECT TO authenticated
  USING (id IN (SELECT private.user_group_ids()));

CREATE POLICY "Authenticated users can create groups"
  ON groups FOR INSERT TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "Admins can update their groups"
  ON groups FOR UPDATE TO authenticated
  USING (
    id IN (
      SELECT gm.group_id FROM public.group_memberships gm
      WHERE gm.user_id = (SELECT auth.uid()) AND gm.role = 'admin'
    )
  )
  WITH CHECK (
    id IN (
      SELECT gm.group_id FROM public.group_memberships gm
      WHERE gm.user_id = (SELECT auth.uid()) AND gm.role = 'admin'
    )
  );

-- =============================================================
-- POLICIES: group_memberships
-- =============================================================
CREATE POLICY "Members can view group memberships"
  ON group_memberships FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Members can insert memberships"
  ON group_memberships FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Members can delete memberships"
  ON group_memberships FOR DELETE TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

-- =============================================================
-- POLICIES: invitations
-- =============================================================
CREATE POLICY "Members can view group invitations"
  ON invitations FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Admins can create invitations"
  ON invitations FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Admins can update invitations"
  ON invitations FOR UPDATE TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()))
  WITH CHECK (group_id IN (SELECT private.user_group_ids()));

-- =============================================================
-- POLICIES: venues (shared, not group-scoped)
-- =============================================================
CREATE POLICY "Authenticated users can view venues"
  ON venues FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can create venues"
  ON venues FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update venues"
  ON venues FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

-- =============================================================
-- POLICIES: catch_reports
-- =============================================================
CREATE POLICY "Members can view group catches"
  ON catch_reports FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()) AND deleted_at IS NULL);

CREATE POLICY "Members can create catches"
  ON catch_reports FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()) AND user_id = (SELECT auth.uid()));

CREATE POLICY "Authors can update own catches"
  ON catch_reports FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()) AND deleted_at IS NULL)
  WITH CHECK (user_id = (SELECT auth.uid()) AND group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Authors can soft-delete own catches"
  ON catch_reports FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()) AND deleted_at IS NULL);

-- =============================================================
-- POLICIES: catch_report_photos
-- =============================================================
CREATE POLICY "Members can view group photos"
  ON catch_report_photos FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Members can upload photos"
  ON catch_report_photos FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Authors can delete own photos"
  ON catch_report_photos FOR DELETE TO authenticated
  USING (
    catch_report_id IN (
      SELECT cr.id FROM public.catch_reports cr
      WHERE cr.user_id = (SELECT auth.uid())
    )
  );

-- =============================================================
-- POLICIES: venue_notes
-- =============================================================
CREATE POLICY "Members can view group venue notes"
  ON venue_notes FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Members can create venue notes"
  ON venue_notes FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Members can update group venue notes"
  ON venue_notes FOR UPDATE TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()))
  WITH CHECK (group_id IN (SELECT private.user_group_ids()));

-- =============================================================
-- POLICIES: sessions
-- =============================================================
CREATE POLICY "Members can view group sessions"
  ON sessions FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

CREATE POLICY "Members can create sessions"
  ON sessions FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()) AND created_by = (SELECT auth.uid()));

CREATE POLICY "Creators can update own sessions"
  ON sessions FOR UPDATE TO authenticated
  USING (created_by = (SELECT auth.uid()))
  WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "Creators can delete own sessions"
  ON sessions FOR DELETE TO authenticated
  USING (created_by = (SELECT auth.uid()));

-- =============================================================
-- POLICIES: session_attendees
-- =============================================================
CREATE POLICY "Members can view session attendees"
  ON session_attendees FOR SELECT TO authenticated
  USING (
    session_id IN (
      SELECT s.id FROM public.sessions s
      WHERE s.group_id IN (SELECT private.user_group_ids())
    )
  );

CREATE POLICY "Users can manage own attendance"
  ON session_attendees FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own attendance"
  ON session_attendees FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can remove own attendance"
  ON session_attendees FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- =============================================================
-- POLICIES: messages
-- =============================================================
CREATE POLICY "Members can view group messages"
  ON messages FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()) AND deleted_at IS NULL);

CREATE POLICY "Members can send messages"
  ON messages FOR INSERT TO authenticated
  WITH CHECK (group_id IN (SELECT private.user_group_ids()) AND user_id = (SELECT auth.uid()));

CREATE POLICY "Authors can soft-delete own messages"
  ON messages FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- =============================================================
-- POLICIES: ai_intelligence_items (read-only for users)
-- =============================================================
CREATE POLICY "Members can view group AI insights"
  ON ai_intelligence_items FOR SELECT TO authenticated
  USING (group_id IN (SELECT private.user_group_ids()));

-- =============================================================
-- POLICIES: removed_members
-- =============================================================
CREATE POLICY "Users can view own removal records"
  ON removed_members FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- =============================================================
-- POLICIES: exports
-- =============================================================
CREATE POLICY "Users can view own exports"
  ON exports FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can request own exports"
  ON exports FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- =============================================================
-- POLICIES: user_devices
-- =============================================================
CREATE POLICY "Users can view own devices"
  ON user_devices FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can register devices"
  ON user_devices FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own devices"
  ON user_devices FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can remove own devices"
  ON user_devices FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));
