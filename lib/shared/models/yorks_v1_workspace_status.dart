/// The honest, role-safe connection state shown by the R35 workspace shell.
///
/// This is deliberately a workspace signal, not a record-level success claim.
/// Individual BOQ, Material Request and logistics editors retain their own
/// server-confirmed save/conflict state because a healthy connection cannot
/// prove that a particular command committed.
enum YorksV1WorkspaceConnectionState {
  connected,
  reconnecting,
  offline,
  syncing,
  saved,
  localDraft,
  conflict,
  failed,
}

class YorksV1WorkspaceStatus {
  const YorksV1WorkspaceStatus({
    required this.state,
    this.pendingChangeCount = 0,
    this.lastAuthoritativeRefresh,
  });

  final YorksV1WorkspaceConnectionState state;
  final int pendingChangeCount;

  /// Null means that this shell instance has not yet observed an authoritative
  /// refresh. The UI must not invent a "saved just now" timestamp in that case.
  final DateTime? lastAuthoritativeRefresh;

  bool get isConnected =>
      state == YorksV1WorkspaceConnectionState.connected ||
      state == YorksV1WorkspaceConnectionState.saved;

  bool get hasUncommittedWork =>
      state == YorksV1WorkspaceConnectionState.syncing ||
      state == YorksV1WorkspaceConnectionState.localDraft ||
      state == YorksV1WorkspaceConnectionState.conflict ||
      state == YorksV1WorkspaceConnectionState.failed ||
      pendingChangeCount > 0;
}
