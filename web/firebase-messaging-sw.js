/* global firebase */

// This is the single root worker and owns push only. Flutter no longer emits a
// cache worker; importing its generated cleanup stub would unregister this
// registration and can delay every application launch.
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

function appUrlFor(data) {
  const fallbackRoute = data.surface === 'team_chat'
    ? '/yorks/team-chat'
    : '/notifications';
  const route = typeof data.route === 'string' && data.route.startsWith('/')
    && !data.route.startsWith('//') && !/[\\\x00-\x20]/.test(data.route)
    ? data.route
    : fallbackRoute;
  const target = new URL(route, 'https://yorks.invalid');
  if (typeof data.notificationId === 'string'
      && /^[0-9a-f-]{36}$/i.test(data.notificationId)) {
    target.searchParams.set('notificationId', data.notificationId);
  }
  const appUrl = new URL(self.registration.scope);
  appUrl.hash = `#${target.pathname}${target.search}`;
  return appUrl.toString();
}

function updateApplicationBadge(data) {
  const parsed = Number.parseInt(data?.unreadCount ?? '', 10);
  const unreadCount = Number.isFinite(parsed)
    ? Math.max(0, Math.min(999, parsed))
    : 0;
  try {
    if (unreadCount > 0 && 'setAppBadge' in self.navigator) {
      return self.navigator.setAppBadge(unreadCount).catch(() => undefined);
    }
    if (unreadCount === 0 && 'clearAppBadge' in self.navigator) {
      return self.navigator.clearAppBadge().catch(() => undefined);
    }
  } catch (_) {
    // Browser, installation and OS notification policy remain authoritative.
  }
  return Promise.resolve();
}

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const badgeUpdate = updateApplicationBadge(data);
  // FCM Webpush notification payloads are displayed by the browser. Only
  // data-only messages need an explicit fallback notification here. The badge
  // is updated in both paths so installed PWAs remain visible while closed.
  if (payload.notification) return badgeUpdate;
  // Only durable events may create a fallback. Console/test pings without an
  // event ID must not create a second, history-less notification surface.
  if (!/^[0-9a-f-]{36}$/i.test(data.notificationId || '')) return badgeUpdate;
  if (data.expiresAt && Date.parse(data.expiresAt) <= Date.now()) return badgeUpdate;
  const title = typeof data.title === 'string' && data.title
    ? data.title
    : data.surface === 'team_chat'
    ? 'New Team Chat message'
    : 'Yorks workflow update';
  const body = typeof data.body === 'string' && data.body
    ? data.body
    : 'A record assigned to you has changed.';
  return Promise.all([
    badgeUpdate,
    self.registration.showNotification(title, {
      body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: data.collapseKey || data.notificationId,
      // Replayed delivery of one outbox UUID replaces the existing notification
      // silently; a genuinely new chat message has a new UUID and still alerts.
      renotify: false,
      requireInteraction: false,
      silent: false,
      vibrate: [120, 60, 120],
      data: { appUrl: appUrlFor(data), yorksFallback: true },
    }),
  ]);
});

self.addEventListener('notificationclick', (event) => {
  // Firebase owns click handling for notification-payload messages (including
  // their fcm_options.link). Handle only the data-only fallback created above.
  if (event.notification?.data?.yorksFallback !== true) return;
  event.notification.close();
  const appUrl = event.notification?.data?.appUrl
    || appUrlFor({ route: '/notifications' });
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    const target = new URL(appUrl, self.registration.scope);
    const origin = new URL(self.registration.scope).origin;
    if (target.origin !== origin) return;
    // Reuse an exact destination. Do not replace a different tab's draft or
    // unsaved worksheet merely because it was the first client returned.
    const existing = windows.find(client => client.url === target.href);
    if (existing && 'focus' in existing) return existing.focus();
    return self.clients.openWindow(target.href);
  })());
});
