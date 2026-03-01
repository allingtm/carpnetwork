# Carp.Network — Step 00: Project Scaffolding

**Read the spec file first:** `Carp-Network-Design-Specification-v1.5-Final.md`  
**Commit after completion:** `git commit -m "Step 00: Project scaffolding"`

---

## Context

You are building Carp.Network — a private fishing group mobile app (iOS + Android). The tech stack is Flutter + Supabase + Cloudflare R2 + Inngest. This is step 00: creating the project skeleton that everything else builds on.

## Project Structure

```
carp-network/
  app/                    ← Flutter mobile app
  supabase/
    migrations/           ← SQL migration files (numbered)
    functions/            ← Edge Functions (Deno/TypeScript)
    config.toml           ← Edge Function configuration
    seed.sql              ← Seed data (rule_sets)
  inngest/                ← Inngest background jobs (Node.js)
  marketing/              ← Static marketing site (later)
```

---

## Task 1: Flutter Project

Create a new Flutter project called `carp_network` in the `app/` directory. Set up the 4-layer architecture with these folders:

```
lib/
  presentation/       ← Screens, widgets, routing, theme
    screens/
    widgets/
    routing/
    theme/
  application/        ← Providers, services (business logic)
    providers/
    services/
  domain/             ← Models, enums, interfaces
    models/
    enums/
  data/               ← Repositories, data sources
    auth/
    catches/
    groups/
    messages/
    photos/
    notifications/
    subscription/
```

Add these dependencies to `pubspec.yaml`:

**Core:** `supabase_flutter`, `flutter_riverpod`, `riverpod_annotation`, `go_router`  
**Offline:** `brick_offline_first_with_supabase`, `drift`, `sqflite`  
**Storage:** `flutter_secure_storage`  
**Image:** `image_picker`, `image`, `cached_network_image`  
**Push:** `firebase_messaging`, `firebase_core`  
**Payments:** `purchases_flutter`  
**Background:** `workmanager`, `connectivity_plus`  
**Utils:** `intl`, `uuid`, `freezed_annotation`, `json_annotation`  
**Dev dependencies:** `build_runner`, `freezed`, `json_serializable`, `riverpod_generator`, `drift_dev`

Create `.env.json.example`:
```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key",
  "REVENUCAT_APPLE_API_KEY": "appl_your-key",
  "REVENUCAT_GOOGLE_API_KEY": "goog_your-key"
}
```

Set minimum SDK: Flutter 3.22+ / Dart 3.4+. Target iOS 15+ and Android API 26+.

Add `.env.json` to `.gitignore`.

**Reference:** Spec Sections 1.1, 14.1

---

## Task 2: Supabase Project

Initialise a Supabase project in `supabase/` using `supabase init`.

Configure `config.toml` with Edge Function JWT settings — by default all functions require JWT. Add an exception for the RevenueCat webhook:

```toml
[functions.revenucat-webhook]
verify_jwt = false
```

Create `supabase/.env.local.example` with all secrets from the spec:

```
SUPABASE_SERVICE_ROLE_KEY=
REVENUCAT_WEBHOOK_SECRET=
CLOUDFLARE_R2_ACCESS_KEY_ID=
CLOUDFLARE_R2_SECRET_ACCESS_KEY=
CLOUDFLARE_R2_BUCKET_NAME=
CLOUDFLARE_R2_ENDPOINT=
CLOUDFLARE_R2_PUBLIC_URL=
ANTHROPIC_API_KEY=
WEATHER_API_KEY=
RESEND_API_KEY=
CRON_SECRET=
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=
INNGEST_SIGNING_KEY=
FCM_SERVICE_ACCOUNT_JSON=
```

**Reference:** Spec Sections 1.2, 14.2, 7.1

---

## Task 3: Inngest Project

Create a Node.js project in `inngest/` with TypeScript:

```bash
mkdir inngest && cd inngest && npm init -y
```

Add dependencies: `inngest`, `sharp`, `@supabase/supabase-js`, `@aws-sdk/client-s3`

Create:
- `src/client.ts` — exports the Inngest client instance
- `src/functions/` — empty directory for job handlers
- `tsconfig.json` — target ES2022, strict mode, outDir: dist

**Reference:** Spec Section 1.2

---

## Task 4: Root Configuration

Create at the repo root:
- `.gitignore` covering Flutter, Node, Supabase, .env files
- `README.md` with project overview and setup instructions

---

## Validation

Run these checks — all must pass before moving on:

1. `cd app && flutter pub get` — succeeds with no errors
2. `cd supabase && supabase start` — starts successfully (requires Docker)
3. `cd inngest && npm install && npx tsc --noEmit` — succeeds
4. Project structure matches the tree above
