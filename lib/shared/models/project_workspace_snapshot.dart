import 'audit_log.dart';
import 'material_plan.dart';
import 'material_request.dart';
import 'project.dart';
import 'user_role.dart';

/// The operational next step shown at the top of a project workspace.
///
/// These are intentionally workflow facts rather than display strings. The
/// presentation layer owns localisation and route selection.
enum ProjectWorkspaceAction {
  acceptProject,
  prepareMaterialPlan,
  reviewMaterialPlan,
  approveMaterialPlan,
  reviseMaterialPlan,
  submitRequestDraft,
  processMaterialRequests,
  confirmSiteReceipt,
  createMaterialRequest,
  projectOnHold,
  projectComplete,
}

/// Concrete conditions that prevent the project from moving cleanly.
///
/// Expected work (for example, preparing a plan) is represented by the current
/// action, not mislabeled as a blocker.
enum ProjectWorkspaceBlocker {
  procurementAcceptance,
  startDateMissing,
  physicalBuildingMissing,
  engineerAssignmentMissing,
  materialPlanChangesRequested,
  requestOnHold,
  projectOnHold,
}

enum ProjectWorkspaceReadinessKind {
  responsibility,
  buildingScope,
  procurementAcceptance,
  materialPlan,
  execution,
}

enum ProjectWorkspaceReadinessState { pending, inProgress, ready, blocked }

class ProjectWorkspaceReadiness {
  const ProjectWorkspaceReadiness({required this.kind, required this.state});

  final ProjectWorkspaceReadinessKind kind;
  final ProjectWorkspaceReadinessState state;
}

/// Read-only, connected view of a project and its existing downstream records.
///
/// Phase 5 deliberately derives this snapshot from the current stores. It does
/// not duplicate source data, invent RFQ/PO records, or calculate a weighted
/// completion percentage.
class ProjectWorkspaceSnapshot {
  const ProjectWorkspaceSnapshot({
    required this.project,
    required this.materialPlan,
    required this.requests,
    required this.activity,
    required this.currentAction,
    required this.currentOwnerRole,
    required this.currentOwnerUserIds,
    required this.blockers,
    required this.readiness,
  });

  final Project project;
  final MaterialPlan? materialPlan;
  final List<MaterialRequest> requests;
  final List<AuditEntry> activity;
  final ProjectWorkspaceAction currentAction;
  final UserRole? currentOwnerRole;
  final List<String> currentOwnerUserIds;
  final List<ProjectWorkspaceBlocker> blockers;
  final List<ProjectWorkspaceReadiness> readiness;

  List<MaterialRequest> get openRequests => requests
      .where(
        (request) =>
            request.status != RequestStatus.received &&
            request.status != RequestStatus.cancelled,
      )
      .toList(growable: false);

  int get requestItemCount =>
      requests.fold(0, (total, request) => total + request.itemCount);
}
