import 'package:flutter/material.dart';

import '../core/constants/constants.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_shell_strings.dart';
import '../shared/models/yorks_v1_workspace_status.dart';

/// A small status treatment shared by the top bar and persistent sidebar.
/// It only describes the globally observable connection/outbox state; record
/// editors render their own authoritative save or conflict state locally.
class YorksV1WorkspaceStatusLabel extends StatelessWidget {
  const YorksV1WorkspaceStatusLabel({
    super.key,
    required this.status,
    this.compact = false,
  });

  final YorksV1WorkspaceStatus status;
  final bool compact;

  static Color colorFor(YorksV1WorkspaceConnectionState state) =>
      switch (state) {
        YorksV1WorkspaceConnectionState.connected ||
        YorksV1WorkspaceConnectionState.saved => AppColors.success,
        YorksV1WorkspaceConnectionState.reconnecting ||
        YorksV1WorkspaceConnectionState.syncing => AppColors.blue,
        YorksV1WorkspaceConnectionState.offline ||
        YorksV1WorkspaceConnectionState.localDraft => AppColors.warning,
        YorksV1WorkspaceConnectionState.conflict ||
        YorksV1WorkspaceConnectionState.failed => AppColors.error,
      };

  static IconData _iconFor(YorksV1WorkspaceConnectionState state) =>
      switch (state) {
        YorksV1WorkspaceConnectionState.connected ||
        YorksV1WorkspaceConnectionState.saved => Icons.cloud_done_outlined,
        YorksV1WorkspaceConnectionState.reconnecting => Icons.sync_outlined,
        YorksV1WorkspaceConnectionState.offline => Icons.cloud_off_outlined,
        YorksV1WorkspaceConnectionState.syncing => Icons.sync_rounded,
        YorksV1WorkspaceConnectionState.localDraft => Icons.edit_note_outlined,
        YorksV1WorkspaceConnectionState.conflict => Icons.sync_problem_outlined,
        YorksV1WorkspaceConnectionState.failed => Icons.error_outline_rounded,
      };

  static TranslatableString _copyFor(YorksV1WorkspaceConnectionState state) =>
      switch (state) {
        YorksV1WorkspaceConnectionState.connected =>
          YorksV1ShellStrings.workspaceConnected,
        YorksV1WorkspaceConnectionState.reconnecting =>
          YorksV1ShellStrings.workspaceReconnecting,
        YorksV1WorkspaceConnectionState.offline =>
          YorksV1ShellStrings.workspaceOffline,
        YorksV1WorkspaceConnectionState.syncing =>
          YorksV1ShellStrings.workspaceSyncing,
        YorksV1WorkspaceConnectionState.saved =>
          YorksV1ShellStrings.savedJustNow,
        YorksV1WorkspaceConnectionState.localDraft =>
          YorksV1ShellStrings.workspaceLocalDraft,
        YorksV1WorkspaceConnectionState.conflict =>
          YorksV1ShellStrings.workspaceConflict,
        YorksV1WorkspaceConnectionState.failed =>
          YorksV1ShellStrings.workspaceFailed,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status.state);
    return Semantics(
      label: _copyFor(status.state).primary,
      liveRegion: status.state != YorksV1WorkspaceConnectionState.connected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(status.state), size: compact ? 14 : 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _copyFor(status.state).primary,
            style:
                (compact ? AppTypography.labelSmall : AppTypography.labelMedium)
                    .copyWith(
                      color: compact ? AppColors.inkSecondary : AppColors.muted,
                      fontWeight: compact ? FontWeight.w700 : null,
                    ),
          ),
        ],
      ),
    );
  }
}
