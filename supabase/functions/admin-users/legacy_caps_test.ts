import { assertEquals } from "jsr:@std/assert@1";

import { legacyShellCaps } from "./legacy_caps.ts";

Deno.test("legacy capability overrides retain only explicitly allowed values", () => {
  assertEquals(
    legacyShellCaps(
      {
        legacyShell: true,
        caps: [
          "finance",
          "untrusted-admin-cap",
          "viewCommercials",
          "finance",
          3,
        ],
      },
      [],
    ),
    ["finance", "viewCommercials"],
  );
});

Deno.test("unmarked exact-role requests receive only server defaults", () => {
  assertEquals(
    legacyShellCaps(
      { caps: ["finance", "untrusted-admin-cap"] },
      ["goods"],
    ),
    ["goods"],
  );
});
