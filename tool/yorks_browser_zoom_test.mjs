import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const bootstrap = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

test('web host follows only the window layout', async () => {
  const host = { style: {} };
  const windowEvents = new Map();
  const window = { innerWidth: 1280, innerHeight: 800,
    addEventListener: (name, fn) => windowEvents.set(name, fn) };
  let boot;
  let receivedHost;
  runInNewContext(bootstrap, {
    window, console,
    document: { querySelector: () => null, getElementById: () => host },
    _flutter: { loader: { load: ({ onEntrypointLoaded }) => {
      boot = onEntrypointLoaded({ initializeEngine: async (config) => {
        receivedHost = config.hostElement;
        return { runApp: async () => {} };
      } });
      return boot;
    } } },
  });
  await boot;
  assert.equal(receivedHost, host);
  assert.equal(host.style.width, '1280px');
  assert.equal(host.style.height, '800px');
  assert.equal(windowEvents.has('resize'), true);
  window.innerWidth = 640;
  window.innerHeight = 400;
  windowEvents.get('resize')();
  assert.equal(host.style.width, '640px');
  assert.equal(host.style.height, '400px');
});

test('zoom ownership suppresses browser scaling but keeps events for Flutter', () => {
  const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
  assert.match(html, /maximum-scale=1\.0, user-scalable=no/);
  assert.match(html, /touch-action: none !important/);
  const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
    .map(match => match[1]).find(source => source.includes('fixed-layout workspace'));
  const listeners = new Map();
  runInNewContext(script, {
    window: { addEventListener: (name, fn) => listeners.set(name, fn), setTimeout: () => {} },
    document: { getElementById: () => null },
  });
  for (const [type, values, expected] of [
    ['wheel', { ctrlKey: true }, true],
    ['wheel', { metaKey: true }, true],
    ['wheel', { shiftKey: true }, false],
    ['wheel', {}, false],
    ['keydown', { ctrlKey: true, key: '+' }, true],
    ['keydown', { metaKey: true, key: '0' }, true],
    ['keydown', { ctrlKey: true, key: 'c' }, false],
    ['keydown', { ctrlKey: true, altKey: true, key: '=' }, false],
  ]) {
    let stopped = false;
    let prevented = false;
    listeners.get(type)({ ...values,
      stopImmediatePropagation: () => { stopped = true; },
      preventDefault: () => { prevented = true; },
    });
    assert.equal(prevented, expected, `${type}: ${JSON.stringify(values)}`);
    assert.equal(stopped, false, `${type} must continue to Flutter`);
  }
  assert.equal(listeners.has('gesturestart'), false);
  assert.equal(listeners.has('mousedown'), false);
});
