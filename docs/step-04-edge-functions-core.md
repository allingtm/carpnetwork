# Carp.Network — Step 04: Edge Functions — Invites, Members, RevenueCat, Push

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 7, 5.2, 9.3, 2.5, 2.4.1  
**Depends on:** Step 02 (database with RLS), Step 00 (Supabase project)  
**Commit after completion:** `git commit -m "Step 04: Edge Functions — invite-create, invite-redeem, member-remove, revenucat-webhook, push-send"`

---

## Context

These Edge Functions handle the server-side logic that requires service role access. They run in Deno on Supabase's infrastructure. The Flutter app calls them via `Supabase.instance.client.functions.invoke()`.

---

## Task 1: Shared Utilities

Create shared modules that all Edge Functions import:

**`supabase/functions/_shared/supabase-admin.ts`:**
- Creates and exports a Supabase client with the service role key
- Used for operations that bypass RLS (inserting records, reading across groups)

**`supabase/functions/_shared/cors.ts`:**
- CORS headers for preflight requests
- Handle OPTIONS method and return appropriate headers

**`supabase/functions/_shared/rate-limit.ts`:**
- Wrapper around Upstash Redis for rate limiting
- Function: `rateLimit(key: string, limit: number, windowSeconds: number): Promise<{ allowed: boolean, remaining: number }>`
- Uses `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` from env

**`supabase/functions/_shared/validate.ts`:**
- Helper that takes a Zod schema and request body, returns parsed data or throws 400
- Always use `schema.strict()` to reject unknown fields

**`supabase/functions/_shared/auth.ts`:**
- Helper to extract and verify JWT from request
- Returns user object or throws 401
- Helper to check if user is admin of a specific group (queries group_memberships with service role)

**Reference:** Spec Sections 7.1, 7.3

---

## Task 2: invite-create Edge Function

Create `supabase/functions/invite-create/index.ts`.

**Auth:** JWT required (default config)  
**Rate limit:** 5 per IP per 15 minutes

**Input (Zod strict):**
```typescript
{
  group_id: string (uuid)
}
```

**Logic:**
1. Verify JWT, extract user_id
2. Verify user is admin of the specified group (query group_memberships)
3. Generate 128-bit invite token: `crypto.getRandomValues(new Uint8Array(16))`, encode as base64url
4. Calculate expiry: 7 days from now
5. Insert into `invitations` table: `group_id`, `invited_by`, `invite_token`, `expires_at`, `status: 'pending'`
6. Return `{ invite_token, invite_url: "https://carp.network/invite/{token}", expires_at }`

**Error responses:**
- 401: Invalid/missing JWT
- 403: Not an admin of the group
- 429: Rate limited
- 400: Invalid input

**Reference:** Spec Sections 2.5, 7.1, 7.3, 17.5

---

## Task 3: invite-redeem Edge Function

Create `supabase/functions/invite-redeem/index.ts`.

**Auth:** JWT required  
**Rate limit:** 5 per IP per 15 minutes

**Input (Zod strict):**
```typescript
{
  invite_token: string
}
```

**Logic:**
1. Verify JWT, extract user_id
2. Look up invitation by token (service role, bypass RLS)
3. Validate: status must be 'pending', expires_at must be in the future, return generic error if not found/expired/used (don't leak info)
4. Check user is not already a member of the group
5. In a single transaction:
   - Create `group_memberships` record: `group_id`, `user_id`, `role: 'member'`, `joined_at: now()`
   - Update invitation: `status: 'accepted'`, `redeemed_by: user_id`, `redeemed_at: now()`
6. Return `{ group_id, group_name }`

**Reference:** Spec Sections 2.5, 7.1, 17.5

---

## Task 4: member-remove Edge Function

Create `supabase/functions/member-remove/index.ts`.

**Auth:** JWT required  
**Rate limit:** 10 per IP per 15 minutes

**Input (Zod strict):**
```typescript
{
  group_id: string (uuid),
  user_id: string (uuid)  // the member to remove
}
```

**Logic:**
1. Verify JWT, extract caller's user_id
2. Verify caller is admin of the group
3. Verify target user is a non-admin member of the group (cannot remove admins)
4. Verify caller is not trying to remove themselves (use "leave group" instead)
5. In a single transaction:
   - Insert into `removed_members`: `group_id`, `user_id`, `removed_by`, `export_available_until: now() + 30 days`
   - Delete from `group_memberships` where `group_id` and `user_id` match
6. Invalidate the removed user's sessions: call `supabase.auth.admin.signOut(userId)` (Spec Section 5.3.1)
7. Optionally send push notification to the removed user
8. Return `{ success: true }`

**Reference:** Spec Sections 2.4.1, 2.15, 7.1, 5.3.1

---

## Task 5: revenucat-webhook Edge Function

Create `supabase/functions/revenucat-webhook/index.ts`.

**Auth:** JWT NOT required (verify_jwt = false in config.toml). Authenticated via webhook secret.  
**No rate limiting (webhook).**

**Logic:**
1. Verify `Authorization` header matches `Bearer ${REVENUCAT_WEBHOOK_SECRET}`
2. Parse the RevenueCat webhook payload
3. Extract `app_user_id` (this is the Supabase user UUID) and `event.type`
4. Check idempotency: look up `event.id` in `stripe_events` table. If exists, return 200 (already processed).
5. Insert into `stripe_events` with the event_id, type, and full payload.
6. Map event type to subscription state change:

| RevenueCat Event | subscription_status | subscription_grace_until |
|---|---|---|
| INITIAL_PURCHASE | `active` | NULL |
| RENEWAL | `active` | NULL |
| CANCELLATION | `active` (until period end) | NULL |
| BILLING_ISSUE | `past_due` | period_end + 7 days |
| EXPIRATION | `inactive` | NULL |

7. Update the `users` table: `subscription_status`, `subscription_period_end`, `subscription_grace_until`
8. Return 200 on success

**Reference:** Spec Sections 5.2, 7.1

---

## Task 6: push-send Edge Function

Create `supabase/functions/push-send/index.ts`.

**Auth:** Service role only (called by other Edge Functions, not by clients directly). Verify the caller is another Edge Function by checking a shared internal secret or by checking that the Authorization header contains the service role key.

**Input:**
```typescript
{
  user_ids: string[],   // target users
  title: string,
  body: string,
  data?: Record<string, string>  // navigation data (route, group_id, etc.)
}
```

**Logic:**
1. Query `user_devices` table for all FCM tokens belonging to the target user_ids
2. Authenticate to FCM using the **FCM HTTP v1 API** (NOT the deprecated server key):
   - Parse `FCM_SERVICE_ACCOUNT_JSON` from env
   - Generate a short-lived OAuth2 access token using the service account credentials (sign a JWT with the service account's private key, exchange for access token via Google OAuth2 endpoint)
3. For each device token, send via FCM HTTP v1 API:
   ```
   POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send
   Authorization: Bearer {access_token}
   {
     "message": {
       "token": "{fcm_token}",
       "notification": { "title": "...", "body": "..." },
       "data": { ... },
       "android": { "priority": "high" },
       "apns": { "payload": { "aps": { "sound": "default" } } }
     }
   }
   ```
4. Handle errors: if FCM returns 404 or UNREGISTERED for a token, delete that device record from `user_devices` (stale token cleanup)
5. Return `{ sent: number, failed: number }`

**CRITICAL:** The legacy FCM Server Key API was shut down in July 2024. Do NOT use `FCM_SERVER_KEY`. Use the HTTP v1 API with service account OAuth2 authentication.

**Reference:** Spec Sections 9.3, 14.2

---

## Task 7: push-silent-upload Edge Function

Create `supabase/functions/push-silent-upload/index.ts`.

**Auth:** Service role only.

This function sends a silent push notification to trigger iOS background photo uploads. It is called when an offline catch report syncs to Supabase and has pending photos.

**Input:**
```typescript
{
  user_id: string,
  catch_report_id: string
}
```

**Logic:**
1. Query `user_devices` for the user's iOS tokens (platform = 'ios')
2. Send a silent push via FCM with `content-available: 1`:
   ```json
   {
     "message": {
       "token": "{fcm_token}",
       "data": { "action": "upload_photos", "catch_report_id": "..." },
       "apns": {
         "payload": {
           "aps": { "content-available": 1 }
         }
       }
     }
   }
   ```
3. No visible notification — iOS wakes the app silently for ~30 seconds

**Reference:** Spec Section 4.2.1

---

## Validation

1. `supabase functions serve invite-create` — starts without error
2. `supabase functions serve invite-redeem` — starts without error
3. `supabase functions serve member-remove` — starts without error
4. `supabase functions serve revenucat-webhook` — starts without error
5. `supabase functions serve push-send` — starts without error
6. `supabase functions serve push-silent-upload` — starts without error
7. Shared utilities import correctly in all functions
8. All Zod schemas use `.strict()` to reject unknown fields
