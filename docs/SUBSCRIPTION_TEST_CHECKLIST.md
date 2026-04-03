# Subscription architecture — test checklist

Use this list to verify the production-grade subscription flow after refactor.

## Backend (single source of truth)

- [ ] **New user** → 7 days unlimited (trial); `planType: 'trial'`, `trialEndDate` set; no daily count.
- [ ] **Trial active** → unlimited AI; `/check-ai-access` returns `planType: 'trial'`, `dailyLimit: null`, `allowed: true`.
- [ ] **Trial expired** → becomes free; Firestore `planType` updated to `'free'`; 2 AI/day enforced.
- [ ] **Premium active** → unlimited; `planType: 'premium'`, `dailyLimit: null`; no usage increment.
- [ ] **Premium expired** → becomes free (by `resolvePlan`); 2 AI/day.
- [ ] **Free at 2 uses** → next request returns 403 `DAILY_LIMIT_REACHED`; no `?? 2` in response.
- [ ] **Usage increment** → only when `planType === 'free'`; trial/premium never increment `dailyAiUsed`.

## Frontend (no UI mismatch)

- [ ] **Trial** → Home shows "Free Trial — X days left"; never shows "X / 2" or free counter.
- [ ] **Premium** → Home shows "Premium — Unlimited"; Profile shows "Premium active until DD MMM YYYY" when expiry set.
- [ ] **Free** → Home shows "X / 2 remaining today"; Profile shows "Free Plan — 2 AI per day".
- [ ] No `planType ?? 'free'` or `dailyLimit ?? 2` in Flutter; all from backend/PlanManager.
- [ ] PlanManager used for Home top card and Profile subscription card; AiUsageControlService still used for pre-AI-call refresh and AI screens; both read from same backend response.

## Firestore

- [ ] Client cannot write `planType`, `trialStartDate`, `trialEndDate`, `premiumStartDate`, `premiumExpiry`, `dailyAiUsed`, `dailyAiDate`.
- [ ] Normalized schema only (legacy fields removed by script if run): `planType`, `trialStartDate`, `trialEndDate`, `premiumStartDate`, `premiumExpiry`, `dailyAiUsed`, `dailyAiDate`, `createdAt`.

## Run cleanup (optional)

From `backend/`:

```bash
node scripts/firestoreUserSchemaCleanup.js
```

This removes legacy fields from `users` docs. Other profile data is untouched.
