# AI Usage Control – Integration Guide

## 1. Backend enforcement

### AI endpoints (all protected)

Every **POST** under `/ai` is wrapped with `requireAiAccess` middleware. No AI route runs without passing the usage check.

| Route | Controller | Usage recorded on |
|-------|------------|--------------------|
| `POST /ai/captions` | generateCaptions | job done (completeJobAndRecordUsage) |
| `POST /ai/calendar` | generateCalendar | job completed |
| `POST /ai/strategy` | generateStrategy | job done |
| `POST /ai/analyze` | analyzeNiche | job done |
| `POST /ai/image-captions` | generateImageCaptions | success response (recordAiUsage in controller) |
| `POST /ai/caption-from-media` | generateCaptionFromMedia | success response |
| `POST /ai/reels-script` | generateReelsScript | job completed |
| `POST /ai/post-ideas` | generatePostIdeas | job completed |
| `POST /ai/hashtags` | generateHashtags | job completed |
| `POST /ai/bio` | generateBio | job completed |
| `POST /ai/hooks` | generateHooks | job completed |
| `POST /ai/comment-reply` | generateCommentReply | job completed |
| `POST /ai/trends` | generateTrends | job completed |
| `POST /ai/carousel` | generateCarousel | job completed |

- **GET /ai/job-status/:jobId** – no middleware (polling only).
- Usage is **only** incremented after a **successful** AI response (no double-count on failure; `usageRecorded` flag per job).

### Trial auto-conversion

- In middleware: if `planType === 'trial'` and `now > trialEndDate`, backend sets `planType = 'free'`, `dailyAiUsed = 0`, `dailyAiDate = today` and saves to Firestore. No frontend needed.

### Daily reset

- Server date only: `todayDateStr()` is `YYYY-MM-DD` in UTC. When `dailyAiDate !== today`, backend resets `dailyAiUsed` to 0 and updates `dailyAiDate` before allowing or counting.

### Race condition safety

- **recordAiUsage(uid, requestId)** runs inside a Firestore **transaction**: read current `dailyAiUsed` / `dailyAiDate`, then update. Prevents double-count.
- **Per-request lock**: each job has `usageRecorded`. `completeJobAndRecordUsage` calls `recordAiUsage` only once per job and sets `job.usageRecorded = true`.

### Test mode

- **DEV_SKIP_LIMITS** (env): set to `true` or `1` to bypass all AI usage checks. Middleware still runs but allows every request and does not record usage.

### Logging

- Structured logs include: `userId`, `planType`, `dailyUsed`, `endpoint`, `allowed`, `error` (when denied). Example:
  `{"event":"ai_access","userId":"...","planType":"free","dailyUsed":1,"creditsLeftToday":1,"allowed":true,"endpoint":"/ai/captions"}`

---

## 2. Firestore user schema (AI usage)

```text
users/{userId}
  planType:        "trial" | "free" | "premium"
  trialStartDate:  Timestamp
  trialEndDate:    Timestamp
  dailyAiUsed:     number
  dailyAiDate:     "YYYY-MM-DD"   (server UTC date)
  totalAiUsed:     number
```

- Set on **signup** (e.g. Cloud Function): `planType = "trial"`, `trialStartDate = now`, `trialEndDate = now + 7 days`, `dailyAiUsed = 0`, `dailyAiDate = today`, `totalAiUsed = 0`.
- Backend is the only writer for `planType`, `dailyAiUsed`, `dailyAiDate`, `totalAiUsed` for usage enforcement.

---

## 3. Flutter: AiUsageControlService

- **Location**: `lib/services/ai_usage_control_service.dart`
- **Usage**:
  - Call **`refresh()`** before showing UI or before an AI action (calls `GET /check-ai-access`).
  - Read **`state.value`** (ValueNotifier<AiAccessState?>): `allowed`, `planType`, `trialDaysLeft`, `creditsLeftToday`, `badgeLabel`.
  - Use **`runWithBackendAiGuard(context, onGenerate: () async { ... })`** so that:
    - If not allowed → paywall is shown and the AI call is not made.
    - If the API returns **DAILY_LIMIT_REACHED** (403) → guard catches it, shows paywall, logs, no retry.

---

## 4. Example protected AI route (Flutter)

```dart
final _aiAccess = AiUsageControlService();

@override
void initState() {
  super.initState();
  _aiAccess.refresh();
}

Future<void> _onGenerateTap() async {
  final result = await runWithBackendAiGuard<YourResultType>(
    context,
    onGenerate: () async {
      setState(() => _isGenerating = true);
      try {
        final data = await _api.someAiMethod(...);
        await _aiAccess.refresh();
        return data;
      } finally {
        if (mounted) setState(() => _isGenerating = false);
      }
    },
    service: _aiAccess,
  );
  if (result == null && mounted) setState(() => _isGenerating = false);
}
```

- **Disable button when blocked**:  
  `onPressed: (_isGenerating || (_aiAccess.lastState != null && !_aiAccess.lastState!.allowed)) ? null : _onGenerateTap`
- **Show badge**: Use **`PlanBadgeFromState(state: _aiAccess.state.value)`** or **`AiCreditBadgeLive(service: _aiAccess)`** in the AppBar or above the button.

---

## 5. UI badge widgets

- **TrialBadge** – `TrialBadge(daysLeft: state.trialDaysLeft)`  
  Use when `planType == 'trial'` and `trialDaysLeft > 0`.
- **CreditsLeftBadge** – `CreditsLeftBadge(creditsLeft: state.creditsLeftToday ?? 0, dailyLimit: state.dailyLimit)`  
  Use for free plan.
- **PremiumBadge** – `PremiumBadge()`  
  Use when `planType == 'premium'`.
- **PlanBadgeFromState** – `PlanBadgeFromState(state: state)`  
  Chooses one of the above from `AiAccessState`.
- **AiCreditBadgeLive** – Refreshes and listens to `AiUsageControlService.state`, shows the appropriate badge.

---

## 6. Failsafe: DAILY_LIMIT_REACHED

- **Backend**: Returns **403** with body `{ "code": "DAILY_LIMIT_REACHED", "message": "..." }`.
- **ApiService**: On 403 with `code == 'DAILY_LIMIT_REACHED'`, throws **DailyLimitReachedException** (no retry).
- **runWithBackendAiGuard**: Catches **DailyLimitReachedException**, shows upgrade dialog, logs (e.g. `logUpgradeDialogShown(source: 'daily_limit_reached_api')`), returns null.

---

## 7. Screens to wire (checklist)

Ensure each AI entry point:

1. Uses **runWithBackendAiGuard** (or equivalent) so the AI call is only made when the backend allows.
2. Disables the main AI button when `!_aiAccess.lastState!.allowed` (or `state != null && !state.allowed`).
3. Shows a plan badge (e.g. **PlanBadgeFromState** or **AiCreditBadgeLive**).
4. Calls **`_aiAccess.refresh()`** in `initState` (or when the screen becomes visible).

| Screen | Entry point | Status |
|--------|-------------|--------|
| AIToolBaseScreen | _generate | ✅ Wired (guard + badge + disable) |
| AICaptionsScreen | _generateCaptions | ✅ Wired |
| NicheAnalysisScreen | _analyzeNiche | Use runWithBackendAiGuard + badge + disable |
| AIStrategyScreen | _generateStrategy | Use runWithBackendAiGuard + badge + disable |
| AICalendarScreen | _generateCalendar | Use runWithBackendAiGuard + badge + disable |
| AICaptionScreen | generate flow | Use runWithBackendAiGuard + badge + disable |
| CaptionGeneratorScreen | _generateCaptions | Use runWithBackendAiGuard + badge + disable |
| AICaptionFromMediaScreen | generateCaptionFromMedia | Use runWithBackendAiGuard + badge + disable |
| ReelScriptScreen | generateReelsScript | Use runWithBackendAiGuard + badge + disable |
| ReelsScriptScreen | generateReelsScript | Use runWithBackendAiGuard + badge + disable |
| HashtagGeneratorScreen | (uses AIToolBaseScreen or direct API) | Via base or add guard |
| Other tools (Bio, Hooks, etc.) | Via AIToolBaseScreen | Covered by base |

---

## 8. Middleware code (reference)

- **Middleware**: `backend/middleware/aiAccess.js`  
  - `requireAiAccess` – checks `x-user-uid`, loads user, enforces trial/free/premium, trial→free conversion, daily reset, logs, returns 403 with `DAILY_LIMIT_REACHED` when blocked.
  - `recordAiUsage(uid, requestId)` – transaction: reset daily if new date, then increment `dailyAiUsed` and `totalAiUsed`.
- **Routes**: `backend/routes/gemini.js` – all POST routes use `requireAiAccess`; GET job-status does not.
- **Controller**: `completeJobAndRecordUsage(jobId, status, data)` – only records usage when status is success and `!data.error` and `!job.usageRecorded`, then sets `job.usageRecorded = true`.
