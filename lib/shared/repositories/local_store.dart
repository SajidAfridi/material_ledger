import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'collection_store.dart';

/// Local ([SharedPreferences]) adapter for [CollectionStore] — a JSON-list per
/// collection key. The default backend for the prototype; the remote adapters
/// (Firestore / REST) implement the same [CollectionStore] interface so nothing
/// upstream changes. `T` is the domain model; callers supply the JSON mappers so
/// the store stays model-agnostic.
class LocalCollectionStore<T> implements CollectionStore<T> {
  LocalCollectionStore({
    required this.prefs,
    required this.key,
    required this.toJson,
    required this.fromJson,
  });

  final SharedPreferences prefs;

  /// The persistence key (one per collection), e.g. `'rental_units_v1'`.
  final String key;

  final Map<String, dynamic> Function(T value) toJson;
  final T Function(Map<String, dynamic> json) fromJson;

  /// Read the whole collection. Returns `[]` when absent or unparseable.
  @override
  List<T> readAll() {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: true);
    } catch (_) {
      return <T>[];
    }
  }

  /// Replace the whole collection (the only write path — keeps reads/writes
  /// symmetric and easy to map onto a batched Firestore write).
  @override
  Future<void> writeAll(List<T> items) async {
    final raw = jsonEncode(items.map(toJson).toList());
    await prefs.setString(key, raw);
  }

  /// Whether the collection has ever been written (used to decide seeding).
  @override
  bool get isSeeded => prefs.containsKey(key);
}
