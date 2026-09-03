// Verify only an already-built Yorks artifact; never alter deployment settings.
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {promisify} from 'node:util';

const [deployment, directory] = process.argv.slice(2);
assert.ok(deployment && directory, 'Usage: node tool/verify-yorks-web-release.mjs URL ARTIFACT_DIR');
assert.equal(new URL(deployment).protocol, 'https:');
const run = promisify(execFile);
const hash = data => createHash('sha256').update(data).digest('hex');
const checks = [
  ['/', 'index.html'],
  ['/yorks/material-requests', 'index.html'],
  ['/yorks/team-chat', 'index.html'],
  ...['main.dart.js', 'flutter_bootstrap.js', 'flutter_service_worker.js', 'firebase-messaging-sw.js', 'manifest.json'].map(file => [`/${file}`, file]),
];
// Limit concurrency; the large JS response remains compressed in transit.
for (let offset = 0; offset < checks.length; offset += 2) {
  await Promise.all(checks.slice(offset, offset + 2).map(async ([route, file]) => {
    const expected = fs.readFileSync(path.join(directory, file));
    const {stdout} = await run('npx', ['--yes', 'vercel', 'curl', route,
      '--deployment', deployment, '--', '--fail', '--silent', '--show-error',
      '--compressed', '--retry', '3', '--retry-all-errors'], {
      cwd: directory, encoding: 'buffer', maxBuffer: 25 * 1024 * 1024, timeout: 180000,
    });
    let actual = stdout;
    if (file === 'index.html') {
      // Preview-only Vercel feedback is the sole allowed HTML transformation.
      actual = Buffer.from(stdout.toString().replace(/<script async data-explicit-opt-in="true" data-deployment-id="dpl_[A-Za-z0-9]+" src="https:\/\/vercel\.live\/_next-live\/feedback\/feedback\.js"><\/script>$/, ''));
    }
    assert.equal(hash(actual), hash(expected), `Artifact mismatch: ${route}`);
    console.log(JSON.stringify({route, bytes: actual.length, sha256: hash(actual), verified: true}));
  }));
}
