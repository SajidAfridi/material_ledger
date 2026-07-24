import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mutation_op.dart';

/// Where queued mutations are committed. The one seam between the sync engine
/// and the real server. Implementations MUST be idempotent on
/// [MutationOp.idempotencyKey] / [MutationOp.docId] (a resend can never create a
/// duplicate) and MUST throw [PermanentSyncException] for non-retryable errors
/// (e.g. permission denied) and [TransientSyncException] for anything retryable
/// (offline, timeout, 5xx).
abstract interface class SyncBackend {
  Future<void> apply(MutationOp op);
}

/// Local backend (the prototype default). The local repository cache is the
/// source of truth here, so a queued op is already durably committed on the
/// device when it is enqueued — applying it is a confirmation. The outbox still
/// provides cross-restart durability, ordered retry, dead-lettering and the
/// sync-status UX, and becomes the real remote-write driver the moment a
/// network backend is swapped in.
class LocalSyncBackend implements SyncBackend {
  const LocalSyncBackend();

  @override
  Future<void> apply(MutationOp op) async {
    // No-op confirm: the write is already in the local cache/store. (A network
    // backend does the real remote write here — see the scaffolds below.)
  }
}

/// The app's sync backend. Swap to a network backend in production (see below).
final syncBackendProvider = Provider<SyncBackend>((ref) {
  return const LocalSyncBackend();
});

// Production uses SupabaseSyncBackend. Server-owned transactions and the
// normalized V7 repositories replace this generic document outbox batch by
// batch; Firestore is not an application data path.
