export interface AuthMutationFailure {
  readonly error: string;
  readonly status: number;
}

/// Maps durable Auth-trigger failures to a stable, non-sensitive Edge result.
/// Capability revocation is intentionally distinct from account inactivity so
/// callers do not receive misleading remediation guidance after a live grant
/// is removed between Edge preflight and the GoTrue mutation.
export function authMutationFailure(
  error: { message?: string } | null,
  lastAdminMessage?: string,
): AuthMutationFailure {
  const message = error?.message ?? "authentication update failed";
  if (
    message.includes("V1_AUTH_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST")
  ) {
    return {
      error: "a conflicting authentication command already exists",
      status: 409,
    };
  }
  if (
    lastAdminMessage != null &&
    message.includes("V1_LAST_ACTIVE_ADMIN_REQUIRED")
  ) {
    return { error: lastAdminMessage, status: 409 };
  }
  if (message.includes("V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN")) {
    return {
      error: "forbidden — inactive user configuration account",
      status: 403,
    };
  }
  if (
    message.includes("V1_ADMIN_AUDIT_CONTEXT_ACTOR_CAPABILITY_REQUIRED") ||
    message.includes("V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED") ||
    message.includes("V1_ADMIN_AUDIT_SELF_MUTATION_DENIED")
  ) {
    return {
      error: "forbidden — user administration denied",
      status: 403,
    };
  }
  return { error: message, status: 400 };
}
