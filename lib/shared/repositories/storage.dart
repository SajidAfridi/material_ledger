import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import 'collection_store.dart';
import 'local_store.dart';

typedef JsonMap = Map<String, dynamic>;

/// Factory for [CollectionStore]s — the application's backend abstraction.
///
/// Providers obtain their store via `ref.watch(storageProvider).collection(...)`
/// and never reference a concrete backend. To move off local storage, implement
/// this interface once (e.g. `FirestoreStorage`, `RestStorage`) and point
/// [storageProvider] at it — every collection follows automatically. See
/// docs/ARCHITECTURE.md.
abstract interface class Storage {
  CollectionStore<T> collection<T>(
    String name, {
    required JsonMap Function(T value) toJson,
    required T Function(JsonMap json) fromJson,
  });
}

/// Local-storage backend (the default). Each collection is a JSON list under a
/// versioned key in [SharedPreferences].
class LocalStorage implements Storage {
  const LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  CollectionStore<T> collection<T>(
    String name, {
    required JsonMap Function(T value) toJson,
    required T Function(JsonMap json) fromJson,
  }) {
    return LocalCollectionStore<T>(
      prefs: _prefs,
      key: name,
      toJson: toJson,
      fromJson: fromJson,
    );
  }
}

/// The single seam to swap the whole app's persistence backend.
///
/// Today: [LocalStorage] over `SharedPreferences`. To go to Firebase or a custom
/// (ASP.NET) server, return a `FirestoreStorage` / `RestStorage` here instead —
/// no other file changes.
final storageProvider = Provider<Storage>((ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
});
