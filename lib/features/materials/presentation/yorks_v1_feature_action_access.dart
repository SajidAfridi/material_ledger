import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';
import '../../../shared/models/app_language.dart';
import '../../../shared/models/yorks_v1_permission_management.dart';
import '../../../shared/models/yorks_v1_permission_strings.dart';
import '../../../shared/providers/yorks_v1_permission_provider.dart';

bool yorksV1CanReadProjectRecord(
  YorksV1CurrentPermissionSnapshotState state,
  String capabilityKey, {
  required bool legacyAllowed,
  required String projectId,
}) => state.hybridAllows(
  capabilityKey,
  legacyAllowed: legacyAllowed,
  projectId: projectId,
);

class YorksV1ProjectReadBoundary extends StatelessWidget {
  const YorksV1ProjectReadBoundary({
    super.key,
    required this.allowed,
    required this.language,
    required this.child,
  });

  final bool allowed;
  final AppLanguage language;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    return Center(
      key: const Key('yorks-v1-project-read-denied'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                YorksV1PermissionStrings.text(language, 'forbidden_title'),
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                YorksV1PermissionStrings.text(language, 'forbidden_body'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presentation decision for an already server-protected Yorks action.
///
/// This helper deliberately keeps the rollout hybrid. Shadow capabilities use
/// the exact-role/membership decision supplied by the existing feature. Once a
/// capability is enforced, only the current server-confirmed person-specific
/// decision for the concrete project is accepted. The server RPC/RLS remains
/// the final authority in both modes.
class YorksV1FeatureActionAccess {
  const YorksV1FeatureActionAccess({
    required this.isVisible,
    required this.canWrite,
    required this.authorizationMode,
  });

  const YorksV1FeatureActionAccess.denied()
    : isVisible = false,
      canWrite = false,
      authorizationMode = null;

  final bool isVisible;
  final bool canWrite;
  final YorksV1PermissionCapabilityAuthorizationMode? authorizationMode;

  /// A confirmed allow remains visible during a routine refresh, but the
  /// mutation pauses until the revision channel and snapshot are trustworthy.
  bool get isWritePaused => isVisible && !canWrite;
}

YorksV1FeatureActionAccess yorksV1FeatureActionAccess(
  YorksV1CurrentPermissionSnapshotState state,
  String capabilityKey, {
  required bool legacyAllowed,
  String? projectId,
  bool anyProject = false,
}) {
  final snapshot = state.snapshot;
  final access = snapshot?.capability(capabilityKey);
  if (snapshot == null ||
      !snapshot.user.isActive ||
      access == null ||
      !access.catalog.isOperational) {
    return const YorksV1FeatureActionAccess.denied();
  }

  // Person-specific grants refine the feature's existing structural, state,
  // ownership and separation-of-duty eligibility; they never manufacture an
  // action that the protected workflow projection says is ineligible.
  final allowed = switch (access.authorizationMode) {
    // Candidate permission values are parity evidence only while shadowed.
    YorksV1PermissionCapabilityAuthorizationMode.shadow => legacyAllowed,
    YorksV1PermissionCapabilityAuthorizationMode.enforced =>
      legacyAllowed &&
          _enforcedAllow(
            snapshot,
            access,
            capabilityKey,
            projectId: projectId,
            anyProject: anyProject,
          ),
  };
  return YorksV1FeatureActionAccess(
    isVisible: allowed,
    // Shadow preserves the legacy structural decision, while AP-16 still
    // pauses every mutation until the confirmed snapshot and its invalidation
    // channel are healthy.
    canWrite: allowed && state.isTrustedForWrites,
    authorizationMode: access.authorizationMode,
  );
}

bool _enforcedAllow(
  YorksV1CurrentPermissionSnapshot snapshot,
  YorksV1PermissionCapabilityAccess access,
  String capabilityKey, {
  String? projectId,
  required bool anyProject,
}) {
  final normalizedProjectId = projectId?.trim();
  if (normalizedProjectId != null && normalizedProjectId.isNotEmpty) {
    return snapshot.allows(capabilityKey, projectId: normalizedProjectId);
  }
  if (access.catalog.requiresProjectAccess) {
    if (!anyProject) return false;
    return snapshot.projectAccess.any(
      (project) =>
          project.hasAccess &&
          snapshot.allows(capabilityKey, projectId: project.projectId),
    );
  }
  return access.authoritativeEffective == true;
}
