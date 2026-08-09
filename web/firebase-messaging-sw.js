/* global firebase */

// Keep Flutter's generated offline/cache handlers in the same root worker.
// A browser permits only one service worker for this scope, so a separate FCM
// registration would otherwise replace Flutter's cache worker on each launch.
importScripts('flutter_service_worker.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBs5vRHMyZXegfAQa-us3FyiCvhJVBQm7A',
  appId: '1:1003807035272:web:206e34aee93941c68ff43d',
  authDomain: 'yorks-48c40.firebaseapp.com',
  messagingSenderId: '1003807035272',
  projectId: 'yorks-48c40',
  storageBucket: 'yorks-48c40.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // Requested operational diagnostic: visible in the device browser's console.
  // Business payloads must remain non-commercial by the Yorks notification
  // contract; protected values never travel in FCM data.
  console.log('[fcm][background]', payload);
});
