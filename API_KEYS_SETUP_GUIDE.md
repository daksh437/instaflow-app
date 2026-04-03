# 🔑 Real API Keys Setup Guide (Hindi/English)

## 📋 Part 1: Gemini API Key (AI Features Ke Liye)

### Step 1: Google AI Studio Mein Jao
1. Browser kholo aur ye link open karo: **https://makersuite.google.com/app/apikey**
2. Ya Google search karo: "Google AI Studio API key"

### Step 2: Google Account Se Login
- Apne Google account se login karo
- Agar pehli baar ho to "Get API Key" button click karo

### Step 3: API Key Generate Karo
1. "Create API Key" button click karo
2. Project select karo (ya naya project create karo)
3. API key automatically generate ho jayega
4. **Important:** API key ko copy kar lo (ye sirf ek baar dikhega!)

### Step 4: API Key Ko Server Mein Add Karo
1. `server` folder mein jao
2. `.env` file kholo (Notepad ya VS Code mein)
3. Ye line find karo:
   ```
   GEMINI_API_KEY=YOUR_GEMINI_API_KEY
   ```
4. Apni API key paste karo:
   ```
   GEMINI_API_KEY=AIzaSyAbc123xyz... (apni actual key)
   ```
5. File save karo

### ✅ Gemini API Key Ready!

---

## 📅 Part 2: Google OAuth Credentials (Calendar Connect Ke Liye)

### Step 1: Google Cloud Console Mein Jao
1. Browser mein ye link open karo: **https://console.cloud.google.com/**
2. Google account se login karo

### Step 2: Project Create/Select Karo
1. Top pe "Select a project" dropdown click karo
2. "New Project" click karo
3. Project name do: "InstaFlow" (ya kuch bhi)
4. "Create" click karo
5. Project select karo

### Step 3: Google Calendar API Enable Karo
1. Left sidebar mein "APIs & Services" → "Library" pe click karo
2. Search box mein type karo: **"Google Calendar API"**
3. "Google Calendar API" select karo
4. "Enable" button click karo
5. Wait karo (10-20 seconds)

### Step 4: OAuth Consent Screen Setup
1. Left sidebar mein "APIs & Services" → "OAuth consent screen" pe click karo
2. User Type: **"External"** select karo → "Create" click karo
3. App information fill karo:
   - **App name:** InstaFlow
   - **User support email:** Apna email
   - **Developer contact:** Apna email
4. "Save and Continue" click karo
5. Scopes: Default hi theek hai → "Save and Continue"
6. Test users: Abhi skip kar sakte ho → "Save and Continue"
7. Summary: "Back to Dashboard" click karo

### Step 5: OAuth 2.0 Client ID Create Karo
1. Left sidebar mein "APIs & Services" → "Credentials" pe click karo
2. Top pe "+ CREATE CREDENTIALS" button click karo
3. "OAuth client ID" select karo
4. Application type: **"Web application"** select karo
5. Name do: "InstaFlow Web Client"
6. **Authorized redirect URIs** section mein:
   - "ADD URI" click karo
   - Ye add karo: `http://localhost:8080/auth/callback`
   - "ADD" click karo
7. "CREATE" button click karo

### Step 6: Credentials Copy Karo
1. Popup mein **Client ID** aur **Client Secret** dikhega
2. **Client ID** copy karo (yeh dikhega: `123456789-abc.apps.googleusercontent.com`)
3. **Client Secret** copy karo (yeh dikhega: `GOCSPX-abc123xyz...`)
4. **Important:** Client Secret sirf ek baar dikhega! Copy kar lo

### Step 7: Server Mein Add Karo
1. `server` folder mein `.env` file kholo
2. Ye lines find karo aur update karo:
   ```
   GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID
   GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET
   ```
3. Apni values paste karo:
   ```
   GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=GOCSPX-abc123xyz...
   ```
4. File save karo

### ✅ Google OAuth Ready!

---

## 🚀 Step 8: Server Restart Karo

1. Terminal mein server folder mein jao:
   ```bash
   cd server
   ```

2. Server restart karo:
   ```bash
   # Pehle stop karo (Ctrl+C)
   # Phir start karo
   npm run dev
   ```

3. Agar sab theek hai to ye message dikhega:
   ```
   🚀 InstaFlow backend running on http://localhost:8080
   ```

---

## ✅ Testing

### Gemini API Test:
1. Flutter app mein "AI Captions" screen pe jao
2. Topic enter karo aur "Generate Captions" click karo
3. **Real AI captions** aayengi! (Mock data nahi)

### Google Calendar Test:
1. Flutter app mein "Connect Google Calendar" pe jao
2. "Connect Google Calendar" button click karo
3. Browser open hoga, Google account se login karo
4. Permissions allow karo
5. App mein wapas aao - "Connected!" dikhega

---

## 🐛 Troubleshooting

### Gemini API Error:
- ✅ API key sahi paste kiya hai?
- ✅ `.env` file mein `GEMINI_API_KEY=` ke baad space nahi hai na?
- ✅ Server restart kiya?

### Google OAuth Error:
- ✅ Client ID aur Secret sahi paste kiye?
- ✅ Redirect URI exactly `http://localhost:8080/auth/callback` hai?
- ✅ Google Calendar API enable hai?
- ✅ OAuth consent screen setup ho gaya?

### "Connection refused" Error:
- ✅ Server running hai? (`npm run dev`)
- ✅ Port 8080 free hai?
- ✅ `.env` file sahi location mein hai? (`server/.env`)

---

## 📝 Quick Checklist

- [ ] Gemini API key generate kiya
- [ ] Gemini API key `.env` mein add kiya
- [ ] Google Cloud project create kiya
- [ ] Google Calendar API enable kiya
- [ ] OAuth consent screen setup kiya
- [ ] OAuth Client ID create kiya
- [ ] Client ID aur Secret `.env` mein add kiye
- [ ] Redirect URI add kiya: `http://localhost:8080/auth/callback`
- [ ] Server restart kiya
- [ ] Flutter app mein test kiya

---

## 🎉 Done!

Ab aapke paas real API keys hain aur sab features properly kaam karenge!

Agar koi step mein problem aaye to batao, main help kar dunga! 🚀

