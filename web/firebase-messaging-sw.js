/* global firebase, clients */

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

function yorksRoute(data) {
  const route = typeof data?.route === 'string' ? data.route : '';
  // Never let a transport payload use the notification click to navigate to a
  // different origin. Yorks route payloads are internal, absolute paths.
  return route.startsWith('/') && !route.startsWith('//')
    ? route
    : '/notifications';
}

messaging.onBackgroundMessage((payload) => {
  // Requested operational diagnostic: visible in the device browser's console.
  // Business payloads must remain non-commercial by the Yorks notification
  // contract; protected values never travel in FCM data.
  console.log('[fcm][background]', payload);

  const notification = payload.notification;
  if (!notification) return undefined;
  return self.registration.showNotification(notification.title || 'Yorks AC. & Ref.', {
    body: notification.body || '',
    data: { route: yorksRoute(payload.data) },
    icon: 'icons/Icon-192.png',
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = yorksRoute(event.notification.data);
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const windowClient of windows) {
        if ('focus' in windowClient) {
          windowClient.navigate(route);
          return windowClient.focus();
        }
      }
      return clients.openWindow(route);
    }),
  );
});
