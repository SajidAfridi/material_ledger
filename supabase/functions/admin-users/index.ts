// admin-users — privileged user provisioning for Yorks GodownPro.
//
// The app can't hold the service_role key, so all Supabase Auth administration
// (create user, change role/claims, reset password, deactivate, delete) goes
// through this Edge Function. It:
//   1. requires a valid JWT (verify_jwt = true at deploy), and
//   2. checks the caller's live action-specific database capability,
// then performs the requested action with the service_role key.
//
// The app keys users by the stable `app_user_id` ('usr-*'); this function
// resolves that to the Supabase auth UUID (via the claim) for update/delete, so
// the app never has to store the UUID.
import { createClient } from "jsr:@supabase/supabase-js@2";

import {
  isV1AdminAuditIdempotencyKey,
  v1AdminAuditRequestHash,
  v1AdminProvisioningIntentHash,
  v1AdminProvisioningPendingMatches,
  v1AdminProvisioningRecoveryMatches,
  withV1AdminAuditContext,
  withV1AdminProvisioningPending,
} from "./auth_audit_context.ts";
import { authMutationFailure } from "./auth_mutation_error.ts";
import {
  commercialCapabilityError,
  commercialCapabilityMutationInput,
  commercialCapabilityRpcPayload,
  opaqueCommercialCapabilitiesResponse,
} from "./commercial_capabilities.ts";
import { legacyShellCaps } from "./legacy_caps.ts";
import {
  defaultCapsForRoles,
  hasForbiddenV1ClaimInput,
  provisionableRole,
  provisionableRoles,
} from "./role_claims.ts";
import {
  type AuthUserForAdminGuard,
  isActiveAuthUser,
  isLastActiveExactAdmin,
} from "./last_active_admin_guard.ts";
import { requiredCapabilityForAdminUserAction } from "./permission_action_access.ts";
import { canUseLegacyUserAdministration } from "./user_configuration_access.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// This server-owned map supplies every exact Yorks V1 command. The retained
// flag-off shell may request only the finite compatibility allow-list in
// `legacy_caps.ts`; no caller-provided array is copied into Auth metadata.
// V1 commercial authorization is separately resolved by protected database
// capabilities, not this legacy-shell compatibility claim.
const LEGACY_ENGINEER_ROLE = "engineer";

// A deliberately quarantined compatibility role. It is never accepted by the
// normal V1 command path and the V1 auth-profile trigger leaves it without a
// V1 profile or authority until an Admin explicitly maps it through the exact
// `updateClaims` route.
function isLegacyEngineerRole(value: unknown): boolean {
  return value === LEGACY_ENGINEER_ROLE;
}

function validAppUserId(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0 &&
    value.length <= 128;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

function authIdempotencyConflict(): Response {
  return json(
    { error: "a conflicting authentication command already exists" },
    409,
  );
}

function authMutationError(
  error: { message?: string } | null,
  lastAdminMessage?: string,
): Response {
  const failure = authMutationFailure(error, lastAdminMessage);
  return json({ error: failure.error }, failure.status);
}

type CreatedUserReplay =
  | { kind: "none" }
  | { kind: "success"; authUserId: string }
  | { kind: "conflict" };

function commercialCapabilityRpcError(
  error: { code?: unknown; message?: unknown } | null,
): Response {
  const mapped = commercialCapabilityError(error);
  return json({ error: mapped.message }, mapped.status);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ── Authenticate first; action-specific authorization follows parsing. ──
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "missing token" }, 401);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: who, error: whoErr } = await caller.auth.getUser();
  if (whoErr || !who?.user) return json({ error: "unauthorized" }, 401);
  if (!isActiveAuthUser(who.user as AuthUserForAdminGuard)) {
    return json(
      { error: "forbidden — inactive user configuration account" },
      403,
    );
  }
  const actorAuthUserId = who.user.id;
  // Capture the authenticated actor claim before entering nested async
  // provisioning helpers. TypeScript cannot retain object-property narrowing
  // across those closures, and authorization must never fall back to a later
  // nullable read of the Auth response.
  const actorRawRole = who.user.app_metadata?.role;

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Read the current Auth directory (paginated; the user base is tiny). This is
  // intentionally server-side so the last-active-Admin guard cannot be bypassed
  // through a direct Edge request that omits the local Flutter roster.
  async function listAuthUsers(): Promise<AuthUserForAdminGuard[]> {
    let page = 1;
    const users: AuthUserForAdminGuard[] = [];
    for (;;) {
      const { data, error } = await admin.auth.admin.listUsers({
        page,
        perPage: 200,
      });
      if (error) throw error;
      users.push(...(data.users as AuthUserForAdminGuard[]));
      if (data.users.length < 200) return users;
      page += 1;
    }
  }

  async function authUserForAppUser(
    users: readonly AuthUserForAdminGuard[],
    appUserId: string,
  ): Promise<AuthUserForAdminGuard | null> {
    const metadataMatch = users.find(
      (user) => user.app_metadata?.app_user_id === appUserId,
    );
    if (metadataMatch != null) return metadataMatch;

    // Older canonical identities may have been reconciled into v1_profiles
    // before their Auth metadata was restamped. Resolve that server-owned
    // mapping without ever accepting or returning an Auth UUID as an app ID.
    const { data, error } = await admin
      .from("v1_profiles")
      .select("auth_user_id")
      .eq("legacy_app_user_id", appUserId)
      .maybeSingle();
    if (error) throw error;
    if (typeof data?.auth_user_id !== "string") return null;
    return users.find((user) => user.id === data.auth_user_id) ?? null;
  }

  // Resolve a stable app_user_id → Supabase auth UUID. Callers that also need
  // the live user directory use [listAuthUsers] once and then [authUserForAppUser]
  // to make the guard and target lookup operate on the same snapshot.
  async function uidForAppUser(appUserId: string): Promise<string | null> {
    return (await authUserForAppUser(await listAuthUsers(), appUserId))?.id ??
      null;
  }

  // A successful create has no stable Auth UUID until GoTrue assigns one. On a
  // lost-response retry, recover only the exact prior command from its trusted
  // audit row and the current app-user mapping. This avoids treating an
  // arbitrary existing appUserId as a successful replay, while preventing a
  // second INSERT (which would have a different Auth UUID) from becoming a
  // conflicting mutation.
  async function replayCreatedUser(
    appUserId: string,
    idempotencyKey: string,
    requestHash: string,
  ): Promise<CreatedUserReplay> {
    const { data, error } = await admin
      .from("v1_audit_events")
      .select("entity_id, request_hash")
      .eq("event_type", "admin_user_created")
      .eq("actor_auth_user_id", actorAuthUserId)
      .eq("idempotency_key", idempotencyKey)
      .limit(2);
    if (error) throw error;

    const rows = (data ?? []) as Array<{
      entity_id: string;
      request_hash: string | null;
    }>;
    if (rows.length === 0) return { kind: "none" };
    if (rows.length !== 1 || rows[0].request_hash !== requestHash) {
      return { kind: "conflict" };
    }

    const target = await authUserForAppUser(await listAuthUsers(), appUserId);
    if (target?.id !== rows[0].entity_id) return { kind: "conflict" };
    return { kind: "success", authUserId: target.id };
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const action = body.action as string;
  const requiredCapability = requiredCapabilityForAdminUserAction(action);
  if (requiredCapability == null) {
    return json({ error: `unknown action: ${String(action)}` }, 400);
  }
  const { data: actionAllowed, error: actionAccessError } = await caller.rpc(
    "v1_current_user_has_capability",
    {
      p_capability_key: requiredCapability,
      p_project_id: null,
    },
  );
  if (actionAccessError) {
    return json({ error: "user permission service unavailable" }, 503);
  }
  if (actionAllowed !== true) {
    return json({ error: "forbidden — action permission required" }, 403);
  }

  try {
    switch (action) {
      case "list": {
        // The Admin directory is sourced from Supabase Auth, not a device-local
        // Flutter roster. Return only the stable identity and server-owned
        // access projection needed by User Management.
        const users = await listAuthUsers();
        const { data: profileRows, error: profileError } = await admin
          .from("v1_profiles")
          .select("auth_user_id, legacy_app_user_id");
        if (profileError) throw profileError;
        const profileAppUserIds = new Map<string, string>();
        for (const row of profileRows ?? []) {
          if (
            typeof row.auth_user_id === "string" &&
            validAppUserId(row.legacy_app_user_id)
          ) {
            profileAppUserIds.set(row.auth_user_id, row.legacy_app_user_id);
          }
        }
        const directory = users.flatMap((user) => {
          const appMetadata = user.app_metadata ?? {};
          const stableAppUserId = validAppUserId(appMetadata.app_user_id)
            ? appMetadata.app_user_id
            : profileAppUserIds.get(user.id);
          // Quarantined/unmapped identities are intentionally omitted rather
          // than exposing the private Auth UUID as a client-selectable target.
          if (!validAppUserId(stableAppUserId)) return [];
          const authRecord = user as AuthUserForAdminGuard & {
            email?: string;
            created_at?: string;
            user_metadata?: Record<string, unknown> | null;
          };
          const metadata = authRecord.user_metadata ?? {};
          const rawRoles = Array.isArray(appMetadata.roles)
            ? appMetadata.roles.filter((role: unknown) =>
              typeof role === "string"
            )
            : [];
          const primaryRole = typeof appMetadata.role === "string"
            ? appMetadata.role
            : null;
          const roles = primaryRole != null && !rawRoles.includes(primaryRole)
            ? [primaryRole, ...rawRoles]
            : rawRoles;
          return [{
            appUserId: stableAppUserId,
            fullName: typeof metadata.full_name === "string"
              ? metadata.full_name
              : "",
            email: authRecord.email ?? "",
            active: isActiveAuthUser(user),
            createdAt: authRecord.created_at ?? new Date().toISOString(),
            role: primaryRole,
            roles,
          }];
        });
        return json({
          ok: true,
          users: directory,
        });
      }

      case "getV1CommercialCapabilities": {
        // The stable app-user key is the only target identifier accepted from
        // Flutter. Resolve it against the live Auth directory, then invoke the
        // protected RPC with the caller's JWT so Postgres re-checks the live
        // action capability through auth.uid().
        const { appUserId } = body as { appUserId: string };
        if (!validAppUserId(appUserId)) {
          return json({ error: "valid appUserId required" }, 400);
        }
        const target = await authUserForAppUser(
          await listAuthUsers(),
          appUserId,
        );
        if (!target) return json({ error: "user not found" }, 404);
        const { data, error } = await caller.rpc(
          "v1_get_user_commercial_capabilities",
          { p_target_auth_user_id: target.id },
        );
        if (error) return commercialCapabilityRpcError(error);
        const projection = opaqueCommercialCapabilitiesResponse(data);
        if (!projection) {
          return json(
            { error: "unexpected commercial capability response" },
            502,
          );
        }
        return json({ ok: true, ...projection });
      }

      case "setV1CommercialCapability": {
        // Do not accept an Auth UUID or role from the client. The only target
        // lookup path is appUserId -> live server-side Auth directory.
        const { appUserId } = body as { appUserId: string };
        const input = commercialCapabilityMutationInput(body);
        if (!validAppUserId(appUserId) || input === null) {
          return json(
            {
              error:
                "valid appUserId, capability, granted, reason and idempotencyKey required",
            },
            400,
          );
        }
        const target = await authUserForAppUser(
          await listAuthUsers(),
          appUserId,
        );
        if (!target) return json({ error: "user not found" }, 404);
        const { data, error } = await caller.rpc(
          "v1_set_user_commercial_capability",
          {
            p_payload: commercialCapabilityRpcPayload(target.id, input),
            p_idempotency_key: input.idempotencyKey,
          },
        );
        if (error) return commercialCapabilityRpcError(error);
        const projection = opaqueCommercialCapabilitiesResponse(data);
        if (!projection) {
          return json(
            { error: "unexpected commercial capability response" },
            502,
          );
        }
        return json({ ok: true, ...projection });
      }

      case "create": {
        const { email, password, fullName, appUserId } = body as {
          email: string;
          password: string;
          fullName: string;
          appUserId: string;
        };
        const role = provisionableRole(body.role);
        const roles = role == null
          ? null
          : provisionableRoles(body.roles, role);
        const idempotencyKey = body.idempotencyKey;
        if (
          !email ||
          !password ||
          !role ||
          roles == null ||
          hasForbiddenV1ClaimInput(body) ||
          !validAppUserId(appUserId) ||
          !isV1AdminAuditIdempotencyKey(idempotencyKey)
        ) {
          return json(
            {
              error:
                "email, password, role, appUserId and idempotencyKey required",
            },
            400,
          );
        }
        const requestedRole = role;
        const provisioningIdempotencyKey: string = idempotencyKey;
        // User creation and exact-role assignment are deliberately separate
        // authorities. Check the requested server role before GoTrue creates
        // an identity, otherwise a delegated `users.create` grant could mint
        // a role above the actor's database-owned delegation ceiling (or leave
        // a partially provisioned, role-less identity after a denied stamp).
        const { data: canAssignNewRole, error: newRoleAccessError } =
          await caller
            .rpc("v1_current_user_can_assign_new_exact_role", {
              p_requested_exact_role: role,
            });
        if (newRoleAccessError) {
          return json({ error: "role assignment service unavailable" }, 503);
        }
        if (canAssignNewRole !== true) {
          return json({ error: "forbidden — role assignment denied" }, 403);
        }
        // The exact role and compatibility claims are server-owned for V1.
        // `roles` may be omitted or echo the same singleton role only; caps
        // and the legacy-shell switch are rejected above rather than filtered.
        const caps = defaultCapsForRoles([requestedRole]);
        const requestHash = await v1AdminAuditRequestHash(serviceKey, {
          version: 1,
          action: "create",
          app_user_id: appUserId,
          email,
          password,
          full_name: fullName ?? "",
          role: requestedRole,
          roles,
          caps,
          email_confirm: true,
          must_change_password: true,
        });
        const provisioningIntentHash = await v1AdminProvisioningIntentHash(
          serviceKey,
          actorAuthUserId,
          appUserId,
          email,
          requestedRole,
        );
        const replay = await replayCreatedUser(
          appUserId,
          idempotencyKey,
          requestHash,
        );
        if (replay.kind === "success") {
          return json({ ok: true, appUserId });
        }
        if (replay.kind === "conflict") return authIdempotencyConflict();

        async function completeProvisioning(
          target: AuthUserForAdminGuard,
        ): Promise<Response> {
          const ordinaryRetry = v1AdminProvisioningPendingMatches(
            target.app_metadata,
            actorAuthUserId,
            appUserId,
            email,
            requestedRole,
            provisioningIdempotencyKey,
            requestHash,
            provisioningIntentHash,
          );
          const targetRecord = target as AuthUserForAdminGuard & {
            email?: string;
            user_metadata?: Record<string, unknown> | null;
          };
          const targetEmailMatches =
            targetRecord.email?.trim().toLowerCase() ===
              email.trim().toLowerCase();
          const exactAdminRecovery = !ordinaryRetry &&
            actorRawRole === "admin" &&
            targetEmailMatches &&
            await v1AdminProvisioningRecoveryMatches(
              target.app_metadata,
              serviceKey,
              actorAuthUserId,
              appUserId,
              email,
              requestedRole,
            );
          if (!ordinaryRetry && !exactAdminRecovery) {
            return json({ error: "appUserId already exists" }, 409);
          }
          const pendingMetadata = target.app_metadata ?? {};
          const { error: roleError } = await admin.auth.admin.updateUserById(
            target.id,
            {
              ...(exactAdminRecovery
                ? {
                  password,
                  user_metadata: {
                    ...(targetRecord.user_metadata ?? {}),
                    full_name: fullName ?? "",
                    must_change_password: true,
                  },
                }
                : {}),
              app_metadata: withV1AdminAuditContext(
                {
                  ...pendingMetadata,
                  role: requestedRole,
                  roles: [requestedRole],
                  app_user_id: appUserId,
                  caps,
                },
                actorAuthUserId,
                exactAdminRecovery ? "provisioning_recovered" : "provisioned",
                provisioningIdempotencyKey,
                requestHash,
              ),
            },
          );
          if (roleError) {
            // An identical concurrent completion can win after this request
            // read the pending marker. Recover the committed command from the
            // immutable audit instead of surfacing a false failure.
            const completedReplay = await replayCreatedUser(
              appUserId,
              provisioningIdempotencyKey,
              requestHash,
            );
            if (completedReplay.kind === "success") {
              return json({ ok: true, appUserId });
            }
            if (completedReplay.kind === "conflict") {
              return authIdempotencyConflict();
            }
            return authMutationError(roleError);
          }
          return json({ ok: true, appUserId });
        }

        const existingTarget = await authUserForAppUser(
          await listAuthUsers(),
          appUserId,
        );
        if (existingTarget != null) {
          return await completeProvisioning(existingTarget);
        }
        // GoTrue may perform a follow-up metadata update as part of
        // createUser.  Create the identity without a canonical role first so
        // that update is quarantined safely; the explicit role assignment
        // below is then performed through the audited role-mapping path.
        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          // must_change_password lives in user_metadata (NOT app_metadata) so the
          // user can clear it themselves via the GoTrue self-update when they set
          // their own password — no admin/service-role round-trip needed. Follows
          // the user across devices (unlike the old device-local roster flag).
          user_metadata: {
            full_name: fullName ?? "",
            must_change_password: true,
          },
          app_metadata: {
            ...withV1AdminProvisioningPending(
              { app_user_id: appUserId },
              actorAuthUserId,
              appUserId,
              email,
              role,
              idempotencyKey,
              requestHash,
              provisioningIntentHash,
            ),
          },
        });
        if (error) {
          // A concurrent identical create can lose the INSERT race after the
          // pre-flight lookup. Re-check the committed trusted audit before
          // reporting the GoTrue error to make that retry safely successful.
          const completedReplay = await replayCreatedUser(
            appUserId,
            idempotencyKey,
            requestHash,
          );
          if (completedReplay.kind === "success") {
            return json({
              ok: true,
              appUserId,
            });
          }
          if (completedReplay.kind === "conflict") {
            return authIdempotencyConflict();
          }
          const pendingTarget = await authUserForAppUser(
            await listAuthUsers(),
            appUserId,
          );
          if (pendingTarget != null) {
            return await completeProvisioning(pendingTarget);
          }
          return authMutationError(error);
        }
        return await completeProvisioning(data.user! as AuthUserForAdminGuard);
      }

      case "createLegacy": {
        // This narrow compatibility action exists only while the legacy shell
        // remains flag-off. It cannot mint a V1 role, profile or protected V1
        // capability: `engineer` is intentionally not in PROVISIONABLE_ROLES.
        const { email, password, fullName, appUserId } = body as {
          email: string;
          password: string;
          fullName: string;
          appUserId: string;
        };
        const idempotencyKey = body.idempotencyKey;
        if (
          !canUseLegacyUserAdministration(
            actorRawRole,
            Deno.env.get("R35_ENABLE_LEGACY_USER_ADMIN"),
          )
        ) {
          return json({ error: "legacy user administration is disabled" }, 403);
        }
        if (
          !email ||
          !password ||
          !validAppUserId(appUserId) ||
          !isLegacyEngineerRole(body.role) ||
          body.legacyShell !== true ||
          !isV1AdminAuditIdempotencyKey(idempotencyKey)
        ) {
          return json(
            {
              error:
                "email, password, legacy engineer role, appUserId and idempotencyKey required",
            },
            400,
          );
        }
        const caps = legacyShellCaps(body, []);
        const requestHash = await v1AdminAuditRequestHash(serviceKey, {
          version: 1,
          action: "createLegacy",
          app_user_id: appUserId,
          email,
          password,
          full_name: fullName ?? "",
          role: LEGACY_ENGINEER_ROLE,
          caps,
          legacy_shell: true,
          email_confirm: true,
          must_change_password: true,
        });
        const replay = await replayCreatedUser(
          appUserId,
          idempotencyKey,
          requestHash,
        );
        if (replay.kind === "success") {
          return json({ ok: true, appUserId });
        }
        if (replay.kind === "conflict") return authIdempotencyConflict();
        if (await uidForAppUser(appUserId)) {
          return json({ error: "appUserId already exists" }, 409);
        }
        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: {
            full_name: fullName ?? "",
            must_change_password: true,
          },
          // The explicit legacy marker permits only allow-listed compatibility
          // claims. The database trigger still quarantines this role rather
          // than materialising a V1 profile or authority.
          app_metadata: {
            ...withV1AdminAuditContext(
              {
                role: LEGACY_ENGINEER_ROLE,
                app_user_id: appUserId,
                caps,
              },
              actorAuthUserId,
              "created",
              idempotencyKey,
              requestHash,
            ),
          },
        });
        if (error) {
          const completedReplay = await replayCreatedUser(
            appUserId,
            idempotencyKey,
            requestHash,
          );
          if (completedReplay.kind === "success") {
            return json({
              ok: true,
              appUserId,
            });
          }
          if (completedReplay.kind === "conflict") {
            return authIdempotencyConflict();
          }
          return authMutationError(error);
        }
        return json({ ok: true, appUserId });
      }

      case "updateClaims": {
        const { appUserId } = body as { appUserId: string };
        const role = provisionableRole(body.role);
        const roles = role == null
          ? null
          : provisionableRoles(body.roles, role);
        const idempotencyKey = body.idempotencyKey;
        if (
          !role ||
          roles == null ||
          hasForbiddenV1ClaimInput(body) ||
          !validAppUserId(appUserId) ||
          !isV1AdminAuditIdempotencyKey(idempotencyKey)
        ) {
          return json({
            error: "valid role, appUserId and idempotencyKey required",
          }, 400);
        }
        const authUsers = await listAuthUsers();
        const target = await authUserForAppUser(authUsers, appUserId);
        if (!target) return json({ error: "user not found" }, 404);
        // `users.roles.assign` says whether the action surface is available;
        // this second, target-aware database preflight enforces the protected
        // delegation ceiling, active/stale identity checks and the no-self
        // rule immediately before the service-role Auth mutation. Never
        // duplicate those rules in this Edge runtime.
        const { data: canAssignRole, error: roleAccessError } = await caller
          .rpc(
            "v1_current_user_can_assign_exact_role",
            {
              p_target_app_user_id: appUserId,
              p_requested_exact_role: role,
            },
          );
        if (roleAccessError) {
          return json({ error: "role assignment service unavailable" }, 503);
        }
        if (canAssignRole !== true) {
          return json({ error: "forbidden — role assignment denied" }, 403);
        }
        if (
          role !== "admin" &&
          isLastActiveExactAdmin(authUsers, target.id)
        ) {
          return json(
            { error: "Cannot demote the last active Admin." },
            409,
          );
        }
        const caps = defaultCapsForRoles([role]);
        const requestHash = await v1AdminAuditRequestHash(serviceKey, {
          version: 1,
          action: "updateClaims",
          app_user_id: appUserId,
          target_auth_user_id: target.id,
          role,
          roles,
          caps,
        });
        const { error } = await admin.auth.admin.updateUserById(target.id, {
          app_metadata: {
            ...withV1AdminAuditContext(
              { role, roles, app_user_id: appUserId, caps },
              actorAuthUserId,
              "role_changed",
              idempotencyKey,
              requestHash,
            ),
          },
        });
        if (error) {
          return authMutationError(
            error,
            "Cannot demote the last active Admin.",
          );
        }
        return json({ ok: true });
      }

      case "updateLegacyClaims": {
        // Keep the compatibility boundary one-way. A caller may refresh an
        // already-quarantined legacy engineer, but cannot use the legacy route
        // to demote, overwrite or otherwise alter an exact V1 identity.
        const { appUserId } = body as { appUserId: string };
        const idempotencyKey = body.idempotencyKey;
        if (
          !canUseLegacyUserAdministration(
            actorRawRole,
            Deno.env.get("R35_ENABLE_LEGACY_USER_ADMIN"),
          )
        ) {
          return json({ error: "legacy user administration is disabled" }, 403);
        }
        if (
          !validAppUserId(appUserId) ||
          !isLegacyEngineerRole(body.role) ||
          body.legacyShell !== true ||
          !isV1AdminAuditIdempotencyKey(idempotencyKey)
        ) {
          return json(
            {
              error:
                "legacy engineer role, appUserId and idempotencyKey required",
            },
            400,
          );
        }
        const authUsers = await listAuthUsers();
        const target = await authUserForAppUser(authUsers, appUserId);
        if (!target) return json({ error: "user not found" }, 404);
        if (target.id === actorAuthUserId) {
          return json(
            { error: "forbidden — legacy role update cannot target self" },
            403,
          );
        }
        const { data: current, error: currentError } = await admin.auth.admin
          .getUserById(target.id);
        if (currentError) return json({ error: currentError.message }, 400);
        if (current.user?.app_metadata?.role !== LEGACY_ENGINEER_ROLE) {
          return json(
            {
              error:
                "legacy role update is only allowed for legacy engineer accounts",
            },
            409,
          );
        }
        const caps = legacyShellCaps(body, []);
        const requestHash = await v1AdminAuditRequestHash(serviceKey, {
          version: 1,
          action: "updateLegacyClaims",
          app_user_id: appUserId,
          target_auth_user_id: target.id,
          role: LEGACY_ENGINEER_ROLE,
          caps,
          legacy_shell: true,
        });
        const { error } = await admin.auth.admin.updateUserById(target.id, {
          app_metadata: {
            ...withV1AdminAuditContext(
              {
                role: LEGACY_ENGINEER_ROLE,
                app_user_id: appUserId,
                caps,
              },
              actorAuthUserId,
              "role_changed",
              idempotencyKey,
              requestHash,
            ),
          },
        });
        if (error) return authMutationError(error);
        return json({ ok: true });
      }

      case "setPassword": {
        // This action is only ever an ADMIN resetting SOMEONE ELSE's password
        // (self-service change goes through GoTrue self-update, not this fn), so
        // it always forces a change on the user's next sign-in. Merge the flag
        // into existing user_metadata so full_name etc. survive.
        const { appUserId, password } = body as {
          appUserId: string;
          password: string;
        };
        const idempotencyKey = body.idempotencyKey;
        if (
          !password ||
          !validAppUserId(appUserId) ||
          !isV1AdminAuditIdempotencyKey(idempotencyKey)
        ) {
          return json({
            error: "password, appUserId and idempotencyKey required",
          }, 400);
        }
        const authUsers = await listAuthUsers();
        const target = await authUserForAppUser(authUsers, appUserId);
        if (!target) return json({ error: "user not found" }, 404);
        if (target.id === actorAuthUserId) {
          return json(
            { error: "forbidden — password reset cannot target self" },
            403,
          );
        }
        const { data: canResetPassword, error: passwordAccessError } =
          await caller.rpc("v1_current_user_can_administer_auth_target", {
            p_target_app_user_id: appUserId,
            p_capability_key: "users.password.reset",
          });
        if (passwordAccessError) {
          return json({ error: "user target service unavailable" }, 503);
        }
        if (canResetPassword !== true) {
          return json({ error: "forbidden — password reset denied" }, 403);
        }
        const { data: cur } = await admin.auth.admin.getUserById(target.id);
        const meta = {
          ...((cur?.user?.user_metadata as Record<string, unknown>) ?? {}),
          must_change_password: true,
        };
        const requestHash = await v1AdminAuditRequestHash(serviceKey, {
          version: 1,
          action: "setPassword",
          app_user_id: appUserId,
          target_auth_user_id: target.id,
          password,
          must_change_password: true,
        });
        const { error } = await admin.auth.admin.updateUserById(target.id, {
          password,
          user_metadata: meta,
          app_metadata: withV1AdminAuditContext(
            (cur?.user?.app_metadata as Record<string, unknown> | undefined) ??
              target.app_metadata,
            actorAuthUserId,
            "password_reset",
            idempotencyKey,
            requestHash,
          ),
        });
        if (error) return authMutationError(error);
        return json({ ok: true });
      }

      case "setActive": {
        const { appUserId, active } = body as {
          appUserId: string;
          active: boolean;
        };
        const idempotencyKey = body.idempotencyKey;
        if (
          !validAppUserId(appUserId) ||
          typeof active !== "boolean" ||
          !isV1AdminAuditIdempotencyKey(idempotencyKey)
        ) {
          return json(
            { error: "appUserId, boolean active and idempotencyKey required" },
            400,
          );
        }
        const authUsers = await listAuthUsers();
        const target = await authUserForAppUser(authUsers, appUserId);
        if (!target) return json({ error: "user not found" }, 404);
        // Activation authority is never self-service. Allowing an access
        // manager to ban their own identity would mutate every effective
        // permission outside the versioned permission workspace and could
        // strand an in-flight administration session.
        if (target.id === actorAuthUserId) {
          return json(
            { error: "forbidden — account activation cannot target self" },
            403,
          );
        }
        const { data: canManageActivation, error: activationAccessError } =
          await caller.rpc("v1_current_user_can_administer_auth_target", {
            p_target_app_user_id: appUserId,
            p_capability_key: "users.activation.manage",
          });
        if (activationAccessError) {
          return json({ error: "user target service unavailable" }, 503);
        }
        if (canManageActivation !== true) {
          return json({ error: "forbidden — account activation denied" }, 403);
        }
        if (!active && isLastActiveExactAdmin(authUsers, target.id)) {
          return json(
            { error: "Cannot deactivate the last active Admin." },
            409,
          );
        }
        const { data: current, error: currentError } = await admin.auth.admin
          .getUserById(target.id);
        if (currentError) return json({ error: currentError.message }, 400);
        // Deactivate = ban far into the future; reactivate = clear the ban.
        const requestHash = await v1AdminAuditRequestHash(serviceKey, {
          version: 1,
          action: "setActive",
          app_user_id: appUserId,
          target_auth_user_id: target.id,
          active,
        });
        const { error } = await admin.auth.admin.updateUserById(target.id, {
          ban_duration: active ? "none" : "87600h",
          app_metadata: withV1AdminAuditContext(
            (current.user?.app_metadata as
              | Record<string, unknown>
              | undefined) ??
              target.app_metadata,
            actorAuthUserId,
            "active_changed",
            idempotencyKey,
            requestHash,
          ),
        });
        if (error) {
          return authMutationError(
            error,
            "Cannot deactivate the last active Admin.",
          );
        }
        return json({ ok: true });
      }

      case "delete": {
        // V1 preserves membership/audit attribution. Account removal is not a
        // valid administrative action; callers must use setActive(false), which
        // bans the account and lets the Auth-triggered profile mirror retain it.
        return json(
          {
            error:
              "User deletion is not supported; deactivate the user instead.",
          },
          409,
        );
      }

      default:
        return json({ error: `unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
