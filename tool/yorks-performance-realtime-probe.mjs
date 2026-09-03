// Local/dedicated-staging only. Uses public test personas, never production.
// Prints transport verdicts/counts, not JWTs, row payloads or chat content.
import {execFileSync} from 'node:child_process';

let base = process.env.SUPABASE_URL;
let key = process.env.SUPABASE_ANON_KEY;
if (!base || !key) {
  const status = JSON.parse(execFileSync('npx', ['--yes', 'supabase', 'status', '-o', 'json'], {
    encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }));
  base = status.API_URL;
  key = status.ANON_KEY;
}
const target = new URL(base);
if (!['127.0.0.1:54321', 'localhost:54321', 'iqltcyimlqtcwyzlemwx.supabase.co'].includes(target.host)) {
  throw new Error('Probe refuses any target other than local/dedicated staging');
}
const authResponse = await fetch(`${base}/auth/v1/token?grant_type=password`, {
  method: 'POST',
  headers: {apikey: key, 'Content-Type': 'application/json'},
  body: JSON.stringify({
    email: 'project.engineer@yorks.local.test',
    password: process.env.YORKS_TEST_PASSWORD ?? 'YorksLocalOnly!2026',
  }),
});
if (!authResponse.ok) throw new Error(`Test-persona login failed: HTTP ${authResponse.status}`);
const session = await authResponse.json();
if (session.user.id !== '10000000-0000-4000-8000-000000000001') {
  throw new Error('Unexpected test persona');
}
const signOut = () => fetch(`${base}/auth/v1/logout?scope=local`, {
  method: 'POST', headers: {apikey: key, Authorization: `Bearer ${session.access_token}`},
});
if (process.argv.includes('--rpc-sizes')) {
  try {
    for (const [rpc, parameters] of [
      ['v1_get_current_permission_snapshot', {}],
      ['v1_list_chat_conversations', {}],
      ['v1_list_my_notifications', {p_limit: 100}],
      ['v1_list_material_requests', {p_project_id: null}],
    ]) {
      const started = performance.now();
      const response = await fetch(`${base}/rest/v1/rpc/${rpc}`, {
        method: 'POST',
        headers: {apikey: key, Authorization: `Bearer ${session.access_token}`, 'Content-Type': 'application/json'},
        body: JSON.stringify(parameters),
      });
      const body = await response.text();
      console.log(JSON.stringify({target: target.host, rpc, status: response.status,
        decoded_bytes: Buffer.byteLength(body), elapsed_ms: Math.round(performance.now() - started)}));
      if (!response.ok) throw new Error(`Staging RPC failed: ${rpc}, HTTP ${response.status}`);
    }
  } finally {
    await signOut();
  }
  process.exit(0);
}
const socketUrl = new URL(`${base}/realtime/v1/websocket`);
socketUrl.protocol = target.protocol === 'https:' ? 'wss:' : 'ws:';
socketUrl.searchParams.set('apikey', key);
socketUrl.searchParams.set('vsn', '1.0.0');
const socket = new WebSocket(socketUrl);
let ref = 0;
let heartbeat;
let finished = false;
const started = Date.now();
const observations = [];
const tables = ['materialCategories', 'materialUnits'];
const send = (topic, event, payload) => socket.send(JSON.stringify({topic, event, payload, ref: String(++ref)}));

try {
  await new Promise((resolve, reject) => {
    const deadline = setTimeout(() => {
      finished = true;
      socket.close();
      resolve();
    }, 22000);
    socket.onopen = () => {
      for (const table of tables) {
        send(`realtime:performance-probe:${table}`, 'phx_join', {
          config: {broadcast: {ack: false, self: false}, presence: {key: '', enabled: false},
            postgres_changes: [{event: '*', schema: 'public', table}], private: false},
          access_token: session.access_token,
        });
      }
      heartbeat = setInterval(() => send('phoenix', 'heartbeat', {}), 10000);
    };
    socket.onmessage = ({data}) => {
      const message = JSON.parse(data);
      if (message.event !== 'system') return;
      observations.push({
        table: tables.find(table => message.topic.endsWith(`:${table}`)),
        elapsed_ms: Date.now() - started,
        status: message.payload.status,
        postgres: message.payload.extension === 'postgres_changes',
        subscription_failure: /unable to subscribe|not found|not exist|matching|not enabled/i.test(message.payload.message ?? ''),
      });
    };
    socket.onerror = () => {
      clearTimeout(deadline);
      reject(new Error('Realtime probe transport failed'));
    };
    socket.onclose = () => {
      if (!finished) {
        clearTimeout(deadline);
        reject(new Error('Realtime probe closed before its observation window'));
      }
    };
  });
  console.log(JSON.stringify({target: target.host, window_ms: Date.now() - started, observations}));
} finally {
  clearInterval(heartbeat);
  socket.close();
  // Revoke this test login only; never sign out the fixture's other sessions.
  await signOut();
}
