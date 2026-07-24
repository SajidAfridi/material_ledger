// admin-users — privileged user provisioning for Yorks GodownPro.
//
// The app can't hold the service_role key, so all Supabase Auth administration
// (create user, change role/claims, reset password, deactivate, delete) goes
// through this Edge Function. It:
//   1. requires a valid JWT (verify_jwt = true at deploy), and
//   2. additionally checks the caller's `app_metadata.role == 'admin'`,
// then performs the requested action with the service_role key.
//
// The app keys users by the stable `app_user_id` ('usr-*'); this function
// resolves that to the Supabase auth UUID (via the claim) for update/delete, so
// the app never has to store the UUID.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Role → default capabilities. Mirrors RoleCapability.defaultFor in the app; a
// fallback only — the app normally passes an explicit `caps` array.
const DEFAULT_CAPS: Record<string, string[]> = {
  admin: ['viewCommercials', 'salary', 'finance', 'rentals', 'writeRentals', 'people',
          'writePeople', 'goods', 'approveLeave'],
  procurement: ['viewCommercials', 'rentals', 'writeRentals', 'people', 'writePeople',
                'goods', 'approveLeave'],
  engineer: [],
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405)

  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // ── Authorize: caller must be a signed-in admin ──────────────────
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'missing token' }, 401)

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: who, error: whoErr } = await caller.auth.getUser()
  if (whoErr || !who?.user) return json({ error: 'unauthorized' }, 401)
  if (who.user.app_metadata?.role !== 'admin') {
    return json({ error: 'forbidden — admin only' }, 403)
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  // Resolve a stable app_user_id → Supabase auth UUID (paginated scan; the user
  // base is tiny). Returns null if not found.
  async function uidForAppUser(appUserId: string): Promise<string | null> {
    let page = 1
    for (;;) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 })
      if (error) throw error
      const hit = data.users.find(
        (u) => (u.app_metadata as Record<string, unknown>)?.app_user_id === appUserId,
      )
      if (hit) return hit.id
      if (data.users.length < 200) return null
      page += 1
    }
  }

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return json({ error: 'invalid JSON body' }, 400)
  }
  const action = body.action as string

  try {
    switch (action) {
      case 'create': {
        const { email, password, fullName, role, appUserId } = body as {
          email: string; password: string; fullName: string;
          role: string; appUserId: string
        }
        if (!email || !password || !role || !appUserId) {
          return json({ error: 'email, password, role, appUserId required' }, 400)
        }
        const caps = (body.caps as string[]) ?? DEFAULT_CAPS[role] ?? []
        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          // must_change_password lives in user_metadata (NOT app_metadata) so the
          // user can clear it themselves via the GoTrue self-update when they set
          // their own password — no admin/service-role round-trip needed. Follows
          // the user across devices (unlike the old device-local roster flag).
          user_metadata: { full_name: fullName ?? '', must_change_password: true },
          app_metadata: { role, app_user_id: appUserId, caps },
        })
        if (error) return json({ error: error.message }, 400)
        return json({ ok: true, authUserId: data.user!.id, appUserId })
      }

      case 'updateClaims': {
        const { appUserId, role } = body as { appUserId: string; role: string }
        const caps = (body.caps as string[]) ?? DEFAULT_CAPS[role] ?? []
        const uid = await uidForAppUser(appUserId)
        if (!uid) return json({ error: 'user not found' }, 404)
        const { error } = await admin.auth.admin.updateUserById(uid, {
          app_metadata: { role, app_user_id: appUserId, caps },
        })
        if (error) return json({ error: error.message }, 400)
        return json({ ok: true })
      }

      case 'setPassword': {
        // This action is only ever an ADMIN resetting SOMEONE ELSE's password
        // (self-service change goes through GoTrue self-update, not this fn), so
        // it always forces a change on the user's next sign-in. Merge the flag
        // into existing user_metadata so full_name etc. survive.
        const { appUserId, password } = body as { appUserId: string; password: string }
        if (!password) return json({ error: 'password required' }, 400)
        const uid = await uidForAppUser(appUserId)
        if (!uid) return json({ error: 'user not found' }, 404)
        const { data: cur } = await admin.auth.admin.getUserById(uid)
        const meta = {
          ...((cur?.user?.user_metadata as Record<string, unknown>) ?? {}),
          must_change_password: true,
        }
        const { error } = await admin.auth.admin.updateUserById(uid, {
          password,
          user_metadata: meta,
        })
        if (error) return json({ error: error.message }, 400)
        return json({ ok: true })
      }

      case 'setActive': {
        const { appUserId, active } = body as { appUserId: string; active: boolean }
        const uid = await uidForAppUser(appUserId)
        if (!uid) return json({ error: 'user not found' }, 404)
        // Deactivate = ban far into the future; reactivate = clear the ban.
        const { error } = await admin.auth.admin.updateUserById(uid, {
          ban_duration: active ? 'none' : '87600h',
        })
        if (error) return json({ error: error.message }, 400)
        return json({ ok: true })
      }

      case 'delete': {
        const { appUserId } = body as { appUserId: string }
        const uid = await uidForAppUser(appUserId)
        if (!uid) return json({ error: 'user not found' }, 404)
        const { error } = await admin.auth.admin.deleteUser(uid)
        if (error) return json({ error: error.message }, 400)
        return json({ ok: true })
      }

      default:
        return json({ error: `unknown action: ${action}` }, 400)
    }
  } catch (e) {
    return json({ error: String(e) }, 500)
  }
})
