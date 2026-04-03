# 🔥 Deploy Firestore Indexes using Firebase CLI

## 📋 Current Status

- ✅ Firebase CLI installed (v14.12.0)
- ✅ `firestore.indexes.json` configured
- ✅ `firebase.json` configured correctly

## 🔍 Step 1: Check Current Project

```bash
firebase use
```

This shows which Firebase project is currently active.

## 🔄 Step 2: Switch to Correct Project

You need to use your new Firebase project: **instaflow-f65a0**

### Option A: If project exists in list

```bash
firebase use instaflow-f65a0
```

### Option B: If project not in list, add it

```bash
firebase use --add
```

Then select your project from the list.

### Option C: Use available project

If `instaflow-f65a0` is not in the list, check available projects:

```bash
firebase projects:list
```

Then switch to the correct one (might be `instaflow-d0a42`):

```bash
firebase use instaflow-d0a42
```

## 📊 Step 3: Verify Indexes Configuration

Your `firestore.indexes.json` contains 3 indexes for the "posts" collection:

1. **Index 1**: `userId` + `status` + `scheduledTime`
2. **Index 2**: `status` + `scheduledTime`
3. **Index 3**: `userId` + `createdAt`

These are already configured correctly!

## 🚀 Step 4: Deploy Indexes

### Deploy only indexes:

```bash
firebase deploy --only firestore:indexes
```

### Or deploy everything (rules + indexes):

```bash
firebase deploy --only firestore
```

## ✅ Step 5: Verify Deployment

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **instaflow-f65a0**
3. Go to **Firestore Database** → **Indexes** tab
4. You should see your indexes being built (may take a few minutes)

## 📋 Indexes Being Deployed

### Index 1: Posts by User, Status, and Scheduled Time
```json
{
  "collectionGroup": "posts",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "scheduledTime", "order": "ASCENDING" }
  ]
}
```

**Use case**: Query posts by user, filter by status, sort by scheduled time

### Index 2: Posts by Status and Scheduled Time
```json
{
  "collectionGroup": "posts",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "scheduledTime", "order": "ASCENDING" }
  ]
}
```

**Use case**: Query all posts by status, sort by scheduled time

### Index 3: Posts by User and Created Time
```json
{
  "collectionGroup": "posts",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "ASCENDING" }
  ]
}
```

**Use case**: Query posts by user, sort by creation date

## ⏱️ Build Time

- Indexes typically build in **2-5 minutes**
- You'll see status: **Building** → **Enabled**
- Queries will work once indexes are **Enabled**

## 🐛 Troubleshooting

### Error: "No project active"

```bash
firebase use <project-id>
```

### Error: "Project not found"

1. Check available projects:
   ```bash
   firebase projects:list
   ```

2. Add project if needed:
   ```bash
   firebase use --add
   ```

### Error: "Permission denied"

1. Make sure you're logged in:
   ```bash
   firebase login
   ```

2. Verify you have access to the project

### Indexes not building

1. Check Firestore is enabled in Firebase Console
2. Verify database is created
3. Check for errors in Firebase Console → Indexes tab

## 📝 Quick Command Reference

```bash
# Check current project
firebase use

# List all projects
firebase projects:list

# Switch project
firebase use instaflow-f65a0

# Deploy indexes
firebase deploy --only firestore:indexes

# Deploy rules + indexes
firebase deploy --only firestore

# Login (if needed)
firebase login
```

## ✅ Success Indicators

After deployment, you should see:

```
✔  firestore: indexes deployed successfully
```

In Firebase Console → Firestore → Indexes:
- Status: **Building** (then **Enabled**)
- All 3 indexes visible

---

**Last Updated**: December 2024  
**Project**: instaflow-f65a0

