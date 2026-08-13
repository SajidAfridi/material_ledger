import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/app_user.dart';
import '../shared/providers/session_provider.dart';
import '../shared/services/push_service.dart';

/// Registers this device for push whenever the signed-in user changes (login,
/// or switching accounts on the same device) — including the case where the
/// app opens already signed in (a restored session). A no-op with
/// [NoopPushService]; [FcmPushService] silently restores an already-granted
/// installation and registers it after authentication. Permission prompts are
/// reserved for the user's explicit Enable alerts action in the notification
/// center, which is required for reliable browser behavior. Watched once at
/// the app root.
final pushBridgeProvider = Provider<void>((ref) {
  // Start transport at app launch without opening a permission prompt.
  // Registration is retried below once a user exists, keeping the token
  // strictly owner-bound in Supabase.
  final push = ref.read(pushServiceProvider);
  unawaited(push.register());
  ref.listen<AppUser?>(currentUserProvider, (previous, next) {
    if (next == null) {
      if (previous != null && push is FcmPushService) {
        unawaited(push.unregisterToken());
      }
      return;
    }
    unawaited(push.register());
  }, fireImmediately: true);
});

/// Live, non-sensitive health of this installation's push transport.
final pushDeliveryStatusProvider = StreamProvider<PushDeliveryStatus>((ref) {
  final push = ref.watch(pushServiceProvider);
  return Stream<PushDeliveryStatus>.multi((controller) {
    final subscription = push.onStatus.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    // Subscribe first, then publish the current snapshot so an initialization
    // result cannot fall into a gap between the snapshot and live stream.
    controller.add(push.status);
    controller.onCancel = subscription.cancel;
  });
});
