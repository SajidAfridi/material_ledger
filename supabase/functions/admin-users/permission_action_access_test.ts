import { assertEquals } from "jsr:@std/assert@1";

import {
  ADMIN_USER_ACTION_CAPABILITY,
  requiredCapabilityForAdminUserAction,
} from "./permission_action_access.ts";

Deno.test("every privileged user action has one explicit capability", () => {
  assertEquals(ADMIN_USER_ACTION_CAPABILITY, {
    list: "users.view",
    create: "users.create",
    createLegacy: "users.create",
    updateClaims: "users.roles.assign",
    updateLegacyClaims: "users.roles.assign",
    setPassword: "users.password.reset",
    setActive: "users.activation.manage",
    delete: "users.delete",
    getV1CommercialCapabilities: "permissions.view",
    setV1CommercialCapability: "permissions.manage",
  });
});

Deno.test("unknown and malformed actions fail closed", () => {
  assertEquals(requiredCapabilityForAdminUserAction("list"), "users.view");
  assertEquals(
    requiredCapabilityForAdminUserAction("updateClaims"),
    "users.roles.assign",
  );
  assertEquals(requiredCapabilityForAdminUserAction("unknown"), null);
  assertEquals(requiredCapabilityForAdminUserAction(""), null);
  assertEquals(requiredCapabilityForAdminUserAction(null), null);
  assertEquals(requiredCapabilityForAdminUserAction({ action: "list" }), null);
});
