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
  // FCM Webpush notification payloads are displayed by the browser. Only
  // data-only messages need an explicit fallback notification here.
  if (payload.notification) return;
  const data = payload.data || {};
  const title = typeof data.title === 'string' && data.title
    ? data.title
    : 'Yorks workflow update';
  const body = typeof data.body === 'string' && data.body
    ? data.body
    : 'A record assigned to you has changed.';
  const route = typeof data.route === 'string' && data.route.startsWith('/')
    && !data.route.startsWith('//')
    ? data.route
    : '/notifications';
  return self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.notificationId || undefined,
    data: { route, yorksFallback: true },
  });
});

self.addEventListener('notificationclick', (event) => {
  // Firebase owns click handling for notification-payload messages (including
  // their fcm_options.link). Handle only the data-only fallback created above.
  if (event.notification?.data?.yorksFallback !== true) return;
  event.notification.close();
  const route = event.notification?.data?.route || '/notifications';
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    for (const windowClient of windows) {
      if ('focus' in windowClient) {
        if ('navigate' in windowClient) await windowClient.navigate(route);
        return windowClient.focus();
      }
    }
    return self.clients.openWindow(route);
  })());
});
