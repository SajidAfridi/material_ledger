import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/yorks_v1_role.dart';
import '../services/password_hasher.dart';
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

/// The role the app operates as — **derived from the signed-in user**. There is
/// no manual setter: log in as the right account to get the right side. With
/// Supabase Auth the same role is also carried in the JWT `app_metadata.role`
/// claim, which is what the server-side RLS enforces.
final currentRoleProvider = Provider<UserRole>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role ?? UserRole.engineer;
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
  emailNotConfirmed,
  rateLimited,
  accountSetupRequired,
  mustChangePassword,
  networkError,
}

/// Maps only the safe, actionable portion of an Auth failure to user-facing
/// state. The raw server message is deliberately never shown: it may disclose
/// configuration details and makes account enumeration easier.
SignInResult signInResultForAuthException(AuthException exception) {
  final code = exception.code?.trim().toLowerCase() ?? '';
  final message = exception.message.trim().toLowerCase();
  if (exception.statusCode == '429' || code.contains('rate_limit')) {
    return SignInResult.rateLimited;
  }
  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return SignInResult.emailNotConfirmed;
  }
  if (exception.statusCode == '400' ||
      exception.statusCode == '401' ||
      code == 'invalid_credentials') {
    return SignInResult.invalidCredentials;
  }
  return SignInResult.networkError;
}

/// Increments for every authoritative Auth lifecycle change, including token
/// refreshes that retain the same app-user ID. Exact Yorks V1 role providers
/// watch this revision rather than assuming a stable local ID means a stable
/// JWT claim.
final authSessionRevisionProvider =
    StateNotifierProvider<AuthSessionRevisionNotifier, int>(
      (ref) => AuthSessionRevisionNotifier(),
    );

class AuthSessionRevisionNotifier extends StateNotifier<int> {
  AuthSessionRevisionNotifier() : super(0);

  void bump() => state++;
}

/// Resolves the compatibility-shell role from the only trusted source: an
/// exact server-controlled `app_metadata.role` claim.
///
/// Yorks V1 claims deliberately map *down* to the existing shell's three
/// legacy buckets so a connected V1 identity can still sign in while retained
/// modules are being migrated. This function is never V1 authorization:
/// Yorks V1 commands and routes use [YorksV1Role.fromServerClaim] directly.
/// In particular, a legacy `engineer` value does not become a Project Engineer
/// or Site Engineer through this compatibility mapping.
UserRole? userRoleFromAppMetadata(Map<String, dynamic> appMetadata) {
  final raw = appMetadata['role'];
  if (raw is! String) return null;
  for (final role in UserRole.values) {
    if (role.name == raw) return role;
  }
  return switch (YorksV1Role.fromServerClaim(raw)) {
    YorksV1Role.projectEngineer ||
    YorksV1Role.siteEngineer ||
    YorksV1Role.seniorMechanicalEngineer ||
    YorksV1Role.projectManager => UserRole.engineer,
    YorksV1Role.procurement => UserRole.procurement,
    YorksV1Role.admin => UserRole.admin,
    null => null,
  };
}

/// Verifies credentials and opens a session. When Supabase is configured this
/// authenticates against **Supabase Auth** (the server issues the JWT that the
/// RLS policies enforce); otherwise it verifies against the local user store.
/// The UI calls the same `signIn` / `signOut` either way.
final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);

/// Keeps the compatibility-shell session in step with the real Supabase
/// session. It is mounted once by [MaterialLedgerApp]; commands remain
/// server-authorized, while this prevents a revoked/expired browser session
/// from continuing to look signed in locally.
final authSessionLifecycleProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return;

  final controller = ref.read(authControllerProvider);
  unawaited(controller.restoreSupabaseSession());
  final subscription = client.auth.onAuthStateChange.listen(
    (state) => unawaited(controller.handleSupabaseAuthState(state)),
    onError: (Object error, StackTrace stackTrace) =>
        unawaited(controller.clearLocalSession()),
  );
  ref.onDispose(() => unawaited(subscription.cancel()));
});

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
    } on AuthException catch (error) {
      return signInResultForAuthException(error);
    } catch (_) {
      // Server unreachable — surface it rather than silently degrading.
      return SignInResult.networkError;
    }

    final authUser = res.user;
    if (authUser == null) {
      await _signOutSupabaseAndClear(client);
      return SignInResult.invalidCredentials;
    }

    final result = await _materializeSupabaseUser(client, authUser);
    if (result != SignInResult.ok &&
        result != SignInResult.mustChangePassword) {
      await _signOutSupabaseAndClear(client);
    }
    return result;
  }

  /// Revalidates an existing browser/mobile session against both GoTrue and the
  /// current user-owned V1 profile. Reading [auth.currentUser] alone is not a
  /// live session check, and a cached AppUser record is never authorization.
  Future<void> restoreSupabaseSession() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return;
    if (client.auth.currentSession == null) {
      await clearLocalSession();
      return;
    }

    try {
      final authUser = (await client.auth.getUser()).user;
      if (authUser == null) {
        await _signOutSupabaseAndClear(client);
        return;
      }
      final result = await _materializeSupabaseUser(client, authUser);
      if (result != SignInResult.ok &&
          result != SignInResult.mustChangePassword) {
        await _signOutSupabaseAndClear(client);
      }
    } catch (_) {
      // A restored session that cannot be verified must not unlock local
      // routes. Do not reinterpret a network failure as bad credentials.
      await clearLocalSession();
    }
  }

  /// Handles remote sign-out, cross-tab sign-out and token/user updates. A
  /// token refresh can change app_metadata, so every non-null session is
  /// revalidated before the UI continues to treat it as authenticated.
  Future<void> handleSupabaseAuthState(AuthState state) async {
    if (state.event == AuthChangeEvent.signedOut || state.session == null) {
      await clearLocalSession();
      return;
    }
    await restoreSupabaseSession();
  }

  Future<SignInResult> _materializeSupabaseUser(
    SupabaseClient client,
    User authUser,
  ) async {
    // The stable AppUser.id is carried in server-owned app metadata. Fall back
    // to the Auth UUID only when that optional compatibility ID is absent.
    final metadataAppUserId = authUser.appMetadata['app_user_id'];
    final appUserId =
        metadataAppUserId is String && metadataAppUserId.trim().isNotEmpty
        ? metadataAppUserId.trim()
        : authUser.id;

    // The "must change password" intent travels in the identity claim
    // (user_metadata), so a forced change set by an admin on one device is
    // honoured wherever the user actually signs in — not just on the device that
    // provisioned them.
    final mustChange = authUser.userMetadata?['must_change_password'] is bool
        ? authUser.userMetadata!['must_change_password'] as bool
        : false;

    // A user provisioned on another device won't be in this device's roster —
    // materialise them from the trusted JWT app_metadata so currentUser
    // resolves. Never infer authorization from email or user_metadata.
    final resolvedRole = userRoleFromAppMetadata(authUser.appMetadata);
    final yorksV1Role = YorksV1Role.fromServerClaim(
      authUser.appMetadata['role'],
    );
    final rawYorksV1Roles = authUser.appMetadata['roles'];
    final yorksV1Roles =
        (rawYorksV1Roles is List ? rawYorksV1Roles : const <Object>[])
            .map(YorksV1Role.fromServerClaim)
            .whereType<YorksV1Role>()
            .toList(growable: false);
    if (resolvedRole == null || yorksV1Role == null) {
      return SignInResult.accountSetupRequired;
    }

    final expectedProfileRole = switch (yorksV1Role) {
      YorksV1Role.projectEngineer => 'project_engineer',
      YorksV1Role.siteEngineer => 'site_engineer',
      YorksV1Role.seniorMechanicalEngineer ||
      YorksV1Role.projectManager => 'project_engineer',
      YorksV1Role.procurement => 'procurement',
      YorksV1Role.admin => 'admin',
    };

    // RLS permits an authenticated user to read only this small noncommercial
    // profile signal. It is the app-side deactivation/configuration backstop;
    // critical RPCs independently enforce the same live predicate.
    final profile = await client
        .from('v1_profiles')
        .select('is_active, canonical_role_snapshot')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();
    if (profile == null) return SignInResult.accountSetupRequired;
    if (profile['is_active'] != true) return SignInResult.deactivated;
    if (profile['canonical_role_snapshot'] != expectedProfileRole) {
      return SignInResult.accountSetupRequired;
    }

    await _ref
        .read(usersProvider.notifier)
        .upsertFromClaims(
          id: appUserId,
          email: authUser.email ?? '',
          fullName: authUser.userMetadata?['full_name'] is String
              ? authUser.userMetadata!['full_name'] as String
              : '',
          role: resolvedRole,
          yorksV1Role: yorksV1Role,
          yorksV1Roles: yorksV1Roles.isEmpty ? [yorksV1Role] : yorksV1Roles,
          mustChangePassword: mustChange,
        );

    if (resolvedRole == UserRole.admin) {
      // User Management must show the live Auth directory, including accounts
      // provisioned from another device. A failed directory refresh never
      // blocks sign-in because the signed-in account is already materialised.
      try {
        await _ref.read(usersProvider.notifier).refreshFromServer();
      } catch (_) {
        // Keep the cached roster and let the screen surface its last-known
        // state; retrying is available from the Admin screen.
      }
    }

    await _ref.read(authSessionProvider.notifier).setUser(appUserId);
    _ref.read(authSessionRevisionProvider.notifier).bump();

    return mustChange ? SignInResult.mustChangePassword : SignInResult.ok;
  }

  /// Local path — used only when Supabase is not configured and local
  /// development was explicitly enabled at startup.
  Future<SignInResult> _signInLocal(String email, String password) async {
    if (_ref.read(localDemoPasswordProvider).isEmpty) {
      return SignInResult.invalidCredentials;
    }
    AppUser? user;
    for (final u in _ref.read(usersProvider)) {
      if (u.email.trim().toLowerCase() == email) {
        user = u;
        break;
      }
    }
    if (user == null) return SignInResult.invalidCredentials;
    if (!PasswordHasher.verify(
      password,
      user.passwordHash,
      user.passwordSalt,
    )) {
      return SignInResult.invalidCredentials;
    }
    if (!user.active) return SignInResult.deactivated;

    await _ref.read(authSessionProvider.notifier).setUser(user.id);
    _ref.read(authSessionRevisionProvider.notifier).bump();
    return user.mustChangePassword
        ? SignInResult.mustChangePassword
        : SignInResult.ok;
  }

  /// Self-service: the SIGNED-IN user changes THEIR OWN password. This uses the
  /// GoTrue self-update API against the caller's own session — no service-role,
  /// no admin rights — which is exactly why it works for a first-login engineer
  /// or procurement user who must change an admin-set temporary password.
  ///
  /// (Contrast [UsersNotifier.setPassword], which is an ADMIN resetting SOMEONE
  /// ELSE's password via the privileged `admin-users` function — that path is
  /// admin-only by design and would 403 a non-admin trying to change their own.)
  ///
  /// Throws on a remote failure so the caller can surface it and keep the user on
  /// the change-password screen rather than silently proceeding.
  Future<void> changeOwnPassword(String newPassword) async {
    final client = _ref.read(supabaseClientProvider);
    if (client != null) {
      // Updates the current session's user; the session stays valid afterwards.
      // Clearing must_change_password in the SAME self-update means a non-admin
      // resolves their own forced-change flag with no admin round-trip.
      await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
          data: {'must_change_password': false},
        ),
      );
    }
    // Mirror the workflow flag into the local roster. Connected mode clears
    // local password material; explicit local development stores its test hash.
    // Only reached if the remote call above succeeded.
    final user = _ref.read(currentUserProvider);
    if (user != null) {
      await _ref
          .read(usersProvider.notifier)
          .applyLocalPassword(user.id, newPassword, mustChange: false);
    }
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
    await clearLocalSession();
  }

  /// Clears only the local presentation session. This is used when Supabase
  /// reports a remote logout or a restored session cannot be verified; it never
  /// tries to make a second network sign-out call from inside an Auth callback.
  Future<void> clearLocalSession() async {
    await _ref.read(authSessionProvider.notifier).logout();
    _ref.read(authSessionRevisionProvider.notifier).bump();
  }

  Future<void> _signOutSupabaseAndClear(SupabaseClient client) async {
    try {
      await client.auth.signOut();
    } catch (_) {
      // Local state is still cleared below. A later Auth event may retry the
      // remote transition once connectivity returns.
    }
    await clearLocalSession();
  }
}
