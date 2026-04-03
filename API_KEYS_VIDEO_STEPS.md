# 🎥 Video-Style Step-by-Step (Screenshots Ke Saath)

## 🎯 Gemini API Key (5 Minutes)

### Screen 1: Google AI Studio
```
1. Browser kholo
2. https://makersuite.google.com/app/apikey pe jao
3. "Get API Key" button dikhega
```

### Screen 2: Create API Key
```
1. "Create API Key" button click
2. Project dropdown se project select (ya "Create project")
3. API key automatically generate hoga
4. Copy button click karo
```

### Screen 3: Paste in .env
```
File: server/.env
Line: GEMINI_API_KEY=AIzaSyAbc123xyz...
(Paste your key here)
```

---

## 🎯 Google OAuth (10 Minutes)

### Screen 1: Google Cloud Console
```
URL: https://console.cloud.google.com/
1. Top right: Project select karo
2. "New Project" → Name: "InstaFlow" → Create
```

### Screen 2: Enable Calendar API
```
Left Menu: APIs & Services → Library
Search: "Google Calendar API"
Click: "Google Calendar API"
Button: "ENABLE"
```

### Screen 3: OAuth Consent Screen
```
Left Menu: APIs & Services → OAuth consent screen
1. User Type: External → Create
2. App name: InstaFlow
3. Email: Your email
4. Save and Continue (3 times)
```

### Screen 4: Create Credentials
```
Left Menu: APIs & Services → Credentials
1. "+ CREATE CREDENTIALS" button
2. "OAuth client ID" select
3. Application type: Web application
4. Name: InstaFlow Web Client
5. Authorized redirect URIs:
   → ADD URI
   → http://localhost:8080/auth/callback
   → ADD
6. CREATE button
```

### Screen 5: Copy Credentials
```
Popup mein dikhega:
Client ID: 123456789-abc.apps.googleusercontent.com
Client Secret: GOCSPX-abc123xyz...

DONO COPY KARO!
```

### Screen 6: Paste in .env
```
File: server/.env

GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abc123xyz...
```

---

## ✅ Final Steps

1. `.env` file save karo
2. Server restart: `npm run dev`
3. Flutter app mein test karo

---

## 🆘 Help Chahiye?

Agar kisi step mein stuck ho to:
1. Screenshot share karo
2. Error message share karo
3. Main exact help kar dunga!

