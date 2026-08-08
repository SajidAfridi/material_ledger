const USER_CONFIGURATION_ROLES = new Set([
  'admin',
  'senior_mechanical_engineer',
])

/// Exact server-controlled roles allowed to operate the protected user
/// configuration gateway. Active-user validation remains a separate required
/// check against the live Auth record.
export function canConfigureUsers(role: unknown): boolean {
  return typeof role === 'string' && USER_CONFIGURATION_ROLES.has(role)
}
