// Bounded HTTP conflict probe; refuses production. Creates only its own
// synthetic private draft, removes it through the owner RPC, and signs out.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';

let base = process.env.SUPABASE_URL;
let key = process.env.SUPABASE_ANON_KEY;
if (!base || !key) {
  const local = JSON.parse(execFileSync('npx', ['--yes', 'supabase', 'status', '-o', 'json'], {
    encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }));
  base = local.API_URL;
  key = local.ANON_KEY;
}
const target = new URL(base);
assert.ok(['127.0.0.1:54321', 'localhost:54321', 'iqltcyimlqtcwyzlemwx.supabase.co'].includes(target.host),
  'This probe must never run against production');
const login = await fetch(base + '/auth/v1/token?grant_type=password', {
  method: 'POST',
  headers: {apikey: key, 'Content-Type': 'application/json'},
  body: JSON.stringify({email: 'project.engineer@yorks.local.test',
    password: process.env.YORKS_TEST_PASSWORD ?? 'YorksLocalOnly!2026'}),
  signal: AbortSignal.timeout(10000),
});
assert.equal(login.status, 200, 'Test persona login');
const session = await login.json();
assert.equal(session.user.id, '10000000-0000-4000-8000-000000000001');
const headers = {apikey: key, Authorization: 'Bearer ' + session.access_token, 'Content-Type': 'application/json'};
const draftId = randomUUID();
let created = false;
let expectedVersion = 1;
async function rpc(name, parameters) {
  const start = performance.now();
  const response = await fetch(base + '/rest/v1/rpc/' + name, {
    method: 'POST', headers, body: JSON.stringify(parameters), signal: AbortSignal.timeout(10000),
  });
  const body = await response.json();
  console.log(JSON.stringify({rpc: name, status: response.status,
    elapsed_ms: Math.round(performance.now() - start), error_code: body.code ?? null}));
  return {status: response.status, body};
}
const sync = (version, key) => rpc('v1_sync_material_request_private_draft', {
  p_payload: {draft_id: draftId, expected_sync_version: version,
    client_updated_at: '2026-09-03T00:00:00Z', draft_data: {}},
  p_idempotency_key: key,
});
const remove = (version, key) => rpc('v1_delete_my_material_request_private_draft', {
  p_payload: {draft_id: draftId, expected_sync_version: version}, p_idempotency_key: key,
});
try {
  const first = await sync(0, randomUUID());
  assert.equal(first.status, 200);
  created = true;
  assert.equal(first.body.sync_version, 1);
  for (const response of [await sync(0, randomUUID()), await remove(2, randomUUID())]) {
    assert.equal(response.status, 409);
    assert.equal(response.body.code, '40001');
    assert.equal(response.body.message, 'V1_PRIVATE_DRAFT_VERSION_CONFLICT');
  }
  const saveKey = randomUUID();
  const current = await sync(1, saveKey);
  assert.equal(current.status, 200);
  expectedVersion = 2;
  assert.equal(current.body.sync_version, 2);
  const retry = await sync(1, saveKey);
  assert.equal(retry.status, 200);
  assert.deepEqual(retry.body, current.body);
  assert.equal((await remove(2, randomUUID())).status, 200);
  created = false;
  console.log(JSON.stringify({target: target.host, result: 'PASS', synthetic_draft_removed: true}));
} finally {
  if (created) assert.equal((await remove(expectedVersion, randomUUID())).status, 200, 'Synthetic cleanup');
  await fetch(base + '/auth/v1/logout?scope=local', {
    method: 'POST', headers, signal: AbortSignal.timeout(10000),
  });
}
