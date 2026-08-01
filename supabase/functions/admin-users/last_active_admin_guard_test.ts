import { assertEquals } from "jsr:@std/assert@1";

import {
  type AuthUserForAdminGuard,
  isActiveAuthUser,
  isLastActiveExactAdmin,
} from "./last_active_admin_guard.ts";

const now = new Date("2026-08-01T12:00:00.000Z");

const exactAdmin = (
  id: string,
  bannedUntil?: string,
): AuthUserForAdminGuard => ({
  id,
  app_metadata: { role: "admin" },
  banned_until: bannedUntil,
});

Deno.test("blocks deactivating or demoting the last active exact Admin", () => {
  assertEquals(
    isLastActiveExactAdmin([exactAdmin("admin-1")], "admin-1", now),
    true,
  );
});

Deno.test("rejects a future-banned cached Admin and excludes it from the active set", () => {
  const users: AuthUserForAdminGuard[] = [
    exactAdmin("admin-1"),
    exactAdmin("admin-banned", "2026-08-02T12:00:00.000Z"),
    { id: "admin-lookalike", app_metadata: { role: "administrator" } },
    { id: "legacy-engineer", app_metadata: { role: "engineer" } },
  ];

  assertEquals(isLastActiveExactAdmin(users, "admin-1", now), true);
  assertEquals(isLastActiveExactAdmin(users, "admin-banned", now), false);
  assertEquals(isActiveAuthUser(users[1], now), false);
});

Deno.test("allows change when a second active exact Admin exists", () => {
  assertEquals(
    isLastActiveExactAdmin(
      [exactAdmin("admin-1"), exactAdmin("admin-2")],
      "admin-1",
      now,
    ),
    false,
  );
});
