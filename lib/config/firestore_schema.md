# Firestore schema (freemium)

## Collection: `users`

| Field | Type | Description |
|-------|------|-------------|
| `email` | string | User email |
| `displayName` | string? | Display name |
| `photoURL` | string? | Photo URL |
| `createdAt` | Timestamp | Account creation |
| `preferences` | map | User preferences |
| `subscriptionPlan` | string | `'trial'` \| `'free'` \| `'pro'` \| `'ultra'` |
| **Trial (7-day)** | | |
| `isTrialActive` | bool | True while trial is active |
| `trialStart` / `trialStartDate` | Timestamp | Trial start = first login |
| `trialEnd` / `trialEndDate` | Timestamp | Trial end = start + 7 days |
| `trialExpired` | bool? | Set true when trial ends |
| **Premium (Google Play)** | | |
| `isPremium` | bool | Has active subscription |
| `premiumPlan` | string | `'none'` \| `'basic'` \| `'pro'` |
| `premiumDuration` | string | `'none'` \| `'1m'` \| `'3m'` \| `'6m'` \| `'12m'` |
| `premiumExpiry` | Timestamp? | Subscription expiry |
| **Free tier usage** | | |
| `dailyFreeUsedCount` | number | AI uses today (reset daily) |
| `lastUsageDate` | Timestamp? | Last AI use date (for daily reset) |

## Subcollection: `users/{uid}/tool_usage`

Per-tool analytics (optional). Key = `toolId`.

| Field | Type |
|-------|------|
| `toolId` | string |
| `count` | number |
| `lastUsed` | Timestamp |
| `lastDate` | string (YYYY-MM-DD) |

## Access rules

- **New user (first login):** Create doc with `trialStartDate` = now, `trialEndDate` = now + 7 days, `dailyFreeUsedCount` = 0, `lastUsageDate` = null. No ads during trial; unlimited AI.
- **After trial:** `isTrialActive` = false. Max 2 AI uses per day; `dailyFreeUsedCount` and `lastUsageDate` reset when date changes. Show ads.
- **Premium:** `isPremium` = true, `premiumExpiry` in future. Unlimited AI; no ads.
