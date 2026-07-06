import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/password_hasher.dart';
import '../sync/supabase_bootstrap.dart';
import 'language_provider.dart';
import 'users_provider.dart';

/// The signed-in user's full account record, or `null` when logged out.
/// Resolved from the auth session id against the users store. This is the single
/// source of identity, role, and per-user permissions for the rest of the app.
final currentUserProvider = Provider<AppUser?>((ref) {
  final uid = ref.watch(authSessionProvider);
  if (uid == null) return null;
  for (final u in ref.watch(usersProvider)) {
    if (u.id == uid) return u;
  }
  return null;
});

/// Debug-only role override used before a real login exists (e.g. widget tests
/// / first run). Ignored once a user is signed in — the user's role always wins.
final devRoleOverrideProvider = StateProvider<UserRole?>((ref) => null);

/// The role the app operates as — **derived from the signed-in user**. There is
/// no manual setter: log in as the right account to get the right side. With
/// Supabase Auth the same role is also carried in the JWT `app_metadata.role`
/// claim, which is what the server-side RLS enforces.
final currentRoleProvider = Provider<UserRole>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) return user.role;
  if (kDebugMode) {
    final override = ref.watch(devRoleOverrideProvider);
    if (override != null) return override;
  }
  return UserRole.engineer;
});

/// Display name stamped on the audit trail — the signed-in user.
final actorNameProvider = Provider<String>(
  (ref) => ref.watch(currentUserProvider)?.fullName ?? 'System',
);

/// Outcome of a sign-in attempt.
enum SignInResult {
  ok,
  invalidCredentials,
  deactivated,
  mustChangePassword,
  networkError,
}

/// Verifies credentials and opens a session. When Supabase is configured this
/// authenticates against **Supabase Auth** (the server issues the JWT that the
/// RLS policies enforce); otherwise it verifies against the local user store.
/// The UI calls the same `signIn` / `signOut` either way.
final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);

class AuthController {
  AuthController(this._ref);
  final Ref _ref;

  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    final target = email.trim().toLowerCase();
    final client = _ref.read(supabaseClientProvider);
    if (client != null) {
      return _signInSupabase(client, target, password);
    }
    return _signInLocal(target, password);
  }

  /// Production path: Supabase Auth is authoritative. There is deliberately no
  /// local-password fallback here — falling back would let a stale local hash
  /// authenticate someone the server would reject, defeating the point.
  Future<SignInResult> _signInSupabase(
    SupabaseClient client,
    String email,
    String password,
  ) async {
    final AuthResponse res;
    try {
      res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException {
      return SignInResult.invalidCredentials;
    } catch (_) {
      // Server unreachable — surface it rather than silently degrading.
      return SignInResult.networkError;
    }

    // The stable AppUser.id is carried in the JWT `app_metadata.app_user_id`
    // claim; the RLS owner-checks key off the same value.
    final authUser = res.user;
    final appUserId = authUser?.appMetadata['app_user_id'] as String?;
    if (authUser == null || appUserId == null) {
      // Auth user is missing its role/identity claim → misconfigured. Refuse
      // rather than sign in with no resolvable identity.
      await client.auth.signOut();
      return SignInResult.invalidCredentials;
    }

    // A user provisioned on another device won't be in this device's roster —
    // materialise them from the JWT claims so currentUser resolves. Existing
    // records (the seeds, with their overrides / employee link) are kept as-is.
    await _ref.read(usersProvider.notifier).upsertFromClaims(
          id: appUserId,
          email: authUser.email ?? '',
          fullName: (authUser.userMetadata?['full_name'] as String?) ?? '',
          role: UserRole.fromName(
            authUser.appMetadata['role'] as String? ?? 'engineer',
          ),
        );

    // A banned user is already rejected by GoTrue above; this is the roster-side
    // backstop for the same intent.
    final local = _localUserById(appUserId);
    if (local != null && !local.active) {
      await client.auth.signOut();
      return SignInResult.deactivated;
    }

    await _ref.read(authSessionProvider.notifier).setUser(appUserId);
    // Now that the session JWT is attached, pull this user's permitted rows.
    await SupabaseBootstrap(client, _ref.read(sharedPreferencesProvider)).run();

    return (local?.mustChangePassword ?? false)
        ? SignInResult.mustChangePassword
        : SignInResult.ok;
  }

  /// Local path — used only when Supabase is not configured (widget tests and
  /// pure-offline development). Unchanged legacy behaviour.
  Future<SignInResult> _signInLocal(String email, String password) async {
    AppUser? user;
    for (final u in _ref.read(usersProvider)) {
      if (u.email.trim().toLowerCase() == email) {
        user = u;
        break;
      }
    }
    if (user == null) return SignInResult.invalidCredentials;
    if (!PasswordHasher.verify(password, user.passwordHash, user.passwordSalt)) {
      return SignInResult.invalidCredentials;
    }
    if (!user.active) return SignInResult.deactivated;

    await _ref.read(authSessionProvider.notifier).setUser(user.id);
    return user.mustChangePassword
        ? SignInResult.mustChangePassword
        : SignInResult.ok;
  }

  AppUser? _localUserById(String id) {
    for (final u in _ref.read(usersProvider)) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> signOut() async {
    final client = _ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {
        // Best-effort — the local session is cleared regardless below.
      }
    }
    await _ref.read(authSessionProvider.notifier).logout();
  }
}
