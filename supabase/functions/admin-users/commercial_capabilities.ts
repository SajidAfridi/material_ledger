export const V1_COMMERCIAL_CAPABILITIES = [
  "view_commercials",
  "manage_commercials",
] as const;

export type V1CommercialCapability =
  (typeof V1_COMMERCIAL_CAPABILITIES)[number];

export interface CommercialCapabilityMutationInput {
  capability: V1CommercialCapability;
  granted: boolean;
  reason: string;
  idempotencyKey: string;
}

type CommercialCapabilityAccess = {
  role_default: boolean;
  effective: boolean;
  override: boolean | null;
};

export type OpaqueCommercialCapabilitiesResponse = {
  capabilities: Record<V1CommercialCapability, CommercialCapabilityAccess>;
};

type RpcError = {
  code?: unknown;
  message?: unknown;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function commercialCapabilityFromRequest(
  value: unknown,
): V1CommercialCapability | null {
  return typeof value === "string" &&
      (V1_COMMERCIAL_CAPABILITIES as readonly string[]).includes(value)
    ? value as V1CommercialCapability
    : null;
}

export function commercialCapabilityMutationInput(
  body: Record<string, unknown>,
): CommercialCapabilityMutationInput | null {
  const capability = commercialCapabilityFromRequest(body.capability);
  const reason = typeof body.reason === "string" ? body.reason.trim() : "";
  const idempotencyKey = typeof body.idempotencyKey === "string"
    ? body.idempotencyKey.trim()
    : "";
  if (
    capability === null ||
    typeof body.granted !== "boolean" ||
    reason.length === 0 ||
    reason.length > 2000 ||
    !uuidPattern.test(idempotencyKey)
  ) {
    return null;
  }
  return {
    capability,
    granted: body.granted,
    reason,
    idempotencyKey,
  };
}

// The target UUID is deliberately supplied only after the Edge service resolves
// the stable appUserId from the live Auth directory. Request fields such as
// targetAuthUserId or role cannot reach the protected database command.
export function commercialCapabilityRpcPayload(
  targetAuthUserId: string,
  input: CommercialCapabilityMutationInput,
): Record<string, unknown> {
  return {
    target_auth_user_id: targetAuthUserId,
    capability: input.capability,
    is_granted: input.granted,
    reason: input.reason,
  };
}

function opaqueCapabilityAccess(
  value: unknown,
): CommercialCapabilityAccess | null {
  if (!isRecord(value)) return null;
  const roleDefault = value.role_default;
  const effective = value.effective;
  const override = value.override;
  if (
    typeof roleDefault !== "boolean" ||
    typeof effective !== "boolean" ||
    (override !== null && typeof override !== "boolean")
  ) {
    return null;
  }
  return {
    role_default: roleDefault,
    effective,
    override,
  };
}

// Normalise a database response to the small capability envelope that Flutter
// understands. Any unexpected row, profile, role or commercial value is
// dropped rather than reflected by the privileged Edge response.
export function opaqueCommercialCapabilitiesResponse(
  value: unknown,
): OpaqueCommercialCapabilitiesResponse | null {
  if (!isRecord(value) || !isRecord(value.capabilities)) return null;
  const capabilities = {} as Record<
    V1CommercialCapability,
    CommercialCapabilityAccess
  >;
  for (const capability of V1_COMMERCIAL_CAPABILITIES) {
    const access = opaqueCapabilityAccess(value.capabilities[capability]);
    if (access === null) return null;
    capabilities[capability] = access;
  }
  return { capabilities };
}

// Keep database implementation details out of the public Edge error response
// while retaining the meaningful permission/conflict distinctions Flutter uses.
export function commercialCapabilityError(
  error: RpcError | null | undefined,
): { status: number; message: string } {
  const code = typeof error?.code === "string" ? error.code : "";
  const message = typeof error?.message === "string" ? error.message : "";
  if (message.includes("V1_ENGINEER_MANAGE_COMMERCIALS_NOT_ALLOWED")) {
    return {
      status: 409,
      message: "manage commercial access cannot be granted to an Engineer",
    };
  }
  if (message.includes("V1_COMMERCIAL_CAPABILITY_GRANT_TARGET_INACTIVE")) {
    return {
      status: 409,
      message: "commercial access cannot be granted to an inactive user",
    };
  }
  if (code === "42501" || message.includes("V1_ACTIVE_ADMIN_REQUIRED")) {
    return { status: 403, message: "forbidden — admin only" };
  }
  if (
    message.includes("V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD") ||
    message.includes("V1_IDEMPOTENCY_COMMAND_STILL_IN_FLIGHT")
  ) {
    return {
      status: 409,
      message: "a conflicting commercial capability command already exists",
    };
  }
  if (code === "22023" || message.includes("V1_COMMERCIAL_CAPABILITY_")) {
    return { status: 400, message: "invalid commercial capability request" };
  }
  return { status: 400, message: "commercial capability request failed" };
}
