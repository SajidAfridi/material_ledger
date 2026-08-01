import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_commercial_capability.dart';
import '../models/yorks_v1_domain_error.dart';
import '../repositories/yorks_v1_current_commercial_capability_repository.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';

/// Overrideable current-session read seam. Unlike the Admin management
/// repository, this one takes no target identity and is usable by every active
/// exact V1 role to learn only its own non-commercial authorization result.
final yorksV1CurrentCommercialCapabilityRepositoryProvider =
    Provider<YorksV1CurrentCommercialCapabilityRepository?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1CurrentCommercialCapabilityRepository(client);
    });

/// Live protected-capability state for the signed-in V1 identity.
///
/// Initial/loading/error states intentionally mean *no commercial access* to
/// downstream providers. A realtime change to the caller's profile or
/// capability override immediately changes to loading (which purges protected
/// Riverpod state) before an authoritative server refresh can re-enable it.
final yorksV1CurrentCommercialCapabilitiesProvider =
    StateNotifierProvider.autoDispose<
      YorksV1CurrentCommercialCapabilitiesNotifier,
      AsyncValue<YorksV1CommercialCapabilities?>
    >((ref) {
      final flags = ref.watch(yorksV1FeatureFlagsProvider);
      final authUserId = ref.watch(yorksV1AuthUserIdProvider);
      final role = ref.watch(yorksV1CurrentRoleProvider);
      final client = ref.watch(supabaseClientProvider);
      final repository = ref.watch(
        yorksV1CurrentCommercialCapabilityRepositoryProvider,
      );
      final notifier = YorksV1CurrentCommercialCapabilitiesNotifier(
        enabled:
            flags.foundation &&
            authUserId != null &&
            authUserId.trim().isNotEmpty &&
            role != null &&
            client != null &&
            repository != null,
        authUserId: authUserId,
        client: client,
        repository: repository,
      );
      unawaited(notifier.start());
      return notifier;
    });

/// Testable bridge for the two non-commercial, self-only authorization
/// signals. Production subscribes to Supabase Realtime; a test can provide a
/// deterministic bridge without exposing a way to alter the protected result.
typedef YorksV1AuthorizationSignalSubscription =
    Future<bool> Function({
      required Future<void> Function() onSignal,
      required void Function(Object? error) onUnavailable,
    });

class YorksV1CurrentCommercialCapabilitiesNotifier
    extends StateNotifier<AsyncValue<YorksV1CommercialCapabilities?>> {
  YorksV1CurrentCommercialCapabilitiesNotifier({
    required bool enabled,
    required String? authUserId,
    required SupabaseClient? client,
    required YorksV1CurrentCommercialCapabilityRepository? repository,
    YorksV1AuthorizationSignalSubscription? authorizationSignalSubscription,
  }) : _enabled = enabled,
       _authUserId = authUserId,
       _client = client,
       _repository = repository,
       _authorizationSignalSubscription = authorizationSignalSubscription,
       super(const AsyncData(null));

  final bool _enabled;
  final String? _authUserId;
  final SupabaseClient? _client;
  final YorksV1CurrentCommercialCapabilityRepository? _repository;
  final YorksV1AuthorizationSignalSubscription?
  _authorizationSignalSubscription;
  final List<RealtimeChannel> _channels = [];
  final _disposedSignal = Completer<void>();
  Completer<bool>? _initialAuthorizationJoin;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _disposed = false;

  Future<void> start() async {
    if (!_enabled) return;
    // Subscribe before accepting an authoritative positive value. When both
    // live signals have joined, their callback makes a second server read;
    // that closes the window where an Admin could revoke access between the
    // original RPC snapshot and realtime registration.
    final signalsReady = await Future.any<bool>([
      _subscribeToAuthorizationChanges(),
      _disposedSignal.future.then((_) => false),
    ]);
    if (_disposed || !signalsReady) return;
    await _refresh();
  }

  /// Explicit refresh seam for post-login and deterministic provider tests.
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    if (!_enabled || _disposed) return;
    // A channel can become live while the initial RPC is in flight. Do not
    // discard that post-join recheck: drain it immediately after this request
    // completes, before retaining its positive result for the session.
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    final repository = _repository;
    if (repository == null) return;
    _refreshing = true;
    try {
      do {
        _refreshQueued = false;
        // Deny and notify dependants *before* the request. This actively
        // purges commercial projections held by providers that use this
        // capability as their authorization signal.
        state = const AsyncLoading();
        try {
          final capabilities = await repository.loadCurrent();
          // A live authorization signal may have arrived during this RPC. Its
          // response must not be exposed even transiently; the queued pass
          // below is the first result eligible to become commercial state.
          if (!_disposed && !_refreshQueued) state = AsyncData(capabilities);
        } on YorksV1DomainException catch (error, stackTrace) {
          if (!_disposed && !_refreshQueued) {
            state = AsyncError(error, stackTrace);
          }
        } catch (error, stackTrace) {
          if (!_disposed && !_refreshQueued) {
            state = AsyncError(
              YorksV1DomainException(
                YorksV1DomainErrorCode.backendUnavailable,
                cause: error,
              ),
              stackTrace,
            );
          }
        }
      } while (_refreshQueued && _enabled && !_disposed);
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> _subscribeToAuthorizationChanges() async {
    final testSubscription = _authorizationSignalSubscription;
    if (testSubscription != null) {
      return testSubscription(
        onSignal: _refresh,
        onUnavailable: _invalidateForAuthorizationSignalFailure,
      );
    }

    final client = _client;
    final authUserId = _authUserId?.trim();
    if (client == null || authUserId == null || authUserId.isEmpty) {
      return false;
    }

    // A role/dormancy change is mirrored in v1_profiles, while an explicit
    // commercial grant/revoke is represented in v1_user_capabilities. Both
    // relations are self-RLS-visible and published only as refresh signals.
    // A join is not enough on its own: after both registrations are live, we
    // fetch the protected value again before retaining commercial data.
    const tables = ['v1_user_capabilities', 'v1_profiles'];
    var readyTableCount = 0;
    final initialJoin = Completer<bool>();
    _initialAuthorizationJoin = initialJoin;
    for (final table in tables) {
      var isReady = false;
      final channel = client
          .channel('v1-commercial-access:$table:$authUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'auth_user_id',
              value: authUserId,
            ),
            callback: (_) {
              // The first read is deliberately held until both self-only
              // subscriptions are live. Before that point, the eventual
              // post-join RPC includes this change; afterwards it can refresh
              // directly.
              if (readyTableCount == tables.length) {
                unawaited(_refresh());
              }
            },
          )
          .subscribe((status, error) {
            if (_disposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              if (!isReady) {
                isReady = true;
                readyTableCount += 1;
              }
              if (readyTableCount == tables.length) {
                if (!initialJoin.isCompleted) {
                  // `start` performs the first protected RPC only after this
                  // exact two-channel acknowledgement.
                  initialJoin.complete(true);
                } else {
                  // A later reconnect restores access only after a fresh
                  // protected server read.
                  unawaited(_refresh());
                }
              }
              return;
            }

            if (isReady) {
              isReady = false;
              readyTableCount -= 1;
            }
            _invalidateForAuthorizationSignalFailure(error);
            if (!initialJoin.isCompleted) initialJoin.complete(false);
          });
      _channels.add(channel);
    }
    return initialJoin.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        if (!initialJoin.isCompleted) initialJoin.complete(false);
        _invalidateForAuthorizationSignalFailure(
          TimeoutException('V1 authorization signals did not become ready'),
        );
        return false;
      },
    );
  }

  /// A dropped or denied realtime subscription means the client can no longer
  /// prove that its held commercial projection is current. Fail closed until a
  /// later successful join triggers the fresh protected RPC.
  void _invalidateForAuthorizationSignalFailure(Object? error) {
    if (!_enabled || _disposed) return;
    state = AsyncError(
      YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      ),
      StackTrace.current,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshQueued = false;
    if (!_disposedSignal.isCompleted) _disposedSignal.complete();
    final pendingJoin = _initialAuthorizationJoin;
    if (pendingJoin != null && !pendingJoin.isCompleted) {
      pendingJoin.complete(false);
    }
    final client = _client;
    if (client != null) {
      for (final channel in _channels) {
        unawaited(client.removeChannel(channel));
      }
    }
    _channels.clear();
    super.dispose();
  }
}
