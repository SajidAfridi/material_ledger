import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/app_user.dart';
import '../shared/providers/session_provider.dart';
import '../shared/services/push_service.dart';

/// Registers this device for push whenever the signed-in user changes (login,
/// or switching accounts on the same device) — including the case where the
/// app opens already signed in (a restored session). A no-op with
/// [NoopPushService] (no Firebase configured yet); [FcmPushService] does the
/// full setup (permission, background handler, token registration) the first
/// time this fires. Watched once at the app root.
final pushBridgeProvider = Provider<void>((ref) {
  ref.listen<AppUser?>(
    currentUserProvider,
    (_, next) {
      if (next == null) return;
      ref.read(pushServiceProvider).register();
    },
    fireImmediately: true,
  );
});
