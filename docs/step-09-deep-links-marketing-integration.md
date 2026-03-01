# Carp.Network — Step 09: Deep Links, Marketing Site, and Integration

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md` — Sections 1.3, 5.1, 17.11  
**Depends on:** Steps 03–08 (all Flutter features and Edge Functions built)  
**Commit after completion:** `git commit -m "Step 09: Deep links, marketing site, .well-known, CORS"`

---

## Context

This step ties everything together: deep link configuration so invite URLs and magic links work, the marketing site for SEO and app store links, and R2 CORS configuration.

---

## Task 1: Android Deep Links (App Links)

Update `app/android/app/src/main/AndroidManifest.xml`:

Add intent filter for verified links:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="carp.network" />
</intent-filter>
```

Create the Digital Asset Links file template:
```json
// marketing/public/.well-known/assetlinks.json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.carpnetwork.app",
    "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
  }
}]
```

**Reference:** Spec Section 17.11

---

## Task 2: iOS Deep Links (Universal Links)

Add Associated Domains entitlement in Xcode:
- `applinks:carp.network`

Create the Apple App Site Association template:
```json
// marketing/public/.well-known/apple-app-site-association
{
  "applinks": {
    "details": [{
      "appIDs": ["YOUR_TEAM_ID.com.carpnetwork.app"],
      "paths": ["/invite/*", "/auth/callback"]
    }]
  }
}
```

The `.well-known` files must be served from the marketing site root with content-type `application/json` and no redirects.

**Reference:** Spec Section 17.11

---

## Task 3: GoRouter Deep Link Handling

Verify GoRouter handles incoming deep links correctly:

- `/invite/:token` — extract token, navigate to invite landing screen, validate token, show join/register flow
- `/auth/callback` — handle Supabase magic link PKCE callback. Supabase Flutter SDK handles this automatically if the scheme/host match.

Test the flows:
1. Open `https://carp.network/invite/abc123` → app opens to invite landing with token `abc123`
2. Click magic link email → app opens, session established, navigates to dashboard

**Reference:** Spec Sections 5.1, 6.1

---

## Task 4: Marketing Site

Create a static marketing site in `marketing/`:

Use **Astro** (lightweight, fast static site generator) or plain HTML. 5 pages:

**1. Landing page (`/`):**
- Hero section: "Private fishing groups for serious anglers"
- Feature highlights: offline catch logging, group management, AI insights
- App Store and Google Play badge links
- Screenshots/mockups

**2. Invite landing (`/invite/[token]`):**
- Client-side JavaScript that:
  1. Attempts deep link: `window.location.href = "https://carp.network/invite/{token}"` (Universal Link / App Link)
  2. After a short timeout, falls back to app store redirect based on user agent
  3. Shows "Download Carp.Network to join this fishing group" with store links

**3. Privacy policy (`/privacy`):**
- Standard privacy policy covering: data collected, how it's used, EXIF stripping, data retention, GDPR rights

**4. Terms of service (`/terms`):**
- Standard terms covering: acceptable use, subscription billing, account termination

**5. Support/contact (`/support`):**
- Contact email, FAQ

Serve `.well-known/assetlinks.json` and `.well-known/apple-app-site-association` from the site root.

**Reference:** Spec Section 1.3

---

## Task 5: R2 CORS Configuration

Document the R2 CORS configuration that needs to be applied via Wrangler CLI:

```json
{
  "AllowedOrigins": ["*"],
  "AllowedMethods": ["GET", "PUT"],
  "AllowedHeaders": ["Content-Type"],
  "MaxAgeSeconds": 3600
}
```

**Note from Spec Section 4.2.1:** R2 CORS for mobile apps requires `"*"` origin since mobile HTTP clients do not send an Origin header. Security is enforced via presigned URL expiry and Redis key validation, not CORS.

---

## Task 6: Cron Edge Functions

Create the remaining cron Edge Functions:

**`supabase/functions/cron-reconcile/index.ts`:**
- Auth: `CRON_SECRET` header
- Runs daily at 04:00 UTC
- Reconcile `groups.member_count` against actual `group_memberships` count
- Prune `stripe_events` older than 90 days
- Prune `user_devices` where `last_active_at` < 60 days ago (stale device tokens)

Update `supabase/config.toml` cron scheduling (or document as Supabase Dashboard cron job configuration):
```
cron-reconcile: 0 4 * * * (daily at 04:00 UTC)
cron-ai-processing: */15 * * * * (every 15 minutes — Phase 2, stub only)
```

**Reference:** Spec Sections 7.1, 7.2

---

## Validation

1. Marketing site builds and serves locally
2. `.well-known/assetlinks.json` serves with correct content-type
3. `.well-known/apple-app-site-association` serves with correct content-type
4. Deep link `/invite/:token` opens app to invite landing (test on device)
5. Magic link callback establishes session
6. `cron-reconcile` Edge Function serves without error
7. Flutter analyze passes
