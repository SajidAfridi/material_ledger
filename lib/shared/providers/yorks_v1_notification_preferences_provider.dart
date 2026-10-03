import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_notification_preferences.dart';
import '../repositories/yorks_v1_notification_preferences_repository.dart';
import 'language_provider.dart';

final yorksV1NotificationPreferencesRepositoryProvider =
    Provider<YorksV1NotificationPreferencesRepository?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return null;
      return YorksV1SupabaseNotificationPreferencesRepository(client);
    });

final yorksV1NotificationPreferencesProvider =
    StateNotifierProvider<
      YorksV1NotificationPreferencesNotifier,
      AsyncValue<YorksV1NotificationPreferences>
    >((ref) {
      final client = ref.watch(supabaseClientProvider);
      final sessionId = ref.watch(authSessionProvider);
      final authUserId = client?.auth.currentUser?.id;
      final repository = ref.watch(
        yorksV1NotificationPreferencesRepositoryProvider,
      );
      final notifier = YorksV1NotificationPreferencesNotifier(
        repository: sessionId == null || authUserId == null ? null : repository,
      );
      unawaited(notifier.refresh());
      final timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(notifier.refresh()),
      );
      ref.onDispose(timer.cancel);
      return notifier;
    });

final yorksV1ForegroundAlertsEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(yorksV1NotificationPreferencesProvider)
          .valueOrNull
          ?.foregroundAlertsEnabled ??
      false;
});

final yorksV1NotificationSoundEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(yorksV1NotificationPreferencesProvider)
          .valueOrNull
          ?.soundEnabled ??
      false;
});

class YorksV1NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<YorksV1NotificationPreferences>> {
  YorksV1NotificationPreferencesNotifier({
    required YorksV1NotificationPreferencesRepository? repository,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _repository = repository,
       super(
         repository == null
             ? const AsyncData(YorksV1NotificationPreferences.defaults())
             : const AsyncLoading(),
       );

  final YorksV1NotificationPreferencesRepository? _repository;
  final Duration requestTimeout;
  Future<void>? _refresh;
  int _requestGeneration = 0;
  bool _saving = false;

  Future<void> refresh() {
    final repository = _repository;
    if (!mounted || repository == null || _saving) return Future<void>.value();
    final pending = _refresh;
    if (pending != null) return pending;
    final generation = ++_requestGeneration;
    late final Future<void> attempt;
    attempt = _load(repository, generation).whenComplete(() {
      if (identical(_refresh, attempt)) _refresh = null;
    });
    _refresh = attempt;
    return attempt;
  }

  Future<void> _load(
    YorksV1NotificationPreferencesRepository repository,
    int generation,
  ) async {
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncLoading();
    try {
      final result = await repository.loadMine().timeout(requestTimeout);
      if (!mounted || generation != _requestGeneration || _saving) return;
      // The server revision is monotonic for this account. A delayed read must
      // never re-enable delivery after a newer disabled choice was confirmed.
      if (result.revision < (state.valueOrNull?.revision ?? 0)) return;
      state = AsyncData(result);
    } catch (error, stackTrace) {
      if (!mounted || generation != _requestGeneration || _saving) return;
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncValue<YorksV1NotificationPreferences>.error(
              error,
              stackTrace,
            ).copyWithPrevious(AsyncData(previous));
    }
  }

  Future<YorksV1NotificationPreferences> save(
    YorksV1NotificationPreferences desired,
  ) async {
    if (!mounted) throw StateError('NOTIFICATION_PREFERENCES_UNAVAILABLE');
    if (_saving) throw StateError('NOTIFICATION_PREFERENCES_SAVE_IN_PROGRESS');
    final repository = _repository;
    final current = state.valueOrNull;
    if (repository == null || current == null) {
      throw StateError('NOTIFICATION_PREFERENCES_UNAVAILABLE');
    }
    _saving = true;
    // Retire a read that began before this write. Its response (or error) may
    // arrive after the confirmed update, while later reads get a fresh slot.
    final generation = ++_requestGeneration;
    _refresh = null;
    try {
      final saved = await repository
          .updateMine(desired: desired, expectedRevision: current.revision)
          .timeout(requestTimeout);
      if (!mounted || generation != _requestGeneration) {
        throw StateError('NOTIFICATION_PREFERENCES_UNAVAILABLE');
      }
      state = AsyncData(saved);
      return saved;
    } catch (error, stackTrace) {
      if (mounted && generation == _requestGeneration) {
        state = AsyncValue<YorksV1NotificationPreferences>.error(
          error,
          stackTrace,
        ).copyWithPrevious(AsyncData(current));
      }
      rethrow;
    } finally {
      _saving = false;
    }
  }
}
