import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
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

/// Debug-only role override used before a real login exists (e.g. widget tests
/// / first run). Ignored once a user is signed in — the user's role always wins.
final devRoleOverrideProvider = StateProvider<UserRole?>((ref) => null);

/// The role the app operates as — **derived from the signed-in user**. There is
/// no manual setter: log in as the right account to get the right side. When
/// Firebase Auth lands the role comes from the user's custom claim instead.
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
enum SignInResult { ok, invalidCredentials, deactivated, mustChangePassword }

/// Verifies credentials against the local user store and opens a session.
/// This is the `AuthService` seam — swap the body for Firebase Auth later; the
/// UI calls the same `signIn`/`signOut`.
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
    AppUser? user;
    for (final u in _ref.read(usersProvider)) {
      if (u.email.trim().toLowerCase() == target) {
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

  Future<void> signOut() => _ref.read(authSessionProvider.notifier).logout();
}
