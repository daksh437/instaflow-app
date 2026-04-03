# ⚡ Google OAuth Quick Setup (5 Minutes)

## 🚀 Fast Steps:

### 1. Google Cloud Console
👉 https://console.cloud.google.com/

### 2. Project Create
- "New Project" → Name: `InstaFlow` → Create

### 3. Enable Calendar API
- APIs & Services → Library
- Search: "Google Calendar API"
- Click: "ENABLE"

### 4. OAuth Consent Screen
- APIs & Services → OAuth consent screen
- User Type: External → Create
- App name: `InstaFlow`
- Email: Your email
- Save and Continue (3 times)

### 5. Create OAuth Client
- APIs & Services → Credentials
- "+ CREATE CREDENTIALS" → "OAuth client ID"
- Application type: **Web application**
- Name: `InstaFlow Web Client`
- **Authorized redirect URIs:**
  ```
  http://localhost:8080/auth/callback
  ```
- CREATE

### 6. Copy Credentials
- **Client ID:** Copy karo
- **Client Secret:** Copy karo (sirf ek baar dikhega!)

### 7. Add to .env
File: `server/.env`
```
GOOGLE_CLIENT_ID=paste_client_id_here
GOOGLE_CLIENT_SECRET=paste_client_secret_here
```

### 8. Restart Server
```bash
cd server
npm run dev
```

### 9. Test
- Flutter app → "Connect Google Calendar"
- Login → Allow → Done! ✅

---

## 🆘 Stuck?

Detailed guide: `GOOGLE_OAUTH_SETUP.md`

