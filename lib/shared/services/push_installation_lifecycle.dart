import 'dart:async';

/// Serializes subscription retirement with enrollment. The durable marker is
/// deliberately only a boolean: no token, account or payload enters storage.
class PushInstallationLifecycle {
  PushInstallationLifecycle({
    required this.cleanupPending,
    required this.setCleanupPending,
    required this.deleteToken,
  });

  final bool Function() cleanupPending;
  final Future<void> Function(bool) setCleanupPending;
  final Future<void> Function() deleteToken;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _cleanup;
  Future<String?>? _registration;
  int? _registrationGeneration;

  int get generation => _generation;
  bool isCurrent(int generation) => !_disposed && generation == _generation;

  Future<String?> register(Future<String?> Function(int) action) {
    final generation = _generation;
    if (_registrationGeneration == generation && _registration != null) {
      return _registration!;
    }
    final attempt = () async {
      await _cleanup;
      if (!isCurrent(generation)) return null;
      if (cleanupPending()) await _deletePending();
      if (!isCurrent(generation)) return null;
      return action(generation);
    }();
    _registrationGeneration = generation;
    _registration = attempt;
    return attempt.whenComplete(() {
      if (identical(_registration, attempt)) {
        _registration = null;
        _registrationGeneration = null;
      }
    });
  }

  /// Invalidate in-flight enrollment immediately, before any asynchronous work.
  /// Enrollment after logout waits until the old browser subscription is gone.
  Future<void> retire(Future<void> Function() unregister) {
    _generation++;
    final previous = _cleanup;
    final pending = () async {
      try {
        await previous;
      } catch (_) {
        // A failed cleanup remains persisted; this attempt retries it.
      }
      await setCleanupPending(true);
      try {
        await unregister();
      } finally {
        await _deletePending();
      }
    }();
    _cleanup = pending;
    return pending.whenComplete(() {
      if (identical(_cleanup, pending)) _cleanup = null;
    });
  }

  Future<void> _deletePending() async {
    await deleteToken();
    await setCleanupPending(false);
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}
