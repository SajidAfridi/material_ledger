// Server-side completion for Yorks controlled-document uploads.
//
// The Flutter client can upload only to a path granted by a short-lived intent.
// This function downloads the private object with the service key, verifies its
// SHA-256 bytes, and invokes the service-only database finalizer.  It never
// accepts actor, role, path, classification or hash authority from the client.
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

function sha256Hex(bytes: ArrayBuffer): Promise<string> {
  return crypto.subtle.digest('SHA-256', bytes).then((digest) =>
    Array.from(new Uint8Array(digest), (byte) =>
      byte.toString(16).padStart(2, '0'),
    ).join(''),
  )
}

function uploadIntentId(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const id = value.trim()
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)
    ? id
    : null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405)

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'missing token' }, 401)

  const body = await req.json().catch(() => null) as Record<string, unknown> | null
  const intentId = uploadIntentId(body?.upload_intent_id)
  if (intentId == null) return json({ error: 'upload_intent_id is required' }, 400)

  const url = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !anonKey || !serviceKey) {
    return json({ error: 'document finalizer is not configured' }, 503)
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: identity, error: identityError } = await caller.auth.getUser()
  if (identityError || identity.user == null) return json({ error: 'unauthorized' }, 401)

  // The authenticated projection proves that this exact caller owns the live
  // intent.  It returns only the storage coordinates and expected metadata.
  const { data: intent, error: intentError } = await caller.rpc(
    'v1_document_upload_intent_projection',
    { p_upload_intent_id: intentId },
  )
  if (intentError || intent == null || typeof intent !== 'object') {
    return json({ error: 'upload intent is unavailable' }, 403)
  }
  const record = intent as Record<string, unknown>
  const bucketId = record.bucket_id
  const objectPath = record.object_path
  const expectedMimeType = record.mime_type
  const expectedByteSize = record.byte_size
  if (
    typeof bucketId !== 'string' || typeof objectPath !== 'string' ||
    typeof expectedMimeType !== 'string' || typeof expectedByteSize !== 'number'
  ) {
    return json({ error: 'upload intent is malformed' }, 409)
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: object, error: downloadError } = await admin.storage
    .from(bucketId)
    .download(objectPath)
  if (downloadError || object == null) {
    return json({ error: 'uploaded object is unavailable' }, 409)
  }
  const bytes = await object.arrayBuffer()
  if (bytes.byteLength !== expectedByteSize) {
    return json({ error: 'uploaded byte size does not match the intent' }, 409)
  }
  const verifiedHash = await sha256Hex(bytes)
  const { data: finalized, error: finalizerError } = await admin.rpc(
    'v1_create_document_version',
    {
      p_upload_intent_id: intentId,
      p_verified_sha256: verifiedHash,
      p_verified_byte_size: bytes.byteLength,
      p_verified_mime_type: expectedMimeType,
    },
  )
  if (finalizerError) {
    return json({ error: 'document finalization failed' }, 409)
  }
  return json(finalized)
})
