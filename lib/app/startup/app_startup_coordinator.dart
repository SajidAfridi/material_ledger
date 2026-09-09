import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/language_provider.dart';
import '../../shared/providers/material_request_provider.dart';
import '../../shared/providers/session_provider.dart';
import '../../shared/providers/yorks_v1_notification_provider.dart';
import '../../shared/sync/realtime_sync.dart';
import '../../shared/sync/sync_engine.dart';
import '../document_expiry_monitor.dart';
import '../idle_request_monitor.dart';
import '../push_bridge.dart';

/// Starts application-wide services in explicit post-frame stages.
///
/// None of these services is an authority for a critical command. They provide
/// refresh signals, compatibility sync, notification delivery and maintenance.
/// Deferring them protects the auth/permission/current-route critical path
/// while retaining every service once the initial workspace has had time to
/// become interactive.
final appStartupCoordinatorProvider = Provider<void>((ref) {
  // Session restoration is the only root concern that starts immediately.
  ref.watch(authSessionLifecycleProvider);
  final sessionId = ref.watch(authSessionProvider);
  final timers = <Timer>[];
  var disposed = false;

  void later(Duration delay, void Function() mount) {
    timers.add(
      Timer(delay, () {
        if (!disposed) mount();
      }),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (disposed) return;

    if (sessionId == null) return;

    // Recipient notifications and push are useful, but they must not contend
    // with the first permission projection or current-route read model.
    later(
      const Duration(seconds: 2),
      () => ref.read(yorksV1NotificationsProvider),
    );
    later(
      const Duration(milliseconds: 2500),
      () => ref.read(pushBridgeProvider),
    );

    // Retained modules still depend on these compatibility systems, so they
    // are delayed rather than removed. Opening a feature that needs the sync
    // engine also constructs it immediately through its existing provider.
    later(const Duration(seconds: 4), () => ref.read(syncEngineProvider));
    later(const Duration(seconds: 5), () => ref.read(realtimeSyncProvider));
    later(
      const Duration(seconds: 7),
      () => ref.read(inventoryReconcilerProvider),
    );

    // These full-cache scans remain functional but run after the user can work.
    // Their long-term home is an authoritative server schedule.
    later(
      const Duration(seconds: 12),
      () => ref.read(idleRequestMonitorProvider),
    );
    later(
      const Duration(seconds: 12),
      () => ref.read(documentExpiryMonitorProvider),
    );
  });

  ref.onDispose(() {
    disposed = true;
    for (final timer in timers) {
      timer.cancel();
    }
  });
});
