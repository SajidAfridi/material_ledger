import 'dart:async';

/// Coalesces invalidation signals, never domain commands or their payloads.
/// A signal received during a read schedules one trailing authorized read so
/// the change cannot be lost behind an in-flight response. No result is cached.
class AuthorizedRefreshQueue {
  AuthorizedRefreshQueue(this._refresh);

  final Future<void> Function() _refresh;
  Future<void>? _inFlight;
  bool _pending = false;
  bool _disposed = false;

  Future<void> request() {
    if (_disposed) return Future.value();
    _pending = true;
    final existing = _inFlight;
    if (existing != null) return existing;
    final done = Completer<void>();
    _inFlight = done.future;
    unawaited(_drain(done));
    return done.future;
  }

  Future<void> _drain(Completer<void> done) async {
    try {
      while (_pending && !_disposed) {
        _pending = false;
        await _refresh();
      }
      done.complete();
    } catch (error, stackTrace) {
      _pending = false;
      done.completeError(error, stackTrace);
    } finally {
      _inFlight = null;
    }
  }

  void dispose() {
    _disposed = true;
    _pending = false;
  }
}

/// Reports only a transition into availability, not repeated join verdicts.
/// Initial availability also requires a read to close the read-before-join gap.
class AuthorizedRefreshReadiness {
  bool _available = false;

  bool markAvailable() {
    final changed = !_available;
    _available = true;
    return changed;
  }

  void markUnavailable() => _available = false;
}
