# AI Usage Control – Final Hardening Audit Report

## 1. Endpoint coverage audit

### AI-related endpoints (backend)

| Method | Path | Protected | Notes |
|--------|------|-----------|--------|
| GET | /ai/job-status/:jobId | No (excluded) | Read-only polling; no AI generation |
| POST | /ai/captions | Yes | requireAiAccess via router.use() |
| POST | /ai/image-captions | Yes | requireAiAccess |
| POST | /ai/caption-from-media | Yes | requireAiAccess |
| POST | /ai/calendar | Yes | requireAiAccess |
| POST | /ai/strategy | Yes | requireAiAccess |
| POST | /ai/analyze | Yes | requireAiAccess |
| POST | /ai/reels-script | Yes | requireAiAccess |
| POST | /ai/post-ideas | Yes | requireAiAccess |
| POST | /ai/hashtags | Yes | requireAiAccess |
| POST | /ai/bio | Yes | requireAiAccess |
| POST | /ai/hooks | Yes | requireAiAccess |
| POST | /ai/comment-reply | Yes | requireAiAccess |
| POST | /ai/trends | Yes | requireAiAccess |
| POST | /ai/carousel | Yes | requireAiAccess |

**Verification:** All POST /ai/* routes are mounted after `router.use(requireAiAccess)` in `backend/routes/gemini.js`. Only `GET /ai/job-status/:jobId` is excluded.

**Fail-build check:** Run `node backend/scripts/audit-ai-routes.js`. Exits 1 if requireAiAccess is missing or expected POST routes are not present.

---

## 2. Double-response safety

- **recordAiUsage** is only called from:
  - **completeJobAndRecordUsage(jobId, status, data):** when `(status === 'completed' || status === 'done') && !data.error && !job.usageRecorded`. So timeout, partial response, or thrown exception in the controller result in either `updateJob(..., 'done', { error: ... })` (data.error set → no record) or no call to completeJobAndRecordUsage for success.
  - **Sync endpoints (image-captions, caption-from-media):** recordAiUsage(req.uid) is called only on the success path after a successful response; on catch we do not call it.
- **Guarantee:** Usage increments only after a confirmed success payload (job completed with data and no error, or sync handler returned 200 with data). No increment on timeout, partial response, or exception.

---

## 3. Retry / network edge case (idempotency)

- **Job-based flows:** Each job has `job.usageRecorded`. Before calling recordAiUsage, we set `job.usageRecorded = true`. A second completion for the same jobId (e.g. client retry or duplicate callback) will see `job.usageRecorded === true` and will not call recordAiUsage again.
- **Sync flows (image-captions, caption-from-media):** No jobId; client retry can result in two successful responses and two increments. Optional future improvement: accept `x-idempotency-key` and cache “already recorded” for that key (e.g. 24h) to make sync endpoints idempotent.
- **Conclusion:** Idempotency enforced for all job-based AI routes via jobId + usageRecorded. Sync routes documented as non-idempotent for retries.

---

## 4. Trial date safety

- **trialEndDate:** Stored by Cloud Function / signup flow as server timestamp. Backend reads via `user.trialEndDate.toDate()` (Firestore Timestamp) or `new Date(user.trialEndDate)`.
- **Validator / auto-fix:**
  - If `planType === 'trial'` and `trialEndDate` is missing or invalid (NaN): backend sets `planType = 'free'`, resets `dailyAiUsed` / `dailyAiDate`, and persists. Logged as `ai_trial_expired_auto_convert` with reason `trial_fields_missing_invalid`.
  - If `planType === 'trial'` and `now > trialEndDate`: backend sets `planType = 'free'`, resets daily fields, persists. Logged as `ai_trial_expired_auto_convert` with reason `trial_expired_converted`.
- **Result:** Invalid or missing trial fields safely convert to free plan; no crash, no stuck trial.

---

## 5. Daily limit edge case

- **Reset after many days inactive:** When `dailyAiDate !== today` (server UTC date), backend resets `dailyAiUsed = 0` and `dailyAiDate = today` before allowing or counting. So any user (active or inactive for days) gets a fresh daily count on the new calendar day.
- **Negative credits:** `creditsLeftToday = Math.max(0, Math.min(DAILY_CREDITS_FREE, DAILY_CREDITS_FREE - dailyAiUsed))`. `dailyAiUsed` is clamped to `[0, DAILY_CREDITS_FREE]` when reading. So creditsLeftToday is always in [0, DAILY_CREDITS_FREE].
- **Clamp:** In getAiAccess, `dailyAiUsed = Math.max(0, Math.min(DAILY_CREDITS_FREE, Math.floor(dailyAiUsed)))` so stored corruption or legacy values cannot produce negative or out-of-range usage for the limit check.

---

## 6. Premium override safety

- In **getAiAccess:** If `planType === 'premium'` we return `allowed: true` and never check or decrement credits.
- In **recordAiUsage:** Inside the transaction we read the user doc; if `planType` (or derived from subscriptionPlan) is `'premium'`, we return without performing any update. So no credit decrement or daily/total increment ever runs for premium users.
- **Result:** Premium users skip all limits and no credit decrement is applied.

---

## 7. Frontend bypass protection

- **runWithBackendAiGuard** is used on: AIToolBaseScreen, AICaptionsScreen, NicheAnalysisScreen.
- **requirePremiumOrTrial** (Firestore-based guard) is still used on: reel_script_screen, ai_caption_screen, caption_generator_screen, hashtag_generator_screen. These do not call the backend /check-ai-access before the AI request; backend still enforces limits, but UI state (e.g. disable button, badge) may not match backend if only the old guard is used.
- **Lint warning:** In `lib/services/api_service.dart`, a comment above `checkAiAccess()` states: “All AI generation methods must ONLY be called after runWithBackendAiGuard or equivalent. Do not call them directly from UI without the guard.”
- **Missing guard list (recommend migration to runWithBackendAiGuard for consistency):**
  - `lib/screens/reel_script_screen.dart` – uses requirePremiumOrTrial
  - `lib/screens/ai_caption_screen.dart` – uses requirePremiumOrTrial
  - `lib/screens/caption_generator_screen.dart` – uses requirePremiumOrTrial
  - `lib/screens/hashtag_generator_screen.dart` – uses requirePremiumOrTrial

---

## 8. Analytics events

**Backend (structured logs):**

- `ai_access` – generic access check
- `ai_allowed` – access allowed (premium / trial / free with credits)
- `ai_blocked_limit` – DAILY_LIMIT_REACHED
- `ai_trial_active` – user on valid trial
- `ai_trial_expired_auto_convert` – trial expired or invalid → free
- `ai_usage_recorded` – usage incremented (with userId, requestId)

**Flutter (AnalyticsService):**

- `logAiAllowed(planType, creditsLeftToday)`
- `logAiBlockedLimit()`
- `logAiTrialActive(trialDaysLeft)`
- `logAiTrialExpiredAutoConvert()`
- `logAiUsageRecorded(toolId)` – client-side funnel only; count is authoritative on backend

---

## 9. Admin debug tool

- **POST /admin/reset-credits** – Body/query: `uid`. Resets `dailyAiUsed = 0`, `dailyAiDate = today`. Requires `x-admin-key` = ADMIN_SECRET/ADMIN_KEY.
- **POST /admin/set-premium** – Body/query: `uid`. Sets `planType = 'premium'`. Requires admin key.
- **POST /admin/set-plan-type** – Body/query: `uid`, `planType` (`trial` | `free` | `premium`). For support/debug. Requires admin key.

**Middleware exports:** `resetUserAiUsage` is an alias for `resetCredits`.

---

## 10. Test scenarios (automated / manual checklist)

| # | Scenario | Steps | Expected |
|---|----------|--------|----------|
| 1 | New user trial | Create new user (signup); call GET /check-ai-access; call POST /ai/captions | planType trial, allowed true, trialDaysLeft ≤ 7; job created; after success, dailyAiUsed 1 |
| 2 | Trial expired | Set user trialEndDate in past; call GET /check-ai-access; call POST /ai/captions | planType free, daily reset if new day; allowed if dailyAiUsed < 2 |
| 3 | Free user limit hit | Set planType free, dailyAiUsed 2, dailyAiDate today; call POST /ai/captions | 403 DAILY_LIMIT_REACHED; no recordAiUsage |
| 4 | Premium unlimited | Set planType premium; call POST /ai/captions multiple times | 200 each time; recordAiUsage does not update user doc |
| 5 | Retry same job | Create job; complete job twice (e.g. duplicate callback or test) | recordAiUsage called once (usageRecorded guard) |
| 6 | Date rollover | Set dailyAiDate to yesterday (UTC); call GET /check-ai-access then POST /ai/captions | dailyAiUsed reset to 0; then 1 after success |
| 7 | DEV_SKIP_LIMITS | Set DEV_SKIP_LIMITS=true; call POST /ai/captions without uid / with any uid | 200; no recordAiUsage; logs reason DEV_SKIP_LIMITS |
| 8 | Missing trial fields | Set planType trial, remove trialEndDate; call GET /check-ai-access | planType updated to free; allowed true; log ai_trial_expired_auto_convert |
| 9 | Invalid trialEndDate | Set planType trial, trialEndDate invalid (e.g. bad timestamp) | Treated as missing; convert to free |
| 10 | Premium no increment | planType premium; POST /ai/captions success | 200; Firestore dailyAiUsed/totalAiUsed unchanged |

---

## Patched middleware (summary)

- **Trial:** Auto-fix missing/invalid trialEndDate → free; existing trial-expired conversion kept.
- **Daily:** Clamp `dailyAiUsed` when reading; clamp `creditsLeftToday` to [0, DAILY_CREDITS_FREE].
- **Premium:** recordAiUsage skips update when user is premium.
- **Analytics:** All access/usage paths log with event names ai_allowed, ai_blocked_limit, ai_trial_active, ai_trial_expired_auto_convert, ai_usage_recorded.
- **Admin:** setPlanType(uid, planType) and POST /admin/set-plan-type added; resetUserAiUsage alias added.

## Edge-case fixes applied

- Double-count: job.usageRecorded guard in completeJobAndRecordUsage (unchanged; verified).
- Success-only: recordAiUsage only on success path; premium skip in recordAiUsage (new).
- Trial safety: validate trialEndDate; convert to free if missing/invalid (new).
- Daily: clamp dailyAiUsed and creditsLeftToday (new).
- Idempotency: documented; job flows use jobId + usageRecorded; sync flows documented as non-idempotent for retries.

No unrelated AI logic was refactored; only verification, sealing loopholes, and edge-case protection were added.
