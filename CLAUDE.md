# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MetaPulse AI (package name `insta_flow`, marketed as "Insta Flow") is an AI-powered Instagram growth/announcer app. It has two halves:

- **Flutter mobile app** at the repo root (`lib/`) — the active client. Targets Android primarily; iOS/web/desktop folders exist but Android is the shipping platform.
- **Node/Express backend** in `backend/` — the active API, **a git submodule** (gitlink at commit, separate `.git`). Deployed to Render at `https://insta-flow-backend.onrender.com`. All AI/Instagram/calendar work goes through it.

### Directories that look active but are NOT

- `flutter_app/` — legacy Flutter project, **excluded from analysis** (`analysis_options.yaml`). Do not edit unless explicitly asked.
- `server/` — older standalone copy of the backend. The live backend is `backend/`. Don't confuse the two.
- `functions/` — Firebase Cloud Functions (`subscriptionCheck.js`), separate deploy.
- `web/web/` — unrelated scaffolding; ignore its `CLAUDE.md`/`AGENTS.md`.
- Root `*.md` files are mostly setup/audit notes. `KEEP_DOCS.md` lists the docs worth keeping; many others are staged for deletion (see `git status`).

## Common commands

### Flutter (run from repo root)
```bash
flutter pub get                 # install deps
flutter run                     # run on connected device/emulator
flutter analyze                 # lint (flutter_lints, see analysis_options.yaml)
flutter test                    # run tests (only test/widget_test.dart exists)
flutter test test/widget_test.dart   # single test file
flutter build apk --release     # release Android build
```
After changing app icons/splash: `dart run flutter_native_splash:create` and `dart run flutter_launcher_icons`.

### Backend (run from `backend/`)
```bash
npm install
npm start                       # node app.js — listens on PORT (default 10000), 0.0.0.0
npm test                        # runs the handful of node test files in tests/ sequentially
npm run audit:ai-routes         # verifies every /ai/* route is guarded by the aiAccess middleware
```
The root `package.json` proxies these: `npm start` / `npm run dev` / `npm run backend` all run the backend via `--prefix backend`.

## Architecture

### Client → backend contract
- Single source of truth for the API base URL is `ApiService.baseUrl` in `lib/services/api_service.dart` (the Render URL). All AI calls funnel through `ApiService`.
- The client authenticates AI requests by sending the Firebase UID in headers `x-user-uid` / `x-user-id`. The backend trusts these headers to load the user (no token verification on the AI path) — usage limits are enforced server-side from Firestore, **never** from frontend counters.
- AI endpoints return a uniform envelope. On any server error, `backend/app.js` error handler returns a **graceful fallback** (`{ success: true, data: <fallback>, fallback: true }`) for `/ai/*` routes instead of a 5xx, so the app degrades rather than breaking.

### Backend structure (`backend/`)
- `app.js` is the entry point (not `index.js`). Mounts routers: `/auth`, `/ai` (gemini), `/instagram`, `/calendar`, `/daily-drop`, `/api` (tts), `/admin`, `/retention`, `/scheduler`, plus `aiAccess` routes at `/`.
- `routes/` → `controllers/` → `services/`. AI generation uses `@google/generative-ai` (Gemini); model from `GEMINI_MODEL` env. Without `GEMINI_API_KEY` the backend runs in MOCK mode.
- Two `node-cron` jobs start with the server: daily viral drop generation (midnight) and Instagram scheduled-post publishing (every minute).
- Startup runs `validateRuntimeGuards()` which **fails fast** if `DEV_SKIP_LIMITS` is set in production and audits that AI routes are guarded.

### AI access / monetization model (the core business logic)
This is enforced in `backend/middleware/aiAccess.js` and mirrored in the client; understand it before touching usage/billing code.
- **Trial**: new users get a 7-day trial = unlimited AI.
- **Free** (after trial): `DAILY_CREDITS_FREE = 2` AI uses/day, reset at **midnight UTC**. Atomic Firestore increment on success.
- **Premium** (Google Play `in_app_purchase`): unlimited.
- Idempotency via `X-Idempotency-Key` (stored in `ai_request_keys`, 48h TTL) so retries don't double-charge credits.
- `DEV_SKIP_LIMITS=true` bypasses all limits for local testing only.
- Client mirror lives in `lib/services/` (`access_control_service`, `ai_usage_control_service`, `premium_service`, `plan_manager`, `play_billing_service`) and `lib/config/monetization_config.dart`. Treat the **server** as authoritative.

### Flutter app structure (`lib/`)
- `main.dart`: wraps everything in `runZonedGuarded`, initializes Firebase first (hardcoded `FirebaseOptions`), then Crashlytics. Heavy services (ads, remote config, notifications, billing) init **non-blocking in the background** via `initServicesInBackground()` — do not move these onto the startup critical path. Routing flows through `SplashGate` → `OnboardingGate` → `ForceUpdateGate` → auth `StreamBuilder`.
- State management: `provider` (`ThemeProvider`, `InstagramProvider`, `ScheduleProvider`).
- `screens/` (~60 screens) = one screen per AI tool/feature; `services/` = business logic and backend/Firebase clients; `config/` = `admin_config`, `monetization_config`, `ai_performance_config`, `app_secrets`, and `firestore_schema.md` (documents the Firestore data model).

### Firebase
- Project `instaflow-f65a0`. Uses Auth, Firestore, Storage, Crashlytics, Analytics, Remote Config, Messaging.
- Security rules in `firestore.rules` / `storage.rules`; indexes in `firestore.indexes.json`. The `users` collection schema (trial/premium/usage fields) is documented in `lib/config/firestore_schema.md`.

## Key conventions

- The Dart package is imported as `package:insta_flow/...` (not `metapulse_ai`), reflecting the `pubspec.yaml` `name: insta_flow`.
- When adding a new AI feature, add the route in `backend/routes`, ensure it sits behind the `aiAccess` middleware (the `audit:ai-routes` check will flag it if not), and add the matching call in `lib/services/api_service.dart`.
- Never weaken server-side usage enforcement to "fix" a client issue — the client counters are advisory only.
