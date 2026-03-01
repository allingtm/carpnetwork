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
-- Stale device cleanup uses a query filter rather than a partial index (now() is not immutable)
CREATE INDEX idx_user_devices_last_active ON user_devices (last_active_at);
