import {
  assert,
  assertEquals,
  assertMatch,
  assertNotEquals,
} from "jsr:@std/assert@1";

import {
  isV1AdminAuditIdempotencyKey,
  V1_ADMIN_AUDIT_CONTEXT_KEY,
  v1AdminAuditRequestHash,
  withV1AdminAuditContext,
} from "./auth_audit_context.ts";

Deno.test("builds a finite server-owned auth audit context and replaces stale context", () => {
  const idempotencyKey = "30000000-0000-4000-8000-000000000001";
  const requestHash = "a".repeat(64);
  const metadata = withV1AdminAuditContext(
    {
      role: "procurement",
      app_user_id: "usr-target",
      caps: ["viewCommercials"],
      [V1_ADMIN_AUDIT_CONTEXT_KEY]: {
        actor_auth_user_id: "untrusted-old-value",
        action: "created",
      },
    },
    "verified-admin-auth-user-id",
    "role_changed",
    idempotencyKey,
    requestHash,
  );

  assertEquals(metadata.role, "procurement");
  assertEquals(metadata.app_user_id, "usr-target");
  assertEquals(metadata[V1_ADMIN_AUDIT_CONTEXT_KEY], {
    actor_auth_user_id: "verified-admin-auth-user-id",
    action: "role_changed",
    idempotency_key: idempotencyKey,
    request_hash: requestHash,
  });
});

Deno.test("accepts only a client UUID idempotency key", () => {
  assert(isV1AdminAuditIdempotencyKey("30000000-0000-4000-8000-000000000001"));
  assert(!isV1AdminAuditIdempotencyKey(" not-a-uuid "));
  assert(
    !isV1AdminAuditIdempotencyKey("30000000-0000-4000-8000-000000000001 "),
  );
});

Deno.test("hashes canonical semantic input without retaining plaintext password", async () => {
  const key = "server-only-service-role-key";
  const first = await v1AdminAuditRequestHash(key, {
    action: "setPassword",
    app_user_id: "usr-target",
    password: "temporary-password",
    must_change_password: true,
  });
  const reordered = await v1AdminAuditRequestHash(key, {
    must_change_password: true,
    password: "temporary-password",
    app_user_id: "usr-target",
    action: "setPassword",
  });
  const changedPassword = await v1AdminAuditRequestHash(key, {
    action: "setPassword",
    app_user_id: "usr-target",
    password: "different-password",
    must_change_password: true,
  });

  assertEquals(first, reordered);
  assertNotEquals(first, changedPassword);
  assertMatch(first, /^[0-9a-f]{64}$/);
  assert(!first.includes("temporary-password"));
});
