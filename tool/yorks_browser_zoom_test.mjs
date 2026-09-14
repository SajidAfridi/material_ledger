import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const bootstrap = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

test('web host preserves layout during pinch, keyboard and page zoom changes', async () => {
  const host = { style: {} };
  const windowEvents = new Map();
  const viewportEvents = new Map();
  const viewport = { height: 800, scale: 1, addEventListener: (name, fn) => viewportEvents.set(name, fn) };
  const window = { innerWidth: 1280, innerHeight: 800, visualViewport: viewport,
    addEventListener: (name, fn) => windowEvents.set(name, fn),
    setTimeout: () => {} };
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
  viewport.scale = 2;
  viewport.height = 400;
  viewportEvents.get('resize')();
  assert.equal(host.style.width, '1280.0625px');
  assert.equal(host.style.height, '800.0625px');
  viewport.height = 250; // Keyboard covers part of the magnified viewport.
  viewportEvents.get('resize')();
  assert.equal(host.style.height, '500.125px');
  viewport.scale = 1;
  viewport.height = 800;
  viewportEvents.get('resize')();
  assert.equal(host.style.height, '800.0625px');
  window.innerWidth = 640; // Browser page zoom changes layout dimensions.
  window.innerHeight = 400;
  viewport.height = 400;
  windowEvents.get('resize')();
  assert.equal(host.style.width, '640.125px');
  assert.equal(host.style.height, '400.125px');
});

test('zoom ownership leaves browser defaults intact and ordinary input untouched', () => {
  const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
  const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
    .map(match => match[1]).find(source => source.includes('Browser zoom must'));
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
    listeners.get(type)({ ...values,
      stopImmediatePropagation: () => { stopped = true; },
      preventDefault: () => assert.fail('Yorks must not suppress browser zoom defaults'),
    });
    assert.equal(stopped, expected, `${type}: ${JSON.stringify(values)}`);
  }
  assert.equal(listeners.has('gesturestart'), false);
  assert.equal(listeners.has('mousedown'), false);
});
