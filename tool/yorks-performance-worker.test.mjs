import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const worker = fs.readFileSync(new URL('../web/firebase-messaging-sw.js', import.meta.url), 'utf8');
function runtime() {
  const imports = [], events = [], notifications = [];
  let onMessage;
  const context = vm.createContext({
    URL, console,
    importScripts: (...urls) => imports.push(...urls),
    firebase: {initializeApp() {}, messaging: () => ({onBackgroundMessage(callback) {onMessage = callback;}})},
    self: {
      registration: {scope: 'https://yorks.test/', showNotification: (title, options) => {notifications.push({title, options}); return Promise.resolve();}},
      navigator: {}, addEventListener: (event, callback) => events.push({event, callback}),
    },
  });
  vm.runInContext(worker, context);
  return {imports, events, notifications, onMessage};
}
test('push worker imports only Firebase and never installs a cleanup listener', () => {
  const {imports, events} = runtime();
  assert.equal(imports.length, 2);
  assert.ok(imports.every(url => url.startsWith('https://www.gstatic.com/firebasejs/')));
  assert.deepEqual(events.map(event => event.event), ['notificationclick']);
});
test('data-only push retains notification content, routing and deduplication', async () => {
  const app = runtime();
  await app.onMessage({data: {surface: 'team_chat', route: '/yorks/team-chat/test', title: 'Fixture', body: 'Test', notificationId: '10000000-0000-4000-8000-000000000001'}});
  assert.equal(app.notifications.length, 1);
  assert.equal(app.notifications[0].title, 'Fixture');
  assert.equal(app.notifications[0].options.body, 'Test');
  assert.equal(app.notifications[0].options.renotify, false);
  assert.equal(app.notifications[0].options.data.yorksFallback, true);
  assert.ok(app.notifications[0].options.data.appUrl.startsWith('https://yorks.test/#/yorks/team-chat/test'));
});
test('browser-displayed notification payloads are not displayed twice', async () => {
  const app = runtime();
  await app.onMessage({notification: {title: 'Already displayed'}, data: {}});
  assert.equal(app.notifications.length, 0);
});
