# 🔥 Firebase Console Setup Guide - instaflow-f65a0

## ✅ Current Status
- ✅ Project created: `instaflow-f65a0`
- ✅ Android app registered (package: `com.Instaflow.app`)
- ✅ `google-services.json` updated in app
- ✅ Flutter code updated

## 📋 Required Setup Steps

### 1. Enable Authentication
**Path**: Authentication → Get started

**Enable these sign-in methods:**
- ✅ **Email/Password** (Enable)
- ✅ **Google Sign-In** (Enable)
  - Configure OAuth consent screen
  - Add authorized domains if needed

**Steps:**
1. Go to Firebase Console → Authentication
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password"
5. Enable "Google"
   - Add support email
   - Configure OAuth consent screen

---

### 2. Create Firestore Database
**Path**: Firestore Database → Create database

**Steps:**
1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Choose mode:
   - **Production mode** (recommended) - Secure rules
   - **Test mode** (development) - Open for 30 days
4. Select location (choose closest to your users)
5. Click "Enable"

**Security Rules:**
Copy the rules from `firestore.rules` in your project and paste in:
Firestore Database → Rules tab

**Current Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isResourceOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow get, list: if isUserDocOwner(userId);
      allow create: if isUserDocOwner(userId);
      allow update: if isUserDocOwner(userId);
      allow delete: if false;
      
      match /devices/{deviceId} {
        allow read, write: if isResourceOwner(userId);
      }
    }

    match /posts/{postId} {
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // ... (see firestore.rules for complete rules)
  }
}
```

---

### 3. Create Storage Bucket
**Path**: Storage → Get started

**Steps:**
1. Go to Firebase Console → Storage
2. Click "Get started"
3. Choose mode:
   - **Production mode** (recommended)
   - **Test mode** (development)
4. Select location (same as Firestore recommended)
5. Click "Done"

**Security Rules:**
Copy the rules from `storage.rules` in your project and paste in:
Storage → Rules tab

**Current Rules:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() {
      return request.auth != null;
    }

    function isResourceOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    match /user_uploads/{userId}/{allPaths=**} {
      allow read: if isResourceOwner(userId);
      allow write: if isResourceOwner(userId);
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

### 4. Cloud Messaging (FCM)
**Path**: Cloud Messaging

**Status**: ✅ Already configured via `google-services.json`

**Optional Setup:**
- Upload APNs key for iOS (if you have iOS app)
- Configure notification settings

---

### 5. Firestore Indexes (Optional)
**Path**: Firestore Database → Indexes

If you have composite queries, create indexes. Your project has `firestore.indexes.json` with:
- `posts` collection indexes for userId, status, scheduledTime queries

**Steps:**
1. Go to Firestore Database → Indexes
2. Click "Create Index"
3. Or import from `firestore.indexes.json`:
   ```bash
   firebase deploy --only firestore:indexes
   ```

---

## ❌ NOT NEEDED (Skip These)

### Firebase Hosting
- **Skip this** - Only for web apps
- Your Flutter app doesn't need hosting

### Cloud Functions
- Only if you plan to use serverless functions
- Can be added later if needed

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Authentication enabled (Email/Password, Google)
- [ ] Firestore database created
- [ ] Firestore security rules applied
- [ ] Storage bucket created
- [ ] Storage security rules applied
- [ ] Cloud Messaging configured
- [ ] Test app: `flutter run`

---

## 🧪 Test Your App

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run app
flutter run

# Test features:
# 1. Sign up with email
# 2. Sign in with Google
# 3. Create/read Firestore data
# 4. Upload to Storage
# 5. Receive notifications
```

---

## 📞 Troubleshooting

### Authentication Issues
- Check if Email/Password is enabled
- Verify Google Sign-In OAuth consent screen
- Check package name matches: `com.Instaflow.app`

### Firestore Issues
- Verify database is created
- Check security rules
- Verify user is authenticated

### Storage Issues
- Verify bucket is created
- Check security rules
- Verify user is authenticated

---

**Project**: instaflow-f65a0
**Last Updated**: December 2024

