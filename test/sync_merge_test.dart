import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/sync/supabase_bootstrap.dart';

/// A cloud `{id, data}` row as returned by `.select('id, data')`.
Map<String, dynamic> row(String id, Map<String, dynamic> data) =>
    {'id': id, 'data': data};

void main() {
  group('SupabaseBootstrap.mergeRows', () {
    test('cloud wins on a shared id', () {
      final local = jsonEncode([
        {'id': 'a', 'v': 'local'},
      ]);
      final merged = SupabaseBootstrap.mergeRows(local, [
        row('a', {'id': 'a', 'v': 'cloud'}),
      ]);
      expect(merged.single['v'], 'cloud');
    });

    test('a local-only row (unsynced offline create) is preserved', () {
      final local = jsonEncode([
        {'id': 'a', 'v': 'cloud-known'},
        {'id': 'local-new', 'v': 'not-yet-pushed'},
      ]);
      final merged = SupabaseBootstrap.mergeRows(local, [
        row('a', {'id': 'a', 'v': 'cloud-known'}),
      ]);
      final ids = merged.map((m) => m['id']).toSet();
      expect(ids, {'a', 'local-new'});
    });

    test('a cloud-only row (created on another device) is added', () {
      final local = jsonEncode([
        {'id': 'a', 'v': 'x'},
      ]);
      final merged = SupabaseBootstrap.mergeRows(local, [
        row('a', {'id': 'a', 'v': 'x'}),
        row('b', {'id': 'b', 'v': 'new'}),
      ]);
      expect(merged.map((m) => m['id']).toSet(), {'a', 'b'});
    });

    test('null / empty local → just the cloud rows', () {
      final merged = SupabaseBootstrap.mergeRows(null, [
        row('a', {'id': 'a'}),
      ]);
      expect(merged.single['id'], 'a');
      expect(SupabaseBootstrap.mergeRows('', const []), isEmpty);
    });

    test('resolves id from the payload data when present', () {
      final merged = SupabaseBootstrap.mergeRows(null, [
        row('a', {'id': 'a', 'note': 'hi'}),
      ]);
      expect(merged.single['note'], 'hi');
    });

    test('preserves a privacy-held local field the cloud row omits', () {
      final local = jsonEncode([
        {'id': 'e1', 'name': 'A', 'salaryAED': 6500},
      ]);
      final merged = SupabaseBootstrap.mergeRows(
        local,
        [
          row('e1', {'id': 'e1', 'name': 'A-updated'}),
        ],
        preserveLocalKeys: ['salaryAED'],
      );
      expect(merged.single['name'], 'A-updated'); // cloud wins on shared fields
      expect(merged.single['salaryAED'], 6500); // local salary preserved
    });
  });
}
