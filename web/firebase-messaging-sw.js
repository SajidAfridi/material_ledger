/* global firebase */

// This is the single root worker and owns push only. Flutter no longer emits a
// cache worker; importing its generated cleanup stub would unregister this
// registration and can delay every application launch.
// Firebase forwards a push to any visible window, even when the browser is
// unfocused. Observe that gap without stopping its authorized onMessage refresh.
// Install click ownership first: durable alerts must never navigate a different
// tab away from an unsaved worksheet or draft.
self.addEventListener('push', observeVisibleUnfocusedPush);
self.addEventListener('notificationclick', handleNotificationClick);

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

function isDurableNotification(data) {
  return data !== null && typeof data === 'object' && !Array.isArray(data)
    && typeof data.notificationId === 'string'
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(data.notificationId);
}

function isFreshDurableNotification(data) {
  if (!isDurableNotification(data) || typeof data.expiresAt !== 'string') return false;
  const expiresAt = Date.parse(data.expiresAt);
  return Number.isFinite(expiresAt) && expiresAt > Date.now();
}

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
      && isDurableNotification(data)) {
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

function showDurableFallback(data) {
  if (!isFreshDurableNotification(data)) return Promise.resolve();
  const title = typeof data.title === 'string' && data.title
    ? data.title
    : data.surface === 'team_chat'
    ? 'New Team Chat message'
    : 'Yorks workflow update';
  const body = typeof data.body === 'string' && data.body
    ? data.body
    : 'A record assigned to you has changed.';
  return Promise.all([
    updateApplicationBadge(data),
    self.registration.showNotification(title, {
      body,
      lang: ['en', 'ar', 'ur', 'hi'].includes(data.language) ? data.language : 'en',
      dir: ['ar', 'ur'].includes(data.language) ? 'rtl' : 'ltr',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: typeof data.collapseKey === 'string' && data.collapseKey
        ? data.collapseKey
        : data.notificationId,
      // Related updates replace the existing record/conversation notification
      // silently instead of creating an unbounded stack.
      renotify: false,
      requireInteraction: false,
      silent: false,
      vibrate: [120, 60, 120],
      data: { appUrl: appUrlFor(data), yorksFallback: true },
    }),
  ]);
}

async function sameOriginWindows() {
  const origin = new URL(self.registration.scope).origin;
  const windows = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  return windows.filter(client => {
    try {
      return new URL(client.url).origin === origin;
    } catch (_) {
      return false;
    }
  });
}

function observeVisibleUnfocusedPush(event) {
  let payload;
  try {
    payload = event.data?.json();
  } catch (_) {
    event.stopImmediatePropagation();
    return;
  }
  const data = payload?.data;
  if (!isFreshDurableNotification(data)) {
    // SDK notification payloads otherwise display before onBackgroundMessage.
    // Reject console/history-less and expired messages at this shared boundary.
    event.stopImmediatePropagation();
    return;
  }
  event.waitUntil((async () => {
    // The first lookup runs alongside Firebase's visible-client decision.
    // Recheck immediately before presentation, including a focus/visibility
    // transition during that lookup. SDK display races share the same tag and
    // renotify:false, so they replace one alert rather than adding a stack.
    const initialWindows = await sameOriginWindows();
    const windows = await sameOriginWindows();
    const wasVisible = initialWindows.some(client => client.visibilityState === 'visible');
    const isVisible = windows.some(client => client.visibilityState === 'visible');
    const hasForegroundOwner = windows.some(client =>
      client.visibilityState === 'visible' && client.focused === true);
    // Firebase may already have forwarded to a window that became hidden.
    // Preserve its alert unless a current visible+focused window can show it.
    if ((!wasVisible && !isVisible) || hasForegroundOwner) return;
    await showDurableFallback(data);
  })().catch(() => undefined));
}

messaging.onBackgroundMessage((payload) => {
  const data = payload.data;
  if (!isFreshDurableNotification(data)) return Promise.resolve();
  // Fully hidden clients retain SDK notification display. Data-only background
  // events use the same durable fallback as visible-but-unfocused windows.
  if (payload.notification) return updateApplicationBadge(data);
  return showDurableFallback(data);
});

function handleNotificationClick(event) {
  const metadata = event.notification?.data;
  const sdkData = metadata?.FCM_MSG?.data;
  let appUrl;
  if (metadata?.yorksFallback === true) {
    appUrl = metadata.appUrl || appUrlFor({ route: '/notifications' });
  } else if (isDurableNotification(sdkData)) {
    // Use the protected sender's safe app route, never an arbitrary SDK link.
    // An expired displayed notification may still open its durable history.
    appUrl = appUrlFor(sdkData);
  } else {
    // Console/non-durable notifications remain outside Yorks click ownership.
    return;
  }
  let target;
  try {
    target = new URL(appUrl, self.registration.scope);
    if (target.origin !== new URL(self.registration.scope).origin) return;
  } catch (_) {
    return;
  }
  event.stopImmediatePropagation();
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await sameOriginWindows();
    // Reuse an exact destination. Do not replace a different tab's draft or
    // unsaved worksheet merely because it was the first client returned.
    const existing = windows.find(client => client.url === target.href);
    if (existing && 'focus' in existing) return existing.focus();
    return self.clients.openWindow(target.href);
  })().catch(() => undefined));
}
