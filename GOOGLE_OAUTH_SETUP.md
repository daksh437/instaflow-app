# Google OAuth Consent Screen Setup Guide

## Problem
Users are seeing: **"Google hasn't verified this app"** warning when trying to connect Google Calendar.

## Solution: Configure OAuth Consent Screen

### Step 1: Go to Google Cloud Console

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Go to **APIs & Services** → **OAuth consent screen**

### Step 2: Configure OAuth Consent Screen

#### User Type Selection:
- **External** (for public apps) - Select this if you want anyone to use your app
- **Internal** (only for Google Workspace users) - Select this if only your organization will use it

#### App Information:
- **App name**: `InstaFlow` (or your app name)
- **User support email**: `instaflow38@gmail.com` (your email)
- **App logo**: (Optional) Upload your app logo
- **App domain**: (Optional) Your website domain
- **Application home page**: (Optional) Your website URL
- **Application privacy policy link**: (Optional) Your privacy policy URL
- **Application terms of service link**: (Optional) Your terms of service URL
- **Authorized domains**: Add your domain (e.g., `onrender.com`)

#### Developer contact information:
- **Email addresses**: `instaflow38@gmail.com`

Click **"Save and Continue"**

### Step 3: Add Scopes

Click **"Add or Remove Scopes"**

Add these scopes:
- `https://www.googleapis.com/auth/userinfo.email`
- `https://www.googleapis.com/auth/calendar`

Click **"Update"** then **"Save and Continue"**

### Step 4: Add Test Users (For Testing Mode)

If your app is in **Testing** mode:
- Click **"Add Users"**
- Add email addresses of users who should be able to test the app
- Click **"Add"**

**Note**: In Testing mode, only added test users can access the app without seeing the warning.

### Step 5: Publish App (For Production)

To remove the warning for all users:

1. Complete all required fields in Step 2
2. Add privacy policy and terms of service links (required for production)
3. Click **"PUBLISH APP"** button
4. Google will review your app (can take a few days)

**OR** (Quick Solution for Testing):

1. Keep app in **Testing** mode
2. Add all user emails as **Test Users**
3. Test users won't see the warning

### Step 6: Verify OAuth Credentials

1. Go to **APIs & Services** → **Credentials**
2. Check your **OAuth 2.0 Client ID**:
   - **Authorized redirect URIs** should include:
     - `https://insta-flow-backend.onrender.com/auth/callback`
   - **Authorized JavaScript origins** (if needed):
     - `https://insta-flow-backend.onrender.com`

### Step 7: Update Render.com Environment Variables

Make sure these are set in Render.com:
- `GOOGLE_CLIENT_ID` = Your OAuth Client ID
- `GOOGLE_CLIENT_SECRET` = Your OAuth Client Secret
- `GOOGLE_REDIRECT_URI` = `https://insta-flow-backend.onrender.com/auth/callback`

## Quick Fix (Temporary)

If you want users to proceed immediately without waiting for verification:

1. In the warning screen, users should click **"Advanced"**
2. Then click **"Go to InstaFlow (unsafe)"** or **"Continue"**
3. This will allow them to proceed, but they'll see the warning each time

## Best Practice

For production app:
1. Complete OAuth consent screen setup
2. Add privacy policy and terms of service
3. Submit for Google verification
4. Once verified, users won't see the warning

For testing/development:
1. Keep app in Testing mode
2. Add test users
3. Test users won't see warnings

## Important Notes

- **Testing Mode**: Only test users can access without warning
- **Production Mode**: Requires privacy policy and terms of service
- **Verification**: Google may take 1-7 days to verify your app
- **Scopes**: Only request scopes you actually need
- **Security**: Never share your OAuth Client Secret publicly
