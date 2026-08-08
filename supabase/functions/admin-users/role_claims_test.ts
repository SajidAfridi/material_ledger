import { assertEquals } from "jsr:@std/assert@1";

import {
  defaultCapsForRoles,
  provisionableRole,
  provisionableRoles,
} from "./role_claims.ts";

Deno.test("all six exact V1 roles are accepted as primary claims", () => {
  for (
    const role of [
      "admin",
      "procurement",
      "project_engineer",
      "site_engineer",
      "senior_mechanical_engineer",
      "project_manager",
    ]
  ) {
    assertEquals(provisionableRole(role), role);
  }
  assertEquals(provisionableRole("engineer"), null);
});

Deno.test("global engineer primary claims keep valid additional roles", () => {
  assertEquals(
    provisionableRoles(
      ["admin", "senior_mechanical_engineer", "project_engineer"],
      "senior_mechanical_engineer",
    ),
    ["senior_mechanical_engineer", "admin", "project_engineer"],
  );
  assertEquals(
    provisionableRoles(["project_manager", "invalid"], "project_manager"),
    null,
  );
});

Deno.test("role capability defaults are server-derived", () => {
  assertEquals(defaultCapsForRoles(["senior_mechanical_engineer"]), []);
  assertEquals(
    defaultCapsForRoles(["project_manager", "procurement"]),
    [
      "viewCommercials",
      "rentals",
      "writeRentals",
      "people",
      "writePeople",
      "goods",
      "approveLeave",
    ],
  );
});
