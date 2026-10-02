import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const script = readFileSync(new URL('../web/firebase-messaging-sw.js', import.meta.url), 'utf8');
const id = '21000000-0000-4000-8000-000000000001';
function worker(windows = []) {
  let receive;
  let sdkClicks = 0;
  let sdkPushes = 0;
  let lookupCount = 0;
  let now = Date.now();
  const listeners = new Map();
  const registrationOrder = [];
  const shown = [];
  const active = new Map();
  const opened = [];
  const forwarded = [];
  const badges = [];
  const matchAll = async () => typeof windows === 'function'
    ? windows(lookupCount++)
    : windows;
  function on(event, handler) {
    registrationOrder.push(event);
    const handlers = listeners.get(event) || [];
    handlers.push(handler);
    listeners.set(event, handlers);
  }
  async function showNotification(title, options) {
    const alert = {title, ...options};
    shown.push(alert);
    // Model OS tag replacement, independently of number of API invocations.
    active.set(options.tag || `untagged:${shown.length}`, alert);
  }
  const self = {
    registration: { scope: 'https://yorks.test/', showNotification },
    navigator: {
      setAppBadge: async count => badges.push(count),
      clearAppBadge: async () => badges.push(0),
    },
    clients: { matchAll, openWindow: async url => opened.push(url) },
    addEventListener: on,
  };
  // Model the pinned Firebase SDK's documented decisions, rather than calling
  // only our background callback: any visible non-extension client receives
  // onMessage, otherwise SDK notification display precedes onBackgroundMessage.
  const sdkPush = async event => {
    sdkPushes++;
    let payload;
    try {
      payload = event.data?.json();
    } catch (_) {
      return;
    }
    if (!payload) return;
    const clients = await matchAll();
    if (clients.some(client => client.visibilityState === 'visible'
        && !client.url.startsWith('chrome-extension://'))) {
      forwarded.push(...clients.map(client => ({client, payload})));
      return;
    }
    if (payload.notification) {
      await showNotification(payload.notification.title || '', {
        ...payload.notification,
        data: {FCM_MSG: payload},
      });
    }
    await receive?.(payload);
  };
  const sdkClick = async event => {
    const payload = event.notification.data?.FCM_MSG;
    if (!payload) return;
    sdkClicks++;
    event.stopImmediatePropagation();
    const link = payload.fcmOptions?.link;
    if (!link) return;
    const clients = await matchAll();
    const client = clients.find(window => new URL(window.url).origin === 'https://yorks.test');
    if (client?.focus) await client.focus();
    else opened.push(link);
  };
  vm.runInNewContext(script, {
    self, URL,
    Date: class extends Date { static now() { return now; } },
    importScripts: () => registrationOrder.push('import'),
    firebase: {
      initializeApp: () => {},
      messaging: () => {
        on('push', event => event.waitUntil(sdkPush(event)));
        on('notificationclick', event => event.waitUntil(sdkClick(event)));
        return {onBackgroundMessage: handler => { receive = handler; }};
      },
    },
  });
  async function dispatch(type, event) {
    const pending = [];
    let stopped = false;
    let closed = false;
    const nativeEvent = {
      ...event,
      waitUntil: task => pending.push(task),
      stopImmediatePropagation: () => { stopped = true; },
    };
    if (event.notification) {
      nativeEvent.notification = {...event.notification, close: () => { closed = true; }};
    }
    for (const handler of listeners.get(type) || []) {
      if (stopped) break;
      handler(nativeEvent);
    }
    await Promise.all(pending);
    return {stopped, closed};
  }
  return {
    shown, active, opened, forwarded, badges, receive, registrationOrder,
    get sdkClicks() { return sdkClicks; },
    get sdkPushes() { return sdkPushes; },
    setNow: value => { now = value; },
    push: payload => dispatch('push', {data: {json: () => structuredClone(payload)}}),
    malformedPush: () => dispatch('push', {data: {json: () => { throw new SyntaxError('bad JSON'); }}}),
    emptyPush: () => dispatch('push', {}),
    tap: data => dispatch('notificationclick', {notification: {data}}),
  };
}
const data = extra => ({notificationId: id, expiresAt: new Date(Date.now() + 60000).toISOString(), route: '/yorks/material-requests/request', ...extra});
const client = (visibilityState, focused = false, url = 'https://yorks.test/#/workspace') => ({url, visibilityState, focused});
const notificationPayload = extra => ({
  notification: {title: 'SDK safe title', body: 'SDK safe body', tag: 'workflow:request', renotify: false},
  data: data({title: 'Protected event title', body: 'Protected event body', collapseKey: 'workflow:request', ...extra}),
});

test('only fresh durable data-only events create fallback notifications', async () => {
  const w = worker();
  for (const bad of [{notificationId: ''}, {expiresAt: ''}, {expiresAt: 'invalid'}, {expiresAt: '2000-01-01'}]) {
    await w.receive({data: data(bad)});
  }
  await w.receive({notification: {title: 'SDK-owned'}, data: data()});
  assert.equal(w.shown.length, 0);
  await w.receive({data: data({collapseKey: 'request:one'})});
  assert.equal(w.shown.length, 1);
  assert.equal(w.shown[0].tag, 'request:one');
  assert.equal(w.shown[0].renotify, false);
  assert.match(w.shown[0].data.appUrl, /#\/yorks\/material-requests\/request\?notificationId=/);
});

test('fallback click focuses exact destination and preserves unrelated draft tabs', async () => {
  let focused = 0;
  const target = 'https://yorks.test/#/notifications';
  const w = worker([{url: 'https://yorks.test/#/draft', focus: () => assert.fail('Wrong tab')},
    {url: target, focus: async () => focused++}]);
  await w.tap({yorksFallback: true, appUrl: target});
  assert.equal(focused, 1);
  assert.equal(w.opened.length, 0);
  await w.tap({yorksFallback: true, appUrl: 'https://yorks.test/#/another'});
  assert.deepEqual(w.opened, ['https://yorks.test/#/another']);
  await w.tap({yorksFallback: true, appUrl: 'https://evil.test/'});
  assert.equal(w.opened.length, 1);
  await w.tap({FCM_MSG: {}});
  assert.equal(w.opened.length, 1);
});

test('unsafe route falls back to the correct in-app surface', async () => {
  for (const route of ['//evil.test', '/\\evil.test', '/hello\nworld', 'https://evil.test']) {
    const w = worker();
    await w.receive({data: data({route, surface: 'team_chat'})});
    assert.match(w.shown[0].data.appUrl, /^https:\/\/yorks.test\/#\/yorks\/team-chat\?/);
  }
});

test('localized fallback notifications preserve device language and direction', async () => {
  for (const [language, expectedLanguage, direction] of [['ar', 'ar', 'rtl'], ['ur', 'ur', 'rtl'], ['hi', 'hi', 'ltr'], ['en', 'en', 'ltr'], ['xx', 'en', 'ltr']]) {
    const w = worker();
    await w.receive({data: data({language, title: 'عنوان', body: 'نص'})});
    assert.equal(w.shown[0].title, 'عنوان');
    assert.equal(w.shown[0].body, 'نص');
    assert.equal(w.shown[0].lang, expectedLanguage);
    assert.equal(w.shown[0].dir, direction);
  }
});

test('Yorks validates push and owns durable clicks before SDK listeners attach', () => {
  const w = worker();
  assert.deepEqual(w.registrationOrder, [
    'push', 'notificationclick', 'import', 'import', 'push', 'notificationclick',
  ]);
});

for (const notification of [true, false]) {
  test(`visible unfocused window receives one OS alert and retains SDK refresh (${notification ? 'notification' : 'data-only'})`, async () => {
    const w = worker([client('visible')]);
    const payload = notificationPayload({unreadCount: '3'});
    if (!notification) delete payload.notification;
    const delivery = await w.push(payload);
    assert.equal(delivery.stopped, false);
    assert.equal(w.sdkPushes, 1);
    assert.equal(w.forwarded.length, 1);
    assert.equal(w.shown.length, 1);
    assert.equal(w.active.size, 1);
    assert.equal(w.shown[0].title, 'Protected event title');
    assert.equal(w.shown[0].body, 'Protected event body');
    assert.equal(w.shown[0].tag, 'workflow:request');
    assert.equal(w.shown[0].renotify, false);
    assert.equal(w.shown[0].data.yorksFallback, true);
    assert.match(w.shown[0].data.appUrl, /#\/yorks\/material-requests\/request\?notificationId=/);
    assert.deepEqual(w.badges, [3]);
  });
}

test('multiple visible unfocused windows receive one OS alert', async () => {
  const w = worker([client('visible'), client('visible', false, 'https://yorks.test/#/draft')]);
  await w.push(notificationPayload());
  assert.equal(w.forwarded.length, 2);
  assert.equal(w.shown.length, 1);
});

test('a focused visible Yorks window retains foreground-only presentation', async () => {
  const w = worker([client('visible', false), client('visible', true)]);
  await w.push(notificationPayload());
  assert.equal(w.sdkPushes, 1);
  assert.equal(w.forwarded.length, 2);
  assert.equal(w.shown.length, 0);
  assert.equal(w.badges.length, 0);
});

for (const [state, windows] of [['closed', []], ['hidden', [client('hidden')]]]) {
  test(`${state} clients retain one SDK notification or one data-only fallback`, async () => {
    const sdk = worker(windows);
    await sdk.push(notificationPayload());
    assert.equal(sdk.shown.length, 1);
    assert.ok(sdk.shown[0].data.FCM_MSG);
    assert.equal(sdk.shown[0].data.yorksFallback, undefined);
    assert.equal(sdk.forwarded.length, 0);

    const fallback = worker(windows);
    await fallback.push({data: data()});
    assert.equal(fallback.shown.length, 1);
    assert.equal(fallback.shown[0].data.yorksFallback, true);
  });
}

test('foreign and extension focus cannot suppress an eligible Yorks alert', async () => {
  const w = worker([
    client('visible'),
    client('visible', true, 'chrome-extension://example/background.html'),
    client('visible', true, 'https://foreign.test/'),
    client('visible', true, 'invalid URL'),
  ]);
  await w.push(notificationPayload());
  assert.equal(w.shown.length, 1);
  assert.equal(w.shown[0].data.yorksFallback, true);
});

test('malformed, console and expired payloads stop before SDK automatic display', async () => {
  const badData = [
    undefined, null, [], {},
    data({notificationId: ''}),
    data({notificationId: '-'.repeat(36)}),
    data({notificationId: '21000000-0000-4000-0000-000000000001'}),
    data({expiresAt: undefined}),
    data({expiresAt: ''}),
    data({expiresAt: 'invalid'}),
    data({expiresAt: '2000-01-01T00:00:00Z'}),
  ];
  for (const invalid of badData) {
    const w = worker();
    const delivery = await w.push({notification: {title: 'Must not display'}, data: invalid});
    assert.equal(delivery.stopped, true);
    assert.equal(w.sdkPushes, 0);
    assert.equal(w.shown.length, 0);
    assert.equal(w.badges.length, 0);
  }
  const malformed = worker();
  assert.equal((await malformed.malformedPush()).stopped, true);
  assert.equal((await malformed.emptyPush()).stopped, true);
  assert.equal(malformed.sdkPushes, 0);
});

test('focus acquired during client lookup suppresses the observer alert', async () => {
  const w = worker(index => [client('visible', index > 0)]);
  await w.push(notificationPayload());
  assert.equal(w.forwarded.length, 1);
  assert.equal(w.shown.length, 0);
});

test('focus lost during client lookup enables the missing OS alert', async () => {
  const w = worker(index => [client('visible', index === 0)]);
  await w.push(notificationPayload());
  assert.equal(w.forwarded.length, 1);
  assert.equal(w.shown.length, 1);
});

for (const hiddenFocused of [false, true]) {
  test(`visibility lost after SDK forwarding retains the missing OS alert (hidden focus=${hiddenFocused})`, async () => {
    const w = worker(index => [index < 2
      ? client('visible')
      : client('hidden', hiddenFocused)]);
    await w.push(notificationPayload());
    assert.equal(w.forwarded.length, 1);
    assert.equal(w.shown.length, 1);
    assert.equal(w.shown[0].data.yorksFallback, true);
  });
}

test('visibility acquired during lookup enables the missing OS alert', async () => {
  const w = worker(index => [client(index === 0 ? 'hidden' : 'visible')]);
  await w.push(notificationPayload());
  assert.equal(w.forwarded.length, 1);
  assert.equal(w.shown.length, 1);
});

test('expiry during client lookup prevents a late fallback', async () => {
  const payload = notificationPayload();
  let w;
  w = worker(index => {
    if (index === 2) w.setNow(Date.parse(payload.data.expiresAt));
    return [client('visible')];
  });
  await w.push(payload);
  assert.equal(w.sdkPushes, 1);
  assert.equal(w.shown.length, 0);
  assert.equal(w.badges.length, 0);
});

test('visibility race collapses SDK and observer display into one silent replacement', async () => {
  // Observer first lookup: visible. SDK snapshot: hidden. Observer recheck:
  // visible again. Both paths can display, but their shared tag owns one alert.
  const w = worker(index => [client(index === 1 ? 'hidden' : 'visible')]);
  await w.push(notificationPayload());
  assert.equal(w.shown.length, 2);
  assert.equal(w.active.size, 1);
  assert.equal(w.shown[0].tag, w.shown[1].tag);
  assert.equal(w.shown[0].renotify, false);
  assert.equal(w.shown[1].renotify, false);
});

test('repeated related deliveries replace one alert and retain its latest exact target', async () => {
  const w = worker([client('visible')]);
  await w.push(notificationPayload());
  const nextId = '21000000-0000-4000-8000-000000000002';
  await w.push(notificationPayload({notificationId: nextId}));
  assert.equal(w.shown.length, 2);
  assert.equal(w.active.size, 1);
  assert.match(w.active.get('workflow:request').data.appUrl, new RegExp(nextId));
});

test('durable SDK click focuses only its exact destination and preserves an earlier draft tab', async () => {
  let exactFocus = 0;
  const target = `https://yorks.test/#/yorks/material-requests/request?notificationId=${id}`;
  const w = worker([
    {url: 'https://yorks.test/#/draft', focus: () => assert.fail('Unsaved draft replaced')},
    {url: target, focus: async () => exactFocus++},
  ]);
  const click = await w.tap({FCM_MSG: notificationPayload()});
  assert.equal(click.stopped, true);
  assert.equal(click.closed, true);
  assert.equal(exactFocus, 1);
  assert.equal(w.sdkClicks, 0);
  assert.equal(w.opened.length, 0);
});

test('durable SDK click opens a new exact destination without focusing or navigating a draft', async () => {
  const w = worker([{
    url: 'https://yorks.test/#/draft',
    focus: () => assert.fail('Wrong tab focused'),
    navigate: () => assert.fail('Unsaved work discarded'),
  }]);
  await w.tap({FCM_MSG: notificationPayload()});
  assert.deepEqual(w.opened, [
    `https://yorks.test/#/yorks/material-requests/request?notificationId=${id}`,
  ]);
  assert.equal(w.sdkClicks, 0);
});

test('durable click ignores arbitrary SDK links and uses a safe route fallback', async () => {
  const w = worker();
  const payload = notificationPayload({route: '//evil.test/', surface: 'team_chat'});
  payload.fcmOptions = {link: 'https://evil.test/'};
  await w.tap({FCM_MSG: payload});
  assert.deepEqual(w.opened, [`https://yorks.test/#/yorks/team-chat?notificationId=${id}`]);
  assert.equal(w.sdkClicks, 0);
});

test('expired displayed durable alerts can still open authorized history', async () => {
  const w = worker();
  await w.tap({FCM_MSG: notificationPayload({expiresAt: '2000-01-01T00:00:00Z'})});
  assert.equal(w.opened.length, 1);
  assert.match(w.opened[0], new RegExp(id));
  assert.equal(w.sdkClicks, 0);
});

test('existing malformed or console SDK clicks remain delegated to SDK', async () => {
  for (const sdkData of [undefined, {}, {notificationId: ''}, {notificationId: '-'.repeat(36)}]) {
    const w = worker();
    await w.tap({FCM_MSG: {data: sdkData}});
    assert.equal(w.sdkClicks, 1);
    assert.equal(w.opened.length, 0);
  }
});
