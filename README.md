# Carp.Network

Private fishing group mobile app (iOS + Android).

## Tech Stack

- **Mobile:** Flutter (Dart)
- **Backend:** Supabase (Postgres, Auth, Edge Functions, Realtime)
- **Storage:** Cloudflare R2
- **Background Jobs:** Inngest (Node.js)
- **Payments:** RevenueCat

## Project Structure

```
carp-network/
  app/                    ← Flutter mobile app
  supabase/
    migrations/           ← SQL migration files
    functions/            ← Edge Functions (Deno/TypeScript)
    config.toml           ← Local dev configuration
    seed.sql              ← Seed data
  inngest/                ← Background jobs (Node.js/TypeScript)
  marketing/              ← Static marketing site (later)
  docs/                   ← Step-by-step build guides
```

## Setup

### Prerequisites

- Flutter 3.22+ / Dart 3.4+
- Node.js 18+
- Docker (for Supabase local dev)
- Supabase CLI

### Flutter App

```bash
cd app
cp .env.json.example .env.json
# Fill in your Supabase and RevenueCat keys
flutter pub get
flutter run
```

### Supabase

```bash
cd supabase
cp .env.local.example .env.local
# Fill in your secrets
supabase start
```

### Inngest

```bash
cd inngest
npm install
npx tsc --noEmit  # Type check
```
