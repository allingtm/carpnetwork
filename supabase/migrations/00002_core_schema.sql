-- =============================================================
-- Carp.Network Core Schema — 17 tables
-- =============================================================

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =============================================================
-- 1. users (extends auth.users)
-- =============================================================
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  avatar_url text,
  location text,
  stripe_customer_id text UNIQUE,
  subscription_status text NOT NULL DEFAULT 'inactive'
    CHECK (subscription_status IN ('active', 'past_due', 'cancelled', 'inactive')),
  subscription_period_end timestamptz,
  subscription_grace_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- 2. stripe_events (text PK, not UUID)
-- =============================================================
CREATE TABLE stripe_events (
  event_id text PRIMARY KEY,
  event_type text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 3. rule_sets
-- =============================================================
CREATE TABLE rule_sets (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  name text NOT NULL,
  description text NOT NULL,
  rules jsonb NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 4. groups
-- =============================================================
CREATE TABLE groups (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  name text NOT NULL,
  rule_set_id uuid NOT NULL REFERENCES rule_sets(id),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  member_count integer NOT NULL DEFAULT 1
);

-- =============================================================
-- 5. group_memberships
-- =============================================================
CREATE TABLE group_memberships (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  role text NOT NULL DEFAULT 'member'
    CHECK (role IN ('admin', 'member')),
  successor_user_id uuid REFERENCES users(id),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id)
);

-- Trigger to maintain groups.member_count on INSERT/DELETE
CREATE OR REPLACE FUNCTION update_member_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.groups SET member_count = member_count + 1 WHERE id = NEW.group_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.groups SET member_count = member_count - 1 WHERE id = OLD.group_id;
    RETURN OLD;
  END IF;
END;
$$;

CREATE TRIGGER trg_group_memberships_count
  AFTER INSERT OR DELETE ON group_memberships
  FOR EACH ROW EXECUTE FUNCTION update_member_count();

-- =============================================================
-- 6. invitations
-- =============================================================
CREATE TABLE invitations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES users(id),
  invite_token text NOT NULL UNIQUE,
  invited_email text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

-- =============================================================
-- 7. venues
-- =============================================================
CREATE TABLE venues (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  name text NOT NULL,
  location_lat numeric(10,7),
  location_lng numeric(10,7),
  county text,
  country text NOT NULL DEFAULT 'UK',
  venue_type text CHECK (venue_type IN ('day_ticket', 'syndicate', 'club', 'free')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (name, location_lat, location_lng)
);

-- =============================================================
-- 8. catch_reports
-- =============================================================
CREATE TABLE catch_reports (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  venue_id uuid NOT NULL REFERENCES venues(id),
  fish_species text NOT NULL
    CHECK (fish_species IN ('common', 'mirror', 'leather', 'ghost', 'fully_scaled', 'grass')),
  fish_weight_lb integer NOT NULL,
  fish_weight_oz integer NOT NULL
    CHECK (fish_weight_oz >= 0 AND fish_weight_oz <= 15),
  fish_name text,
  swim text,
  casting_distance_wraps integer,
  bait_type text,
  bait_brand text,
  bait_product text,
  bait_size_mm integer,
  bait_colour text,
  rig_name text,
  hook_size integer,
  hooklink_material text,
  hooklink_length_inches integer,
  lead_arrangement text,
  air_pressure_mb numeric(6,1),
  wind_direction text,
  wind_speed_mph integer,
  air_temp_c numeric(4,1),
  water_temp_c numeric(4,1),
  cloud_cover text,
  rain text,
  moon_phase text,
  caught_at timestamptz NOT NULL,
  notes text,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_catch_reports_updated_at
  BEFORE UPDATE ON catch_reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- 9. catch_report_photos
-- =============================================================
CREATE TABLE catch_report_photos (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  catch_report_id uuid NOT NULL REFERENCES catch_reports(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  storage_key text NOT NULL,
  url text NOT NULL,
  width integer,
  height integer,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 10. venue_notes
-- =============================================================
CREATE TABLE venue_notes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  venue_id uuid NOT NULL REFERENCES venues(id),
  content jsonb NOT NULL,
  ai_populated_content jsonb,
  last_edited_by uuid REFERENCES users(id),
  last_ai_update timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, venue_id)
);

CREATE TRIGGER trg_venue_notes_updated_at
  BEFORE UPDATE ON venue_notes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- 11. sessions
-- =============================================================
CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES users(id),
  venue_id uuid NOT NULL REFERENCES venues(id),
  title text,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  duration_type text
    CHECK (duration_type IN ('day_session', 'overnighter', '48_hour', 'weekend')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 12. session_attendees
-- =============================================================
CREATE TABLE session_attendees (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  session_id uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  status text NOT NULL DEFAULT 'going'
    CHECK (status IN ('going', 'maybe', 'declined')),
  preferred_swim text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, user_id)
);

-- =============================================================
-- 13. messages
-- =============================================================
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  content text NOT NULL,
  reply_to_id uuid REFERENCES messages(id),
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 14. ai_intelligence_items
-- =============================================================
CREATE TABLE ai_intelligence_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  category text NOT NULL
    CHECK (category IN ('pattern', 'venue', 'briefing', 'product')),
  title text NOT NULL,
  highlight text NOT NULL,
  content text NOT NULL,
  related_venue_id uuid REFERENCES venues(id),
  related_session_id uuid REFERENCES sessions(id),
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 15. removed_members
-- =============================================================
CREATE TABLE removed_members (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  removed_by uuid REFERENCES users(id),
  reason text NOT NULL
    CHECK (reason IN ('removed', 'left_voluntarily')),
  export_available_until timestamptz NOT NULL,
  export_downloaded boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================
-- 16. exports
-- =============================================================
CREATE TABLE exports (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id uuid NOT NULL REFERENCES users(id),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'complete', 'failed')),
  download_url text,
  error_message text,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

-- =============================================================
-- 17. user_devices
-- =============================================================
CREATE TABLE user_devices (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL UNIQUE,
  platform text NOT NULL
    CHECK (platform IN ('ios', 'android')),
  last_active_at timestamptz NOT NULL DEFAULT now()
);
