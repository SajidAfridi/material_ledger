// Retained-shell JWT capability policy. This is intentionally separate from
// Yorks V1 database authorization, which is evaluated from protected server
// relations rather than an Auth metadata capability list.

export const LEGACY_CAPABILITY_ALLOWLIST = [
  "viewCommercials",
  // Keep the historical spelling during the commercial-capability migration.
  "cost",
  "salary",
  "finance",
  "rentals",
  "writeRentals",
  "people",
  "writePeople",
  "goods",
  "approveLeave",
] as const;

const allowedLegacyCapabilities = new Set<string>(LEGACY_CAPABILITY_ALLOWLIST);

// Uses client capability input only from the explicitly marked retained legacy
// shell, and only after filtering it through the finite policy above. Unmarked
// exact Yorks V1 commands receive their server-owned fallback.
export function legacyShellCaps(
  body: Record<string, unknown>,
  fallback: readonly string[],
): string[] {
  if (body.legacyShell !== true || !Array.isArray(body.caps)) {
    return [...fallback];
  }

  return [
    ...new Set(
      body.caps.filter(
        (capability): capability is string =>
          typeof capability === "string" &&
          allowedLegacyCapabilities.has(capability),
      ),
    ),
  ].sort();
}
