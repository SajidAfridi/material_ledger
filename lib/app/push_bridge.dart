import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/app_user.dart';
import '../shared/providers/session_provider.dart';
import '../shared/providers/yorks_v1_notification_provider.dart';
import '../shared/services/push_service.dart';
import 'app.dart' show appRouterProvider;

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
  final router = ref.watch(appRouterProvider);
  final acknowledgedRouteIds = <String>{};

  void acknowledgeCurrentRoute() {
    if (ref.read(currentUserProvider) == null) return;
    final id = router
        .routeInformationProvider
        .value
        .uri
        .queryParameters['notificationId']
        ?.trim();
    if (id == null ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(id) ||
        !acknowledgedRouteIds.add(id)) {
      return;
    }
    unawaited(() async {
      try {
        await ref.read(yorksV1NotificationsProvider.notifier).markSeen(id);
      } catch (_) {
        acknowledgedRouteIds.remove(id);
      }
    }());
  }

  router.routeInformationProvider.addListener(acknowledgeCurrentRoute);
  ref.onDispose(
    () =>
        router.routeInformationProvider.removeListener(acknowledgeCurrentRoute),
  );
  unawaited(push.register());
  ref.listen<AppUser?>(currentUserProvider, (previous, next) {
    if (next == null) {
      if (previous != null && push is FcmPushService) {
        unawaited(push.unregisterToken());
      }
      return;
    }
    unawaited(push.register());
    acknowledgeCurrentRoute();
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
