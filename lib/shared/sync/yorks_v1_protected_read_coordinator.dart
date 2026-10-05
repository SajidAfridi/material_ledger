import '../models/yorks_v1_domain_error.dart';

/// Coalesces an authority-scoped protected read without weakening its server
/// authorization boundary.
///
/// The owning Riverpod provider must recreate this coordinator whenever the
/// authenticated user, exact role, or confirmed permission revision changes.
/// That keeps the small last-success cache inside one authority scope only.
///
/// A refresh requested while a read is active becomes one trailing read. Any
/// further refresh requests join that trailing read instead of creating a
/// request fan-out. A transient transport failure may reuse the last success;
/// authentication and authorization failures are always surfaced.
class YorksV1ProtectedReadCoordinator<T> {
  YorksV1ProtectedReadCoordinator({
    this.freshCacheDuration = const Duration(seconds: 3),
    this.maxEntries = 32,
    DateTime Function()? now,
  }) : assert(maxEntries > 0),
       _now = now ?? DateTime.now;

  final Duration freshCacheDuration;
  final int maxEntries;
  final DateTime Function() _now;
  final Map<String, _ProtectedReadSlot<T>> _slots = {};

  Future<T> load({required String key, required Future<T> Function() read}) {
    final slot = _slots.putIfAbsent(key, _ProtectedReadSlot<T>.new);
    final active = slot.inFlight;
    if (active != null) {
      if (!slot.stale) return active;
      return slot.trailing ??= active.then(
        (_) => _start(key: key, slot: slot, read: read),
        onError: (_) => _start(key: key, slot: slot, read: read),
      );
    }

    final cachedAt = slot.cachedAt;
    if (!slot.stale &&
        slot.hasCachedValue &&
        cachedAt != null &&
        _now().difference(cachedAt) <= freshCacheDuration) {
      return Future<T>.value(slot.cachedValue as T);
    }
    return _start(key: key, slot: slot, read: read);
  }

  /// Requests fresh server state for [key]. If a read is already active, the
  /// next [load] joins one trailing read after it.
  void markStale(String key) {
    _slots.putIfAbsent(key, _ProtectedReadSlot<T>.new).stale = true;
  }

  Future<T> _start({
    required String key,
    required _ProtectedReadSlot<T> slot,
    required Future<T> Function() read,
  }) {
    slot.stale = false;
    slot.trailing = null;
    final token = Object();
    slot.inFlightToken = token;
    late final Future<T> operation;
    operation = _run(key: key, slot: slot, read: read).whenComplete(() {
      if (identical(slot.inFlightToken, token)) {
        slot.inFlight = null;
        slot.inFlightToken = null;
      }
      if (!slot.hasCachedValue &&
          slot.inFlight == null &&
          slot.trailing == null &&
          !slot.stale) {
        _slots.remove(key);
      }
    });
    slot.inFlight = operation;
    return operation;
  }

  Future<T> _run({
    required String key,
    required _ProtectedReadSlot<T> slot,
    required Future<T> Function() read,
  }) async {
    try {
      final value = await read();
      slot.cachedValue = value;
      slot.hasCachedValue = true;
      slot.cachedAt = _now();
      _trimCache(exceptKey: key);
      return value;
    } catch (error) {
      if (slot.hasCachedValue && _canReuseCachedValue(error)) {
        return slot.cachedValue as T;
      }
      rethrow;
    }
  }

  void _trimCache({required String exceptKey}) {
    while (_slots.length > maxEntries) {
      String? oldestKey;
      DateTime? oldestAt;
      for (final entry in _slots.entries) {
        if (entry.key == exceptKey || entry.value.inFlight != null) continue;
        final candidateAt =
            entry.value.cachedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (oldestAt == null || candidateAt.isBefore(oldestAt)) {
          oldestAt = candidateAt;
          oldestKey = entry.key;
        }
      }
      if (oldestKey == null) return;
      _slots.remove(oldestKey);
    }
  }

  static bool _canReuseCachedValue(Object error) {
    if (error is! YorksV1DomainException) return false;
    return error.code == YorksV1DomainErrorCode.backendUnavailable ||
        error.code == YorksV1DomainErrorCode.offline;
  }
}

class _ProtectedReadSlot<T> {
  Future<T>? inFlight;
  Object? inFlightToken;
  Future<T>? trailing;
  bool stale = false;
  bool hasCachedValue = false;
  T? cachedValue;
  DateTime? cachedAt;
}
