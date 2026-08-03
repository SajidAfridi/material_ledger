import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_workspace_status.dart';
import '../sync/connectivity_service.dart';
import '../sync/sync_engine.dart';

/// Shared shell state derived from real reachability and the durable outbox.
///
/// Normalized V1 commands report their own result near the affected record;
/// the shell intentionally reports only what it can prove globally and never
/// turns a connection indicator into a false record-save acknowledgement.
final yorksV1WorkspaceStatusProvider = Provider<YorksV1WorkspaceStatus>((ref) {
  final syncState = ref.watch(syncStatusProvider);
  final pendingCount = ref.watch(pendingSyncCountProvider);
  final online = ref.watch(isOnlineProvider);

  if (!online && syncState != SyncState.error) {
    return YorksV1WorkspaceStatus(
      state: YorksV1WorkspaceConnectionState.offline,
      pendingChangeCount: pendingCount,
    );
  }

  return switch (syncState) {
    SyncState.synced => const YorksV1WorkspaceStatus(
      state: YorksV1WorkspaceConnectionState.connected,
    ),
    SyncState.syncing => YorksV1WorkspaceStatus(
      state: YorksV1WorkspaceConnectionState.syncing,
      pendingChangeCount: pendingCount,
    ),
    SyncState.offlineQueued => YorksV1WorkspaceStatus(
      state: YorksV1WorkspaceConnectionState.offline,
      pendingChangeCount: pendingCount,
    ),
    SyncState.error => YorksV1WorkspaceStatus(
      state: YorksV1WorkspaceConnectionState.failed,
      pendingChangeCount: pendingCount,
    ),
  };
});
