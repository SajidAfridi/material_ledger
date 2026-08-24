export const ADMIN_USER_ACTION_CAPABILITY = {
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
} as const;

export type AdminUserAction = keyof typeof ADMIN_USER_ACTION_CAPABILITY;

/// Returns the one protected server capability required before an Edge action
/// may reach any service-role operation. Unknown or non-string actions fail
/// closed instead of falling through to a broader role gate.
export function requiredCapabilityForAdminUserAction(
  action: unknown,
): string | null {
  if (
    typeof action !== "string" ||
    !Object.prototype.hasOwnProperty.call(ADMIN_USER_ACTION_CAPABILITY, action)
  ) {
    return null;
  }
  return ADMIN_USER_ACTION_CAPABILITY[action as AdminUserAction];
}
