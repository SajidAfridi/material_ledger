// send-push — fan out a push notification to one or more app users via FCM.
//
// The client can't hold Google's service-account key, so the actual send goes
// through this Edge Function: given target `app_user_id`s + a title/body, it
// looks up their registered device tokens (device_tokens — service_role only,
// the client has no read access to it) and calls FCM's HTTP v1 API using a
// server-to-server OAuth2 token obtained from the service-account key.
//
// PUSH IS PURELY A TRANSPORT: the actual notification record already lives in
// the (synced) `notifications` table and reaches every device on its own — this
// function's only job is to wake the target device and hand it a `route` to
// deep-link to on tap. It is config-gated like every other optional integration
// in this app: with no FCM_SERVICE_ACCOUNT_JSON secret set, it responds 501
// rather than erroring the caller's flow (the in-app/synced notification still
// works with no push).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })

// ── Google service-account OAuth2 (server-to-server, RS256 JWT-bearer) ──
// Standard flow, implemented dependency-free with Deno's built-in WebCrypto
// (mirrors this project's other Edge Function's "no external deps" style).

function base64UrlEncode(bytes: Uint8Array): string {
  let str = ''
  for (const b of bytes) str += String.fromCharCode(b)
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const contents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const der = Uint8Array.from(atob(contents), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

/** Exchanges a Firebase/GCP service-account key for a short-lived FCM access token. */
async function getFcmAccessToken(
  serviceAccount: { client_email: string; private_key: string },
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  )
  const claims = base64UrlEncode(
    new TextEncoder().encode(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      }),
    ),
  )
  const unsigned = `${header}.${claims}`
  const key = await importPrivateKey(serviceAccount.private_key)
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const tokenData = await res.json()
  if (!res.ok) throw new Error(`token exchange failed: ${JSON.stringify(tokenData)}`)
  return tokenData.access_token as string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405)

  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // ── Authorize FIRST: caller must be signed in (any role — sending a push
  // for a teammate's event is routine, low-stakes, done by every role). This
  // must happen before anything else, including the config-availability
  // check below, so an unauthenticated caller never learns configuration
  // state. ──
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'missing token' }, 401)
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: who, error: whoErr } = await caller.auth.getUser()
  if (whoErr || !who?.user) return json({ error: 'unauthorized' }, 401)

  const saJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
  if (!saJson) {
    // Not configured yet — the in-app/synced notification still works without
    // push, so this is a soft failure, not a hard error for the caller.
    return json({ ok: false, error: 'push not configured' }, 501)
  }

  let body: {
    targetAppUserIds?: string[]
    title?: string
    body?: string
    data?: Record<string, string>
  }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'invalid JSON body' }, 400)
  }
  const targets = (body.targetAppUserIds ?? []).filter(Boolean)
  if (targets.length === 0 || !body.title) {
    return json({ error: 'targetAppUserIds (non-empty) and title required' }, 400)
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  try {
    // Tiny team app — a full scan + in-memory filter avoids PostgREST JSON-path
    // filter syntax entirely and is trivially fast at this scale.
    const { data: rows, error: tokErr } = await admin
      .from('device_tokens')
      .select('id, data')
    if (tokErr) throw tokErr

    const targetSet = new Set(targets)
    const matching = (rows ?? []).filter((r) =>
      targetSet.has((r.data as Record<string, unknown>)?.appUserId as string),
    )
    if (matching.length === 0) {
      return json({ ok: true, sent: 0, note: 'no registered devices for these users' })
    }

    const serviceAccount = JSON.parse(saJson) as {
      project_id: string
      client_email: string
      private_key: string
    }
    const accessToken = await getFcmAccessToken(serviceAccount)
    const sendUrl =
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

    let sent = 0
    const staleTokenIds: string[] = []
    for (const row of matching) {
      const token = row.id as string
      const res = await fetch(sendUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: body.title, body: body.body ?? '' },
            data: body.data ?? {},
          },
        }),
      })
      if (res.ok) {
        sent += 1
      } else {
        const errBody = await res.json().catch(() => ({}))
        const status = errBody?.error?.status
        // The token no longer exists on the device (uninstalled / reset) —
        // self-clean so we stop trying to push to it.
        if (status === 'NOT_FOUND' || status === 'UNREGISTERED') {
          staleTokenIds.push(token)
        }
      }
    }

    if (staleTokenIds.length > 0) {
      await admin.from('device_tokens').delete().in('id', staleTokenIds)
    }

    return json({ ok: true, sent, staleRemoved: staleTokenIds.length })
  } catch (e) {
    return json({ error: String(e) }, 500)
  }
})
