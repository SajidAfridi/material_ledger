import { assertEquals } from "jsr:@std/assert@1";

import { authMutationFailure } from "./auth_mutation_error.ts";

Deno.test("revoked action capability remains a non-misleading 403", () => {
  assertEquals(
    authMutationFailure({
      message: "V1_ADMIN_AUDIT_CONTEXT_ACTOR_CAPABILITY_REQUIRED",
    }),
    {
      error: "forbidden — user administration denied",
      status: 403,
    },
  );
});

Deno.test("inactive actor remains distinct from action capability denial", () => {
  assertEquals(
    authMutationFailure({
      message: "V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN",
    }),
    {
      error: "forbidden — inactive user configuration account",
      status: 403,
    },
  );
});

Deno.test("idempotency and last Admin conflicts retain stable status", () => {
  assertEquals(
    authMutationFailure({
      message: "V1_AUTH_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST",
    }),
    {
      error: "a conflicting authentication command already exists",
      status: 409,
    },
  );
  assertEquals(
    authMutationFailure(
      { message: "V1_LAST_ACTIVE_ADMIN_REQUIRED" },
      "Cannot deactivate the last active Admin.",
    ),
    {
      error: "Cannot deactivate the last active Admin.",
      status: 409,
    },
  );
});
