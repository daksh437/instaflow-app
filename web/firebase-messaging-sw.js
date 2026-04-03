/* eslint-disable no-undef */
// Placeholder service worker for Firebase Cloud Messaging.
// Update the config object with your Firebase project values.

importScripts("https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js");

// TODO: Replace with your Firebase web app configuration.
firebase.initializeApp({
  apiKey: "REPLACE_ME",
  authDomain: "REPLACE_ME.firebaseapp.com",
  projectId: "REPLACE_ME",
  storageBucket: "REPLACE_ME.appspot.com",
  messagingSenderId: "REPLACE_ME",
  appId: "1:REPLACE_ME:web:REPLACE_ME",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title ?? "MetaPulse AI";
  const notificationOptions = {
    body: payload.notification?.body ?? "",
    data: payload.data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

