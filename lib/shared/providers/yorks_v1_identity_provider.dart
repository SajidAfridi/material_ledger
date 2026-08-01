import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_role.dart';
import 'language_provider.dart' show authSessionProvider, supabaseClientProvider;

/// The immutable Supabase Auth identity for V1 local-draft isolation. It is not
/// a profile ID and is never synthesized from the legacy local user roster.
final yorksV1AuthUserIdProvider = Provider<String?>((ref) {
  // The Supabase client instance is stable across sign-in/out. Watching the
  // session notifier makes this projection refresh when that client's current
  // Auth user changes, without treating the legacy app-user ID as authority.
  ref.watch(authSessionProvider);
  return ref.watch(supabaseClientProvider)?.auth.currentUser?.id;
});

/// V1 client eligibility reads only the exact, server-controlled JWT
/// `app_metadata.role` claim. Missing, altered or legacy claims resolve to no
/// privileged V1 role and remain fail-closed.
final yorksV1CurrentRoleProvider = Provider<YorksV1Role?>((ref) {
  // This is an invalidation trigger only. The exact V1 role still comes solely
  // from the current Supabase Auth user's server-controlled app metadata.
  ref.watch(authSessionProvider);
  final appMetadata = ref
      .watch(supabaseClientProvider)
      ?.auth
      .currentUser
      ?.appMetadata;
  return YorksV1Role.fromServerClaim(appMetadata?['role']);
});
