import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/sync/mutation_op.dart';
import 'package:material_ledger/shared/sync/supabase_sync_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseSyncBackend.mapError — retry classification', () {
    test('timeout → transient (retry)', () {
      expect(
        SupabaseSyncBackend.mapError(TimeoutException('x')),
        isA<TransientSyncException>(),
      );
    });

    test('RLS / permission denied (42501) → permanent (dead-letter)', () {
      expect(
        SupabaseSyncBackend.mapError(
          const PostgrestException(message: 'denied', code: '42501'),
        ),
        isA<PermanentSyncException>(),
      );
    });

    test('integrity violation (23503 FK) → permanent', () {
      expect(
        SupabaseSyncBackend.mapError(
          const PostgrestException(message: 'fk', code: '23503'),
        ),
        isA<PermanentSyncException>(),
      );
    });

    test('invalid data (22P02) → permanent', () {
      expect(
        SupabaseSyncBackend.mapError(
          const PostgrestException(message: 'bad input', code: '22P02'),
        ),
        isA<PermanentSyncException>(),
      );
    });

    test('too many connections (53300) → transient', () {
      expect(
        SupabaseSyncBackend.mapError(
          const PostgrestException(message: 'overloaded', code: '53300'),
        ),
        isA<TransientSyncException>(),
      );
    });

    test('no SQLSTATE code → transient (safe to retry)', () {
      expect(
        SupabaseSyncBackend.mapError(
          const PostgrestException(message: 'unknown'),
        ),
        isA<TransientSyncException>(),
      );
    });

    test('arbitrary/network error → transient', () {
      expect(
        SupabaseSyncBackend.mapError(Exception('socket closed')),
        isA<TransientSyncException>(),
      );
    });
  });
}
