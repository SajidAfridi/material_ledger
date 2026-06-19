import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import 'language_provider.dart';

const _kRoleKey = 'current_role';
const _kActorNameKey = 'current_actor_name';

/// The role the app is currently operating as.
///
/// There is no real auth yet, so this doubles as the dev role-switcher seam.
/// When Firebase Auth lands, the role comes from the signed-in user's claims
/// and `setRole` is removed (the switcher is dev-only).
final currentRoleProvider = StateNotifierProvider<RoleNotifier, UserRole>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RoleNotifier(prefs);
});

class RoleNotifier extends StateNotifier<UserRole> {
  RoleNotifier(this._prefs)
    : super(UserRole.fromName(_prefs.getString(_kRoleKey) ?? UserRole.engineer.name));

  final SharedPreferences _prefs;

  Future<void> setRole(UserRole role) async {
    await _prefs.setString(_kRoleKey, role.name);
    state = role;
  }
}

/// Display name of the person acting (used to stamp the audit trail).
///
/// Mock for now; becomes the authenticated user's display name with Firebase.
final actorNameProvider = StateNotifierProvider<ActorNameNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ActorNameNotifier(prefs);
});

class ActorNameNotifier extends StateNotifier<String> {
  ActorNameNotifier(this._prefs)
    : super(_prefs.getString(_kActorNameKey) ?? 'Ahmed Khan');

  final SharedPreferences _prefs;

  Future<void> setName(String name) async {
    await _prefs.setString(_kActorNameKey, name);
    state = name;
  }
}
