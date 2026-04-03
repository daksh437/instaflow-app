# ⚡ Quick Final Setup Checklist

## 🔥 Firebase Console (5 minutes)

### 1. Authentication Setup

**Go to**: https://console.firebase.google.com/project/instaflow-fosao/authentication

1. **Enable Email/Password**:
   - Sign-in method → Email/Password → Enable → Save

2. **Enable Google Sign-In**:
   - Sign-in method → Google → Enable → Save
   - **Add SHA-1**: `E7:25:43:51:E3:91:B2:82:90:9E:2D:C4:33:69:5D:B8:8F:27:36:2D`

3. **Authorized Domains**:
   - Settings → Authorized domains
   - Ensure: `localhost`, `insta-flow-backend.onrender.com`

---

## 🚀 Deploy Firestore Rules

```bash
# Switch to correct project
firebase use instaflow-fosao

# If project not found, add it:
firebase use --add
# Then select instaflow-fosao

# Deploy rules
firebase deploy --only firestore:rules

# Deploy storage rules (if needed)
firebase deploy --only storage:rules
```

---

## 📱 Test Flutter App

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run app
flutter run

# Test:
# 1. Sign up with email
# 2. Sign in with Google
# 3. Create/read Firestore data
# 4. Upload to Storage
```

---

## ✅ Quick Verification

### Firebase Console:
- [ ] Authentication → Email/Password enabled
- [ ] Authentication → Google enabled + SHA-1 added
- [ ] Firestore → Rules deployed
- [ ] Storage → Rules deployed

### Flutter App:
- [ ] App builds successfully
- [ ] Email/Password sign up works
- [ ] Google Sign-In works
- [ ] Firestore read/write works

### Backend:
- [ ] Health check: https://insta-flow-backend.onrender.com/health
- [ ] AI endpoints working

---

**Time**: ~10 minutes  
**Status**: Ready for production! 🚀
