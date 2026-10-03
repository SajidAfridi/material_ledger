import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'yorks_v1_project_draft_store.dart';

ProjectDraftAtomicStorage createProjectDraftAtomicStorage(
  SharedPreferences preferences,
) => SharedPreferencesProjectDraftStorage(preferences);

/// Serialized within this app process. Native SharedPreferences cannot promise
/// atomic ownership across separate app processes. The new setup release gate
/// must keep that unsupported guarantee guarded; browser persistence has a real
/// cross-tab primitive. This boundary never silently upgrades process safety.
class SharedPreferencesProjectDraftStorage
    implements ProjectDraftAtomicStorage {
  SharedPreferencesProjectDraftStorage(this.preferences);
  final SharedPreferences preferences;
  static final Map<String, Future<void>> _tails = {};

  @override
  bool get supportsAtomicOwnership => false;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<T> transaction<T>(
    String lockKey,
    T Function(ProjectDraftAtomicTransaction transaction) work,
  ) async {
    final previous = _tails[lockKey] ?? Future<void>.value();
    final finished = Completer<void>();
    _tails[lockKey] = finished.future;
    try {
      await previous;
      final tx = _PreferenceTransaction(preferences);
      final result = work(tx);
      await tx.commit();
      return result;
    } finally {
      finished.complete();
      if (identical(_tails[lockKey], finished.future)) _tails.remove(lockKey);
    }
  }
}

class _PreferenceTransaction implements ProjectDraftAtomicTransaction {
  _PreferenceTransaction(this.preferences);
  final SharedPreferences preferences;
  final Map<String, String?> _writes = {};

  @override
  String? read(String key) =>
      _writes.containsKey(key) ? _writes[key] : preferences.getString(key);

  @override
  void write(String key, String value) => _writes[key] = value;

  @override
  void remove(String key) => _writes[key] = null;

  Future<void> commit() async {
    for (final entry in _writes.entries) {
      final acknowledged = entry.value == null
          ? await preferences.remove(entry.key)
          : await preferences.setString(entry.key, entry.value!);
      if (!acknowledged) {
        throw const ProjectDraftStorageException('write_not_acknowledged');
      }
    }
  }
}
