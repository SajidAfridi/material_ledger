export const V1_ADMIN_AUDIT_CONTEXT_KEY = "_v1_admin_audit_context";

export type V1AdminAuditAction =
  | "created"
  | "role_changed"
  | "password_reset"
  | "active_changed";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA_256_HEX_PATTERN = /^[0-9a-f]{64}$/;

type CanonicalJson =
  | null
  | boolean
  | number
  | string
  | CanonicalJson[]
  | { [key: string]: CanonicalJson };

// The client creates this opaque command key once and preserves it if the
// transport retries. Keep it verbatim rather than normalising it in Edge: the
// database owns UUID parsing and a caller must not be able to change a key
// between attempts by relying on whitespace trimming.
export function isV1AdminAuditIdempotencyKey(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function canonicalJson(value: unknown): CanonicalJson {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (typeof value === "object") {
    const result: { [key: string]: CanonicalJson } = {};
    for (
      const [key, child] of Object.entries(value).sort(([left], [right]) =>
        left.localeCompare(right)
      )
    ) {
      result[key] = canonicalJson(child);
    }
    return result;
  }
  throw new TypeError("admin audit request contains a non-JSON value");
}

// Hash only the canonical, server-built semantic command. The service-role
// key stays in the Edge runtime, which makes the 64-hex value safe to retain in
// an audit row while still binding a password-reset retry to its password.
// Plaintext credentials never leave this HMAC input.
export async function v1AdminAuditRequestHash(
  hmacKey: string,
  operation: Record<string, unknown>,
): Promise<string> {
  if (hmacKey.length === 0) {
    throw new TypeError("admin audit HMAC key is required");
  }
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(hmacKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(JSON.stringify(canonicalJson(operation))),
  );
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

// Adds the only transient audit context the auth.users BEFORE trigger accepts.
// The Edge constructs actor/action after verified Auth lookup; no request-body
// value can influence it. The trigger validates and removes this key before
// the Auth row commits, so it never persists in a user's app metadata.
export function withV1AdminAuditContext(
  appMetadata: Record<string, unknown> | null | undefined,
  actorAuthUserId: string,
  action: V1AdminAuditAction,
  idempotencyKey: string,
  requestHash: string,
): Record<string, unknown> {
  if (!isV1AdminAuditIdempotencyKey(idempotencyKey)) {
    throw new TypeError("admin audit idempotency key must be a UUID");
  }
  if (!SHA_256_HEX_PATTERN.test(requestHash)) {
    throw new TypeError(
      "admin audit request hash must be lowercase SHA-256 hex",
    );
  }
  const next = { ...(appMetadata ?? {}) };
  // Never carry an existing/transmitted context across a separate mutation.
  delete next[V1_ADMIN_AUDIT_CONTEXT_KEY];
  next[V1_ADMIN_AUDIT_CONTEXT_KEY] = {
    actor_auth_user_id: actorAuthUserId,
    action,
    idempotency_key: idempotencyKey,
    request_hash: requestHash,
  };
  return next;
}
