# 🔥 Enable Firebase APIs in Google Cloud Console

## 📋 Project: instaflow-fosao

## 🚀 Method 1: Google Cloud Console (Easiest - Recommended)

### Step 1: Go to APIs Library

1. Visit: [Google Cloud Console APIs Library](https://console.cloud.google.com/apis/library)
2. **Select Project**: `instaflow-fosao` (top dropdown)
3. If project not visible, click dropdown → Select project → Search "instaflow-fosao"

### Step 2: Enable Each API

Search and enable each API:

#### Core Firebase APIs:

1. **Identity Toolkit API**
   - Search: `Identity Toolkit API`
   - Click → **Enable**
   - API: `identitytoolkit.googleapis.com`

2. **Firebase Cloud Messaging API**
   - Search: `Firebase Cloud Messaging API`
   - Click → **Enable**
   - API: `fcm.googleapis.com`

3. **Firebase Remote Config API**
   - Search: `Firebase Remote Config API`
   - Click → **Enable**
   - API: `firebaseremoteconfig.googleapis.com`

4. **Firebase Dynamic Links API**
   - Search: `Firebase Dynamic Links API`
   - Click → **Enable**
   - API: `firebasedynamiclinks.googleapis.com`

5. **Firebase In-App Messaging API**
   - Search: `Firebase In-App Messaging API`
   - Click → **Enable**
   - API: `firebaseinappmessaging.googleapis.com`

6. **Firebase App Check API**
   - Search: `Firebase App Check API`
   - Click → **Enable**
   - API: `firebaseappcheck.googleapis.com`

#### Database & Storage:

7. **Cloud Firestore API**
   - Search: `Cloud Firestore API`
   - Click → **Enable**
   - API: `firestore.googleapis.com`

8. **Cloud Storage for Firebase API**
   - Search: `Cloud Storage for Firebase API`
   - Click → **Enable**
   - API: `firebasestorage.googleapis.com`

#### ML & AI:

9. **Firebase ML API**
   - Search: `Firebase ML API`
   - Click → **Enable**
   - API: `firebaseml.googleapis.com`

10. **Generative Language API** (Gemini)
    - Search: `Generative Language API`
    - Click → **Enable**
    - API: `generativelanguage.googleapis.com`

#### Analytics:

11. **Google Analytics Data API**
    - Search: `Google Analytics Data API`
    - Click → **Enable`
    - API: `analyticsdata.googleapis.com`

12. **Google Analytics Admin API**
    - Search: `Google Analytics Admin API`
    - Click → **Enable`
    - API: `analyticsadmin.googleapis.com`

---

## 🖥️ Method 2: gcloud CLI (Command Line)

### Prerequisites:

1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
2. Authenticate:
   ```bash
   gcloud auth login
   ```
3. Set project:
   ```bash
   gcloud config set project instaflow-fosao
   ```

### Enable All APIs (PowerShell):

```powershell
# List of APIs to enable
$APIS = @(
    "identitytoolkit.googleapis.com",
    "fcm.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "firebasedynamiclinks.googleapis.com",
    "firebaseinappmessaging.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebaseml.googleapis.com",
    "analyticsdata.googleapis.com",
    "analyticsadmin.googleapis.com",
    "firestore.googleapis.com",
    "firebasestorage.googleapis.com",
    "generativelanguage.googleapis.com"
)

# Enable each API
foreach ($api in $APIS) {
    Write-Host "Enabling $api..."
    gcloud services enable $api --project=instaflow-fosao
}

# Check enabled APIs
Write-Host "`n✅ Enabled APIs:"
gcloud services list --enabled --project=instaflow-fosao
```

### Enable All APIs (Bash/Linux/Mac):

```bash
# List of APIs to enable
APIS=(
    "identitytoolkit.googleapis.com"
    "fcm.googleapis.com"
    "firebaseremoteconfig.googleapis.com"
    "firebasedynamiclinks.googleapis.com"
    "firebaseinappmessaging.googleapis.com"
    "firebaseappcheck.googleapis.com"
    "firebaseml.googleapis.com"
    "analyticsdata.googleapis.com"
    "analyticsadmin.googleapis.com"
    "firestore.googleapis.com"
    "firebasestorage.googleapis.com"
    "generativelanguage.googleapis.com"
)

# Enable each API
for api in "${APIS[@]}"; do
    echo "Enabling $api..."
    gcloud services enable $api --project=instaflow-fosao
done

# Check enabled APIs
echo -e "\n✅ Enabled APIs:"
gcloud services list --enabled --project=instaflow-fosao
```

---

## 📋 Complete API List

| API Name | API ID | Purpose |
|----------|--------|---------|
| Identity Toolkit API | `identitytoolkit.googleapis.com` | Authentication |
| Firebase Cloud Messaging API | `fcm.googleapis.com` | Push Notifications |
| Firebase Remote Config API | `firebaseremoteconfig.googleapis.com` | Feature Flags |
| Firebase Dynamic Links API | `firebasedynamiclinks.googleapis.com` | Sharing Links |
| Firebase In-App Messaging API | `firebaseinappmessaging.googleapis.com` | In-App Messages |
| Firebase App Check API | `firebaseappcheck.googleapis.com` | Security |
| Cloud Firestore API | `firestore.googleapis.com` | Database |
| Cloud Storage for Firebase API | `firebasestorage.googleapis.com` | File Storage |
| Firebase ML API | `firebaseml.googleapis.com` | On-Device ML |
| Generative Language API | `generativelanguage.googleapis.com` | Gemini AI |
| Google Analytics Data API | `analyticsdata.googleapis.com` | Analytics Data |
| Google Analytics Admin API | `analyticsadmin.googleapis.com` | Analytics Admin |

---

## ✅ Verification

### Check Enabled APIs:

**Via Console:**
1. Go to: [APIs & Services → Enabled APIs](https://console.cloud.google.com/apis/library?project=instaflow-fosao)
2. You should see all APIs listed as "Enabled"

**Via CLI:**
```bash
gcloud services list --enabled --project=instaflow-fosao
```

---

## 🔗 Quick Links

### Direct API Enable Links:

1. **Identity Toolkit**: https://console.cloud.google.com/apis/library/identitytoolkit.googleapis.com?project=instaflow-fosao
2. **FCM**: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=instaflow-fosao
3. **Remote Config**: https://console.cloud.google.com/apis/library/firebaseremoteconfig.googleapis.com?project=instaflow-fosao
4. **Dynamic Links**: https://console.cloud.google.com/apis/library/firebasedynamiclinks.googleapis.com?project=instaflow-fosao
5. **In-App Messaging**: https://console.cloud.google.com/apis/library/firebaseinappmessaging.googleapis.com?project=instaflow-fosao
6. **App Check**: https://console.cloud.google.com/apis/library/firebaseappcheck.googleapis.com?project=instaflow-fosao
7. **Firestore**: https://console.cloud.google.com/apis/library/firestore.googleapis.com?project=instaflow-fosao
8. **Storage**: https://console.cloud.google.com/apis/library/firebasestorage.googleapis.com?project=instaflow-fosao
9. **Firebase ML**: https://console.cloud.google.com/apis/library/firebaseml.googleapis.com?project=instaflow-fosao
10. **Generative Language**: https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=instaflow-fosao
11. **Analytics Data**: https://console.cloud.google.com/apis/library/analyticsdata.googleapis.com?project=instaflow-fosao
12. **Analytics Admin**: https://console.cloud.google.com/apis/library/analyticsadmin.googleapis.com?project=instaflow-fosao

---

## ⚠️ Important Notes

1. **Billing**: Some APIs may require billing to be enabled
2. **Propagation**: API enablement may take 1-2 minutes to propagate
3. **Permissions**: You need "Project Editor" or "Owner" role
4. **Quotas**: Check API quotas if you hit limits

---

## 🐛 Troubleshooting

### "Permission Denied"

- Ensure you have proper IAM roles
- Check project access

### "API Not Found"

- Verify project ID: `instaflow-fosao`
- Check project exists in Google Cloud Console

### "Billing Required"

- Enable billing for the project
- Some APIs require paid plan

---

**Last Updated**: December 2024  
**Project**: instaflow-fosao

