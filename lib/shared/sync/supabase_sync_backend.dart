import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'mutation_op.dart';
import 'sync_backend.dart';

/// Commits queued mutations to a (self-hosted, UAE-region) Supabase / Postgres
/// instance. The outbox remains the single write driver — this is just the
/// "apply" target. Every collection maps to a table `<collection>` with an
/// `id text primary key` and a `data jsonb` column; a write is an UPSERT keyed
/// on the client-generated [MutationOp.docId], so a resend overwrites the same
/// row and can never create a duplicate (the outbox's exactly-once promise).
///
/// Reads still come from the local cache in this phase; this is the durable
/// write sink + foundation for server-side reporting and later realtime reads.
class SupabaseSyncBackend implements SyncBackend {
  const SupabaseSyncBackend(
    this._client, {
    this.timeout = const Duration(seconds: 30), // headroom for UAE mobile
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<void> apply(MutationOp op) async {
    try {
      await _client
          .from(op.collection)
          .upsert({
            'id': op.docId,
            'data': op.payload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'id')
          .timeout(timeout);
    } catch (error) {
      throw mapError(error);
    }
  }

  /// Translate a failure into the engine's retry contract: [PermanentSyncException]
  /// for things a retry can't fix (RLS/permission denial, integrity/data errors —
  /// dead-lettered and surfaced with Retry), [TransientSyncException] for
  /// everything else (offline, timeout, 5xx, token refresh — retried with backoff).
  static Exception mapError(Object error) {
    if (error is TimeoutException) {
      return const TransientSyncException('timeout');
    }
    if (error is PostgrestException) {
      return _isPermanentPostgres(error.code)
          ? PermanentSyncException(error.message)
          : TransientSyncException(error.message);
    }
    // AuthException (token expiry — auto-refresh + retry), SocketException,
    // ClientException and anything else network-shaped → retry.
    return TransientSyncException(error.toString());
  }

  /// Postgres SQLSTATE classes that a retry will never resolve:
  ///   42xxx — access rule / syntax (incl. 42501 insufficient_privilege = RLS)
  ///   23xxx — integrity constraint violation (FK, check, not-null)
  ///   22xxx — invalid data (bad type/format)
  /// Null / connection (08) / resource (53) / intervention (57) → transient.
  static bool _isPermanentPostgres(String? code) {
    if (code == null) return false;
    return code.startsWith('42') ||
        code.startsWith('23') ||
        code.startsWith('22');
  }
}
