# InstaFlow Backend (Google OAuth + Gemini + Google Calendar)

## Features
- Google OAuth 2.0 (Calendar + email scopes)
- Gemini AI: captions, 7-day calendar, strategy
- Google Calendar event creation
- CORS enabled (Flutter/web)
- JSON token store (replaceable with DB)

## Structure
```
server/
  app.js
  package.json
  env.example
  routes/
    auth.js
    gemini.js
    calendar.js
  controllers/
    authController.js
    geminiController.js
    calendarController.js
  utils/
    oauthClient.js
    geminiClient.js
    tokenStore.js
  data/
    tokens.json
```

## Env
Copy `env.example` → `.env` and fill:
```
PORT=8080
BASE_URL=http://localhost:8080
CLIENT_BASE_URL=http://localhost:5173
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=http://localhost:8080/auth/callback
GEMINI_API_KEY=...
GEMINI_MODEL=gemini-1.5-flash
TOKEN_STORE_PATH=./data/tokens.json
```

## Install & Run
```bash
cd server
npm install
npm run dev   # or npm start
```

## API
- `GET /auth/url` → { url }
- `GET /auth/callback?code=...&userId=...` → saves refresh_token
- `GET /auth/status?userId=...` → { connected }

- `POST /ai/captions`  body { topic, tone }
- `POST /ai/calendar`  body { topic, days }
- `POST /ai/strategy`  body { niche }

- `POST /calendar/create` body { userId, title, description, startDateTime, endDateTime }

Responses: `{ success: true/false, data?/error? }`

## Notes
- Gemini model via `@google/generative-ai`
- Replace tokenStore with Firestore/MySQL in production
- Keep secrets out of VCS; use HTTPS + rate limiting in prod
# InstaFlow Backend — AI Growth Strategy + Calendar + Google Calendar Scheduling

Stack: **Node.js + Express + Google OAuth + Google Calendar API + Gemini AI**

## Features
- Google OAuth (Calendar scope) — connect user Google account
- Gemini AI endpoints: captions, weekly content calendar, growth strategy
- Google Calendar event creation for scheduled posts
- CORS enabled for Flutter/Web
- Token storage via JSON file (can swap to Firestore)

## Folder Structure
```
server/
  app.js
  package.json
  env.example
  routes/
    auth.js
    gemini.js
    calendar.js
  controllers/
    authController.js
    geminiController.js
    calendarController.js
  utils/
    oauthClient.js
    geminiClient.js
    tokenStore.js
  tokenStore.json (auto-created)
```

## Env Setup
Copy `env.example` → `.env` and fill:
```
PORT=8080
CLIENT_BASE_URL=http://localhost:5173
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=http://localhost:8080/auth/callback
GEMINI_API_KEY=...
TOKEN_STORE_PATH=./tokenStore.json
```

### Google Cloud OAuth
- Create OAuth Client (Web)
- Authorized redirect URI → `http://localhost:8080/auth/callback`
- Scopes used: `userinfo.email`, `calendar`
- Set `prompt=consent` and `access_type=offline` to ensure `refresh_token`

## Install & Run
```bash
cd server
npm install
npm run dev   # or npm start
```

## API Endpoints

### Auth
- `GET /auth/url` → { url }
- `GET /auth/callback?code=...&userId=optional` → saves refresh_token
- `GET /auth/status?userId=optional` → { connected: bool }

### Gemini AI
- `POST /ai/captions` body `{ topic, tone }` → 8 captions + 5 hashtags
- `POST /ai/calendar` body `{ topic, days }` → array of day objects
- `POST /ai/strategy` body `{ niche }` → strategy JSON

### Google Calendar
- `POST /calendar/create` body `{ userId, title, description, startDateTime, endDateTime }`

All responses: `{ success: true/false, data?/error? }`

## Notes
- Gemini model: `gemini-1.5-flash` via `@google/generative-ai`
- Token store: JSON file; swap to Firestore by replacing `tokenStore.js`
- Remember to keep API keys and client secrets out of version control.

