# Carp.Network — Step 02: RLS Policies and JWT Custom Claims Hook

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 3, 5.3  
**Depends on:** Step 01 complete (all tables exist)  
**Commit after completion:** `git commit -m "Step 02: RLS policies and custom access token hook"`

---

## Context

RLS is the primary security boundary for Carp.Network. Even if application code has a bug that omits a group_id filter, the database must reject the query. This step creates the policies that enforce data isolation between groups.

---

## Task 1: Private Schema and Helper Function

Create `supabase/migrations/00004_rls_policies.sql`.

**First**, create the private schema and the security definer helper function:

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

**CRITICAL:** This function must be in a non-public schema. Functions in the public schema are callable via Supabase's RPC endpoint — a SECURITY DEFINER function there would be a security hole.

**Reference:** Spec Section 3.2

---

## Task 2: Enable RLS on All Tables

In the same migration file, enable RLS on every public table:

```sql
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
```

---

## Task 3: Create Policies for Each Table

Follow the set-based pattern from **Spec Section 3.1**. Key rules:

- **Always** wrap `auth.uid()` in `(SELECT auth.uid())` — this triggers PostgreSQL's initPlan optimizer (57–61% improvement)
- **Always** specify `TO authenticated` on all policies
- **Never** use a helper function that accepts group_id as parameter (causes N+1)
- All SELECT policies on soft-delete tables must include `AND deleted_at IS NULL`
- All UPDATE policies must include `WITH CHECK` preventing group_id/user_id modification

Create policies for each table per **Spec Section 3.3**:

**users:** Users can SELECT and UPDATE their own record only (`id = (SELECT auth.uid())`). INSERT handled by auth trigger.

**stripe_events:** No user access. Service role only.

**rule_sets:** All authenticated users can SELECT (rule_sets are global reference data). No INSERT/UPDATE/DELETE for users.

**groups:** SELECT where `id IN (SELECT private.user_group_ids())`. INSERT for authenticated users (creating a group). UPDATE by admin only (check membership role).

**group_memberships:** SELECT where `group_id IN (SELECT private.user_group_ids())`. INSERT/DELETE restricted by application logic (Edge Functions use service role).

**invitations:** SELECT where `group_id IN (SELECT private.user_group_ids())`. INSERT/UPDATE via application logic.

**venues:** SELECT for all authenticated users (venues are shared). INSERT for authenticated users. UPDATE for authenticated users.

**catch_reports:** SELECT where `group_id IN (SELECT private.user_group_ids()) AND deleted_at IS NULL`. INSERT where `group_id IN (SELECT private.user_group_ids())`. UPDATE/DELETE (soft) only where `user_id = (SELECT auth.uid()) AND deleted_at IS NULL`.

**catch_report_photos:** SELECT where `group_id IN (SELECT private.user_group_ids())`. INSERT where `group_id IN (SELECT private.user_group_ids())`. DELETE only where the related catch_report's user_id matches.

**venue_notes:** SELECT/INSERT/UPDATE where `group_id IN (SELECT private.user_group_ids())`. UPDATE WITH CHECK that group_id cannot be changed.

**sessions:** SELECT/INSERT where `group_id IN (SELECT private.user_group_ids())`. UPDATE/DELETE where `created_by = (SELECT auth.uid())`.

**session_attendees:** SELECT where session's group is in user's groups. INSERT/UPDATE/DELETE where `user_id = (SELECT auth.uid())`.

**messages:** SELECT where `group_id IN (SELECT private.user_group_ids()) AND deleted_at IS NULL`. INSERT where `group_id IN (SELECT private.user_group_ids())`. UPDATE (soft delete) where `user_id = (SELECT auth.uid())`.

**ai_intelligence_items:** SELECT where `group_id IN (SELECT private.user_group_ids())`. No INSERT/UPDATE/DELETE for users (service role only from AI jobs).

**removed_members:** SELECT only where `user_id = (SELECT auth.uid())`.

**exports:** SELECT only where `user_id = (SELECT auth.uid())`. INSERT by authenticated users for their own exports.

**user_devices:** SELECT/INSERT/UPDATE/DELETE where `user_id = (SELECT auth.uid())`.

**Reference:** Spec Sections 3.1, 3.2, 3.3, 3.4

---

## Task 4: Custom Access Token Hook

Create `supabase/migrations/00005_custom_access_token_hook.sql`.

This PostgreSQL function is called by Supabase whenever it mints a JWT. It adds subscription claims to the token:

```sql
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  claims jsonb;
  user_sub_status text;
  user_period_end timestamptz;
  user_grace_until timestamptz;
BEGIN
  claims := event->'claims';

  SELECT subscription_status, subscription_period_end, subscription_grace_until
  INTO user_sub_status, user_period_end, user_grace_until
  FROM public.users
  WHERE id = (event->>'user_id')::uuid;

  claims := jsonb_set(claims, '{app_metadata,subscription_status}', to_jsonb(COALESCE(user_sub_status, 'inactive')));
  
  IF user_period_end IS NOT NULL THEN
    claims := jsonb_set(claims, '{app_metadata,subscription_period_end}', to_jsonb(user_period_end));
  END IF;
  
  IF user_grace_until IS NOT NULL THEN
    claims := jsonb_set(claims, '{app_metadata,subscription_grace_until}', to_jsonb(user_grace_until));
  END IF;

  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;

-- Grant execute to supabase_auth_admin (required for the hook)
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook FROM authenticated, anon, public;

-- Grant the hook function access to read from users table
GRANT SELECT ON public.users TO supabase_auth_admin;
```

**Note:** After deploying, you must enable this hook in the Supabase Dashboard under Authentication → Hooks → Custom Access Token. This is a manual dashboard configuration step, not something migrations can do.

**Reference:** Spec Section 5.3

---

## Validation

1. `supabase db reset` succeeds with zero errors
2. All tables have RLS enabled: `SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = false;` returns 0 rows
3. The custom_access_token_hook function exists: `SELECT proname FROM pg_proc WHERE proname = 'custom_access_token_hook';` returns 1 row
4. The private.user_group_ids() function exists: `SELECT proname FROM pg_proc WHERE proschema = 'private' AND proname = 'user_group_ids';`
