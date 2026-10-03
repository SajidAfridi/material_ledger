import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {test} from 'node:test';
import vm from 'node:vm';

test('parse/print preserves public names, deferred shared state, Unicode and side effects', () => {
  const dir = mkdtempSync(join(tmpdir(), 'yorks-js-'));
  try {
    const path = join(dir, 'main.dart.js');
    const source = `/*! Yorks license fixture */
      var shared = { counter: 0, title: "\\u064a\\u0648\\u0631\\u0643\\u0633" };
      function PublicEntry(value) { this.value = value; shared.counter++; }
      globalThis.fixture = { PublicEntry, shared, lazy: function() { return shared; } };
    `;
    writeFileSync(path, source);
    execFileSync('bash', [resolve('tool/compact_web_javascript.sh'), path], {stdio: 'pipe'});
    const compact = readFileSync(path, 'utf8');
    assert.ok(compact.includes('Yorks license fixture'));
    const original = vm.createContext({});
    const result = vm.createContext({});
    vm.runInContext(source, original);
    vm.runInContext(compact, result);
    const deferred = 'globalThis.answer = [new fixture.PublicEntry(42).value, fixture.PublicEntry.name, fixture.lazy().title, fixture.shared.counter]';
    vm.runInContext(deferred, original);
    vm.runInContext(deferred, result);
    assert.equal(JSON.stringify(result.answer), JSON.stringify(original.answer));
  } finally {
    rmSync(dir, {recursive:true, force:true});
  }
});
