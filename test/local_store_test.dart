import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/repositories/local_store.dart';

class _Thing {
  const _Thing(this.id);
  final String id;
  Map<String, dynamic> toJson() => {'id': id};
  // Throws if 'id' is absent (null as String) — simulates a malformed row.
  factory _Thing.fromJson(Map<String, dynamic> json) =>
      _Thing(json['id'] as String);
}

void main() {
  LocalCollectionStore<_Thing> store(SharedPreferences prefs) =>
      LocalCollectionStore<_Thing>(
        prefs: prefs,
        key: 'things',
        toJson: (t) => t.toJson(),
        fromJson: _Thing.fromJson,
      );

  test('one malformed row is skipped — the rest of the collection survives',
      () async {
    SharedPreferences.setMockInitialValues({
      'flutter.things': jsonEncode([
        {'id': 'a'},
        {'oops': 'no id here'}, // fromJson throws on this row
        {'id': 'c'},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final all = store(prefs).readAll();
    // The bad row is dropped; a single corrupt record can't wipe everything.
    expect(all.map((t) => t.id).toList(), ['a', 'c']);
  });

  test('a completely corrupt blob yields an empty list (no throw)', () async {
    SharedPreferences.setMockInitialValues({'flutter.things': 'not json {['});
    final prefs = await SharedPreferences.getInstance();
    expect(store(prefs).readAll(), isEmpty);
  });

  test('absent key → empty list', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(store(prefs).readAll(), isEmpty);
  });
}
