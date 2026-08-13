import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/yorks_v1_notification.dart';
import '../repositories/yorks_v1_notification_repository.dart';
import 'language_provider.dart';

final yorksV1NotificationRepositoryProvider =
    Provider<YorksV1NotificationRepository?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return null;
      return YorksV1SupabaseNotificationRepository(client);
    });

final yorksV1NotificationsProvider =
    StateNotifierProvider<
      YorksV1NotificationsNotifier,
      AsyncValue<List<YorksV1NotificationRecord>>
    >((ref) {
      final client = ref.watch(supabaseClientProvider);
      final repository = ref.watch(yorksV1NotificationRepositoryProvider);
      final appSessionId = ref.watch(authSessionProvider);
      final authUserId = client?.auth.currentUser?.id;
      final notifier = YorksV1NotificationsNotifier(
        client: client,
        repository: repository,
        authUserId: appSessionId == null ? null : authUserId,
      );
      unawaited(notifier.start());
      return notifier;
    });

final yorksV1AppNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final language = ref.watch(languageProvider);
  return ref
          .watch(yorksV1NotificationsProvider)
          .valueOrNull
          ?.map((record) => record.toAppNotification(language))
          .toList(growable: false) ??
      const [];
});

class YorksV1NotificationsNotifier
    extends StateNotifier<AsyncValue<List<YorksV1NotificationRecord>>> {
  YorksV1NotificationsNotifier({
    required SupabaseClient? client,
    required YorksV1NotificationRepository? repository,
    required String? authUserId,
  }) : _client = client,
       _repository = repository,
       _authUserId = authUserId?.trim(),
       super(const AsyncLoading());

  final SupabaseClient? _client;
  final YorksV1NotificationRepository? _repository;
  final String? _authUserId;

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _fallbackTimer;
  bool _started = false;
  bool _disposed = false;
  bool _loading = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    if (_repository == null ||
        _client == null ||
        _authUserId?.isEmpty != false) {
      state = const AsyncData([]);
      return;
    }
    await refresh(showLoading: true);
    if (_disposed) return;
    final subscribed = await _subscribe();
    if (!subscribed) _startFallback();
  }

  Future<void> refresh({bool showLoading = false}) async {
    final repository = _repository;
    if (repository == null || _loading || _disposed) return;
    _loading = true;
    final previous = state.valueOrNull;
    if (showLoading && previous == null) state = const AsyncLoading();
    try {
      state = AsyncData(await repository.listMine());
    } catch (error, stackTrace) {
      // Preserve the last authorized list during a temporary network failure;
      // the retry timer/Realtime reconnect will reconcile it.
      if (previous == null || previous.isEmpty) {
        state = AsyncError(error, stackTrace);
      }
      _startFallback();
    } finally {
      _loading = false;
    }
  }

  Future<void> markSeen(String notificationId) async {
    final repository = _repository;
    if (repository == null) return;
    final current = state.valueOrNull ?? const <YorksV1NotificationRecord>[];
    final index = current.indexWhere((item) => item.id == notificationId);
    if (index < 0) {
      await repository.markSeen(notificationId);
      await refresh();
      return;
    }
    if (current[index].seenAt != null) return;
    final acknowledged = current[index].acknowledgedAt(DateTime.now());
    state = AsyncData([
      ...current.take(index),
      acknowledged,
      ...current.skip(index + 1),
    ]);
    try {
      await repository.markSeen(notificationId);
    } catch (_) {
      if (!_disposed) state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> markAllSeen() async {
    final repository = _repository;
    if (repository == null) return;
    final current = state.valueOrNull ?? const <YorksV1NotificationRecord>[];
    if (!current.any((record) => record.seenAt == null)) return;
    final acknowledgedAt = DateTime.now();
    state = AsyncData(
      current
          .map(
            (record) => record.seenAt == null
                ? record.acknowledgedAt(acknowledgedAt)
                : record,
          )
          .toList(growable: false),
    );
    try {
      await repository.markAllSeen();
    } catch (_) {
      if (!_disposed) state = AsyncData(current);
      rethrow;
    }
  }

  Future<bool> _subscribe() async {
    final client = _client;
    final authUserId = _authUserId;
    if (client == null || authUserId == null || authUserId.isEmpty) {
      return false;
    }
    try {
      final token = client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) return false;
      await client.realtime.setAuth(token);
      _authSubscription = client.auth.onAuthStateChange.listen((event) {
        final refreshed = event.session?.accessToken;
        if (refreshed != null && refreshed.isNotEmpty) {
          unawaited(client.realtime.setAuth(refreshed));
        }
      });
      final joined = Completer<bool>();
      _channel = client
          .channel('yorks-v1-notification-center:$authUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'v1_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_auth_user_id',
              value: authUserId,
            ),
            callback: (_) => unawaited(refresh()),
          )
          .subscribe((status, _) {
            if (_disposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              _fallbackTimer?.cancel();
              _fallbackTimer = null;
              if (!joined.isCompleted) joined.complete(true);
              unawaited(refresh());
            } else if (!joined.isCompleted &&
                status == RealtimeSubscribeStatus.channelError) {
              joined.complete(false);
            }
          });
      return joined.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  void _startFallback() {
    if (_fallbackTimer != null || _disposed || _repository == null) return;
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(refresh()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _authSubscription?.cancel();
    final channel = _channel;
    final client = _client;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    super.dispose();
  }
}
