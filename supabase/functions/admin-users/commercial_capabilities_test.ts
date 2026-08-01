import {
  commercialCapabilityError,
  commercialCapabilityMutationInput,
  commercialCapabilityRpcPayload,
  opaqueCommercialCapabilitiesResponse,
} from "./commercial_capabilities.ts";
import { assertEquals, assertStrictEquals } from "jsr:@std/assert";

Deno.test("mutation payload uses only a server-resolved target UUID", () => {
  const input = commercialCapabilityMutationInput({
    capability: "view_commercials",
    granted: false,
    reason: "Pilot access withdrawn",
    idempotencyKey: "20000000-0000-4000-8000-000000000001",
    // These hostile/irrelevant request fields must never reach the RPC.
    targetAuthUserId: "99999999-9999-4999-8999-999999999999",
    role: "admin",
  });
  if (input === null) throw new Error("expected valid Edge mutation input");

  const payload = commercialCapabilityRpcPayload(
    "10000000-0000-4000-8000-000000000001",
    input,
  );
  assertEquals(payload, {
    target_auth_user_id: "10000000-0000-4000-8000-000000000001",
    capability: "view_commercials",
    is_granted: false,
    reason: "Pilot access withdrawn",
  });
  assertStrictEquals(
    payload.target_auth_user_id,
    "10000000-0000-4000-8000-000000000001",
  );
  assertStrictEquals("role" in payload, false);
  assertStrictEquals("targetAuthUserId" in payload, false);
});

Deno.test("mutation input rejects malformed capability and idempotency values", () => {
  assertStrictEquals(
    commercialCapabilityMutationInput({
      capability: "salary",
      granted: true,
      reason: "No",
      idempotencyKey: "20000000-0000-4000-8000-000000000001",
    }),
    null,
  );
  assertStrictEquals(
    commercialCapabilityMutationInput({
      capability: "view_commercials",
      granted: true,
      reason: " ",
      idempotencyKey: "not-a-uuid",
    }),
    null,
  );
});

Deno.test("success response contains only the opaque capability projection", () => {
  const response = opaqueCommercialCapabilitiesResponse({
    capabilities: {
      view_commercials: {
        role_default: true,
        effective: false,
        override: false,
        unit_cost_aed: 95,
      },
      manage_commercials: {
        role_default: true,
        effective: true,
        override: null,
        supplier_name: "must not leave Edge",
      },
    },
    target_auth_user_id: "10000000-0000-4000-8000-000000000001",
    role: "admin",
  });

  assertEquals(response, {
    capabilities: {
      view_commercials: {
        role_default: true,
        effective: false,
        override: false,
      },
      manage_commercials: {
        role_default: true,
        effective: true,
        override: null,
      },
    },
  });
});

Deno.test("malformed capability responses fail closed", () => {
  assertStrictEquals(
    opaqueCommercialCapabilitiesResponse({
      capabilities: {
        view_commercials: {
          role_default: true,
          effective: true,
          override: null,
        },
      },
    }),
    null,
  );
});

Deno.test("commercial command errors map to safe status and message", () => {
  assertEquals(
    commercialCapabilityError({
      code: "42501",
      message: "V1_ACTIVE_ADMIN_REQUIRED",
    }),
    { status: 403, message: "forbidden — admin only" },
  );
  assertEquals(
    commercialCapabilityError({
      code: "42501",
      message: "V1_ENGINEER_MANAGE_COMMERCIALS_NOT_ALLOWED",
    }),
    {
      status: 409,
      message: "manage commercial access cannot be granted to an Engineer",
    },
  );
  assertEquals(
    commercialCapabilityError({
      message: "V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD",
    }),
    {
      status: 409,
      message: "a conflicting commercial capability command already exists",
    },
  );
  assertEquals(
    commercialCapabilityError({
      code: "22023",
      message: "V1_COMMERCIAL_CAPABILITY_TARGET_INVALID",
    }),
    { status: 400, message: "invalid commercial capability request" },
  );
  assertEquals(
    commercialCapabilityError({
      message: "unexpected database detail containing a unit cost",
    }),
    { status: 400, message: "commercial capability request failed" },
  );
});
