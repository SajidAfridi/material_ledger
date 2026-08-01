// A minimal Auth-user shape used by the Edge guard. It intentionally reads
// only server-owned Auth fields and does not depend on the Flutter roster.
export type AuthUserForAdminGuard = {
  id: string;
  app_metadata?: Record<string, unknown> | null;
  banned_until?: string | null;
};

// Yorks V1 recognizes only this exact server role as an administrator.
export function isExactAdmin(user: AuthUserForAdminGuard): boolean {
  return user.app_metadata?.role === "admin";
}

// An Auth user is active unless it has a future ban. Treat an unexpected
// `banned_until` value as active so an unparsable server response cannot allow
// removal of the last administrator.
export function isActiveAuthUser(
  user: AuthUserForAdminGuard,
  now = new Date(),
): boolean {
  const bannedUntil = user.banned_until;
  if (typeof bannedUntil !== "string" || bannedUntil.trim().length === 0) {
    return true;
  }

  const bannedUntilMillis = Date.parse(bannedUntil);
  return Number.isNaN(bannedUntilMillis) || bannedUntilMillis <= now.getTime();
}

// True exactly when [targetAuthUserId] is the one live exact-role Admin in the
// current Auth directory. This protects role demotion and deactivation from
// direct Edge calls that bypass the local Flutter roster safeguard.
export function isLastActiveExactAdmin(
  users: readonly AuthUserForAdminGuard[],
  targetAuthUserId: string,
  now = new Date(),
): boolean {
  const activeAdminIds = users
    .filter((user) => isExactAdmin(user) && isActiveAuthUser(user, now))
    .map((user) => user.id);
  return activeAdminIds.length === 1 && activeAdminIds[0] === targetAuthUserId;
}
