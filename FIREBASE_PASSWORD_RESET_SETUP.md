# Firebase Password Reset Email Setup Guide

## Problem
Password reset email nahi aa raha hai after clicking "Send Reset Link".

## Solution: Firebase Console Configuration

### Step 1: Enable Email/Password Provider

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **instaflow-f65a0**
3. Go to **Authentication** → **Sign-in method**
4. Check if **Email/Password** is enabled:
   - If disabled, click on it
   - Click **Enable**
   - Click **Save**

### Step 2: Check Authorized Domains

1. In **Authentication** → **Settings** → **Authorized domains**
2. Make sure these domains are listed:
   - `localhost` (for development)
   - Your custom domain (if any)
   - Firebase automatically adds: `[project-id].web.app` and `[project-id].firebaseapp.com`

### Step 3: Check Email Templates

1. Go to **Authentication** → **Templates**
2. Click on **Password reset** template
3. Check if email template is configured properly
4. You can customize the email subject and body here
5. Make sure the template is enabled

### Step 4: Check Email Action URL

1. In **Password reset** template
2. Check the **Action URL**:
   - It should point to your app or a web page where users can reset password
   - Default: Uses Firebase Hosting or can be custom

### Step 5: Check Spam Folder

- Password reset emails sometimes go to spam folder
- Check spam/junk folder in your email
- Check email is correct

### Step 6: Check Firebase Project Status

1. Make sure Firebase project is active
2. Check billing status (even Free tier should work)
3. Check if there are any service limits

## Common Issues

### Issue 1: Email/Password Provider Not Enabled
**Solution:** Enable it in Authentication → Sign-in method

### Issue 2: Email in Spam Folder
**Solution:** Check spam folder, mark as not spam

### Issue 3: Invalid Email Address
**Solution:** Make sure email is registered in Firebase Authentication

### Issue 4: Too Many Requests
**Solution:** Wait a few minutes and try again

### Issue 5: Email Template Not Configured
**Solution:** Check Authentication → Templates → Password reset

## Testing Steps

1. Make sure user account exists with that email
2. Try sending reset email
3. Check email inbox (and spam folder)
4. Check Firebase Console → Authentication → Users to verify email exists
5. Check Firebase Console logs for any errors

## Debugging

If still not working, check:
1. Firebase Console → Authentication → Users - Verify email exists
2. Firebase Console logs for errors
3. App console logs for Firebase errors
4. Network tab for API calls

## Alternative: Manual Email Testing

You can test by creating a user first in Firebase Console:
1. Authentication → Users → Add user
2. Enter email and password
3. Then try password reset from app

