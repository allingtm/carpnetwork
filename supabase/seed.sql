-- Seed data for Carp.Network — rule_sets

INSERT INTO rule_sets (id, name, description, rules) VALUES
(
  uuid_generate_v7(),
  'Standard',
  'Balanced rules for most fishing groups. Admin-controlled invites, detailed location logging, and standard privacy settings.',
  '{"invitation_policy": "admin_only", "location_detail": "venue_and_swim", "photo_backgrounds": "allowed", "external_sharing": "prohibited", "named_fish_logging": "enabled", "removal_vote_required": false, "max_members": 20}'::jsonb
),
(
  uuid_generate_v7(),
  'Syndicate',
  'Tighter group for syndicate waters. Smaller membership cap with venue-level location only.',
  '{"invitation_policy": "admin_only", "location_detail": "venue_only", "photo_backgrounds": "allowed", "external_sharing": "prohibited", "named_fish_logging": "enabled", "removal_vote_required": false, "max_members": 12}'::jsonb
),
(
  uuid_generate_v7(),
  'Casual',
  'Relaxed rules for social fishing groups. Allows sharing catches externally with permission.',
  '{"invitation_policy": "admin_only", "location_detail": "venue_and_swim", "photo_backgrounds": "allowed", "external_sharing": "with_permission", "named_fish_logging": "disabled", "removal_vote_required": false, "max_members": 20}'::jsonb
),
(
  uuid_generate_v7(),
  'Strict Privacy',
  'Maximum privacy for exclusive waters. Restricted photo backgrounds, no external sharing, small group size.',
  '{"invitation_policy": "admin_only", "location_detail": "venue_only", "photo_backgrounds": "restricted", "external_sharing": "prohibited", "named_fish_logging": "enabled", "removal_vote_required": false, "max_members": 8}'::jsonb
);
