import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'observability_service.dart';

/// Sentry-backed crash & error reporting — the production implementation of
/// [ObservabilityService]. Only instantiated when a DSN is supplied (see
/// `main.dart`); the SDK itself is initialised there.
///
/// PII is scrubbed aggressively because this app holds salaries, financials and
/// HR data: no user identity, IP, device name, and breadcrumb *values* are
/// dropped before anything leaves the device (see [scrubEvent]/[scrubBreadcrumb]
/// plus `sendDefaultPii = false`).
class SentryObservability implements ObservabilityService {
  const SentryObservability();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    if (kDebugMode) {
      debugPrint('[sentry] ${fatal ? 'FATAL ' : ''}error: $error');
    }
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        if (reason != null && reason.isNotEmpty) {
          scope.setTag('reason', reason);
        }
      },
    );
  }

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    // Sentry is a crash tool, not an analytics product — record events as
    // breadcrumbs so they add context to a later crash. Only the keys travel
    // (values are redacted) to keep salaries / financials / PII off the wire.
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: name,
        category: 'app',
        data: {for (final k in params.keys) k: '·'},
      ),
    );
  }

  // ─── PII scrubbing ───────────────────────────────────────────────────────

  /// Strip the data map from every breadcrumb — keep message/category/level so
  /// the trail stays useful without leaking values (route args, field data…).
  static Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb, Hint hint) {
    if (crumb == null) return null;
    return Breadcrumb(
      message: crumb.message,
      category: crumb.category,
      level: crumb.level,
      type: crumb.type,
      timestamp: crumb.timestamp,
      // data intentionally omitted.
    );
  }

  /// Final guard on the outgoing event: drop user identity and re-strip
  /// breadcrumb data in case any bypassed [scrubBreadcrumb]. (sentry 9.x: assign
  /// directly to the event rather than copyWith.)
  static FutureOr<SentryEvent?> scrubEvent(SentryEvent event, Hint hint) {
    event.user = null;
    event.breadcrumbs = event.breadcrumbs
        ?.map(
          (c) => Breadcrumb(
            message: c.message,
            category: c.category,
            level: c.level,
            type: c.type,
            timestamp: c.timestamp,
          ),
        )
        .toList();
    return event;
  }
}
