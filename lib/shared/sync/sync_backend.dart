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

// ───────────────────────────────────────────────────────────────────────────
// PRODUCTION SCAFFOLDS — reference implementations. Kept as documentation (not
// compiled) so the prototype stays dependency-light; copy into a real backend
// adapter once `cloud_firestore` / your REST client is added, then point
// `syncBackendProvider` at it.
// ───────────────────────────────────────────────────────────────────────────
//
// Firestore (built-in offline persistence + transactions):
//
//   // main(): enable offline persistence on mobile AND web.
//   FirebaseFirestore.instance.settings = const Settings(
//     persistenceEnabled: true,                 // mobile
//     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
//   );
//   // Web: await FirebaseFirestore.instance.enablePersistence(
//   //   const PersistenceSettings(synchronizeTabs: true));
//
//   class FirestoreSyncBackend implements SyncBackend {
//     final FirebaseFirestore _db;
//     const FirestoreSyncBackend(this._db);
//     @override
//     Future<void> apply(MutationOp op) async {
//       try {
//         final doc = _db.collection(op.collection).doc(op.docId); // client id
//         if (op.isTransactional) {
//           await _db.runTransaction((tx) async {        // atomic stock/balance
//             // read current doc, compute new state from op.payload, tx.set(...)
//           }).timeout(const Duration(seconds: 20));
//         } else {
//           await doc.set(op.payload, SetOptions(merge: true))   // idempotent
//               .timeout(const Duration(seconds: 20));
//         }
//       } on FirebaseException catch (e) {
//         if (e.code == 'permission-denied' || e.code == 'invalid-argument') {
//           throw PermanentSyncException(e.message ?? e.code);
//         }
//         throw TransientSyncException(e.message ?? e.code); // unavailable, etc.
//       } on TimeoutException {
//         throw const TransientSyncException('timeout');
//       }
//     }
//   }
//
// Custom server (ASP.NET / REST):
//
//   class RestSyncBackend implements SyncBackend {
//     final http.Client _client; final String _base; final String _token;
//     @override
//     Future<void> apply(MutationOp op) async {
//       final res = await _client
//           .put(Uri.parse('$_base/api/${op.collection}/${op.docId}'),
//               headers: {'Authorization': 'Bearer $_token',
//                         'Idempotency-Key': op.idempotencyKey,   // server dedupe
//                         'Content-Type': 'application/json'},
//               body: jsonEncode(op.payload))
//           .timeout(const Duration(seconds: 20));
//       if (res.statusCode == 401 || res.statusCode == 403) {
//         throw PermanentSyncException('HTTP ${res.statusCode}');
//       }
//       if (res.statusCode >= 500 || res.statusCode == 408) {
//         throw TransientSyncException('HTTP ${res.statusCode}');
//       }
//     }
//   }
