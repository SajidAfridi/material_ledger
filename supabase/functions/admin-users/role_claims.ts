export const DEFAULT_CAPS: Readonly<Record<string, readonly string[]>> = {
  admin: [
    "viewCommercials",
    "salary",
    "finance",
    "rentals",
    "writeRentals",
    "people",
    "writePeople",
    "goods",
    "approveLeave",
  ],
  procurement: [
    "viewCommercials",
    "rentals",
    "writeRentals",
    "people",
    "writePeople",
    "goods",
    "approveLeave",
  ],
  project_engineer: [],
  site_engineer: [],
  senior_mechanical_engineer: [],
  project_manager: [],
  workshop_in_charge: [],
  document_controller: [],
};

const PROVISIONABLE_ROLES = new Set(Object.keys(DEFAULT_CAPS));

export function provisionableRole(value: unknown): string | null {
  if (typeof value !== "string" || !PROVISIONABLE_ROLES.has(value)) {
    return null;
  }
  return value;
}

export function provisionableRoles(
  value: unknown,
  primary: string,
): string[] | null {
  const requested = Array.isArray(value) ? value : [primary];
  const roles = requested
    .filter((role): role is string => typeof role === "string")
    .filter((role, index, all) => all.indexOf(role) === index);
  if (
    roles.length === 0 ||
    roles.some((role) => !PROVISIONABLE_ROLES.has(role))
  ) {
    return null;
  }
  return [primary, ...roles.filter((role) => role !== primary)];
}

export function defaultCapsForRoles(roles: readonly string[]): string[] {
  return [...new Set(roles.flatMap((role) => DEFAULT_CAPS[role] ?? []))];
}
