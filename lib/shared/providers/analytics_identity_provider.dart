import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import 'language_provider.dart';
import 'yorks_v1_identity_provider.dart';

/// Keeps the PostHog identity aligned with the authoritative Supabase Auth
/// UUID and exact server-controlled V1 role claim. No email, display name,
/// project membership or editable user metadata is used.
final analyticsIdentityLifecycleProvider = Provider<void>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  // Deliberately do not use yorksV1AuthUserIdProvider's local-demo fallback:
  // external analytics identity is Supabase Auth UUID only.
  final userId = ref.watch(supabaseClientProvider)?.auth.currentUser?.id;
  final role = ref.watch(yorksV1CurrentRoleProvider);
  if (userId == null || role == null) {
    analytics.reset();
    return;
  }
  analytics.identify(userId: userId, role: role.claimValue);
});
