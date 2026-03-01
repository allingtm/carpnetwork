-- Custom Access Token Hook
-- Adds subscription claims to JWT when Supabase mints tokens
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  claims jsonb;
  user_sub_status text;
  user_period_end timestamptz;
  user_grace_until timestamptz;
BEGIN
  claims := event->'claims';

  SELECT u.subscription_status, u.subscription_period_end, u.subscription_grace_until
  INTO user_sub_status, user_period_end, user_grace_until
  FROM public.users u
  WHERE u.id = (event->>'user_id')::uuid;

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
