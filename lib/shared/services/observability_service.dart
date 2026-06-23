import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Crash reporting + lightweight analytics behind one interface. Today it's a
/// no-op (errors print in debug only); on production day swap the provider for a
/// Crashlytics or Sentry implementation — call sites (main.dart error hooks +
/// any `logEvent`) don't change.
abstract interface class ObservabilityService {
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  void logEvent(String name, {Map<String, Object?> params = const {}});
}

class NoopObservability implements ObservabilityService {
  const NoopObservability();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    if (kDebugMode) {
      debugPrint('[observability] ${fatal ? 'FATAL ' : ''}error: $error');
      if (stack != null) debugPrint(stack.toString());
    }
  }

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    if (kDebugMode) debugPrint('[observability] event: $name $params');
  }
}

/// Overridden in main() with the concrete instance wired into the error hooks.
final observabilityProvider = Provider<ObservabilityService>(
  (ref) => const NoopObservability(),
);
