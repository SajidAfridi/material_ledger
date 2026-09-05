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
      return notifier;
    });

final yorksV1ForegroundAlertsEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(yorksV1NotificationPreferencesProvider)
          .valueOrNull
          ?.foregroundAlertsEnabled ??
      true;
});

final yorksV1NotificationSoundEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(yorksV1NotificationPreferencesProvider)
          .valueOrNull
          ?.soundEnabled ??
      true;
});

class YorksV1NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<YorksV1NotificationPreferences>> {
  YorksV1NotificationPreferencesNotifier({
    required YorksV1NotificationPreferencesRepository? repository,
  }) : _repository = repository,
       super(
         repository == null
             ? const AsyncData(YorksV1NotificationPreferences.defaults())
             : const AsyncLoading(),
       );

  final YorksV1NotificationPreferencesRepository? _repository;
  bool _refreshing = false;
  bool _saving = false;

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null || _refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncLoading();
    try {
      state = AsyncData(await repository.loadMine());
    } catch (error, stackTrace) {
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncValue<YorksV1NotificationPreferences>.error(
              error,
              stackTrace,
            ).copyWithPrevious(AsyncData(previous));
    } finally {
      _refreshing = false;
    }
  }

  Future<YorksV1NotificationPreferences> save(
    YorksV1NotificationPreferences desired,
  ) async {
    if (_saving) throw StateError('NOTIFICATION_PREFERENCES_SAVE_IN_PROGRESS');
    final repository = _repository;
    final current = state.valueOrNull;
    if (repository == null || current == null) {
      throw StateError('NOTIFICATION_PREFERENCES_UNAVAILABLE');
    }
    _saving = true;
    try {
      final saved = await repository.updateMine(
        desired: desired,
        expectedRevision: current.revision,
      );
      state = AsyncData(saved);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncValue<YorksV1NotificationPreferences>.error(
        error,
        stackTrace,
      ).copyWithPrevious(AsyncData(current));
      rethrow;
    } finally {
      _saving = false;
    }
  }
}
