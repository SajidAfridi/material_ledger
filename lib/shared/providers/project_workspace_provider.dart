import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_plan.dart';
import '../models/material_request.dart';
import '../models/project.dart';
import '../models/project_workspace_snapshot.dart';
import '../models/user_role.dart';
import 'audit_log_provider.dart';
import 'material_plan_provider.dart';
import 'material_request_provider.dart';
import 'project_provider.dart';

/// Connected, role-safe project workspace snapshot.
///
/// Using [visibleProjectsProvider] is important: a guessed deep link cannot
/// expose an engineer to a project they are not assigned to. Office roles
/// already receive the full register through that provider.
final projectWorkspaceProvider =
    Provider.family<ProjectWorkspaceSnapshot?, String>((ref, projectId) {
      Project? project;
      for (final candidate in ref.watch(visibleProjectsProvider)) {
        if (candidate.id == projectId) {
          project = candidate;
          break;
        }
      }
      if (project == null) return null;

      final plan = ref.watch(planForProjectProvider(projectId));
      final requests =
          ref
              .watch(materialRequestsProvider)
              .where((request) => _belongsToProject(request, project!))
              .toList(growable: false)
            ..sort((a, b) => b.requestDate.compareTo(a.requestDate));
      final activity =
          ref
              .watch(auditLogProvider)
              .where((entry) => entry.refId == project!.id)
              .toList(growable: false)
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final action = _deriveCurrentAction(project, plan, requests);
      return ProjectWorkspaceSnapshot(
        project: project,
        materialPlan: plan,
        requests: requests,
        activity: activity,
        currentAction: action,
        currentOwnerRole: _ownerRole(action),
        currentOwnerUserIds: _ownerUserIds(project, action),
        blockers: _deriveBlockers(project, plan, requests),
        readiness: _deriveReadiness(project, plan),
      );
    });

bool _belongsToProject(MaterialRequest request, Project project) =>
    request.projectId != null
    ? request.projectId == project.id
    : request.projectName == project.name;

ProjectWorkspaceAction _deriveCurrentAction(
  Project project,
  MaterialPlan? plan,
  List<MaterialRequest> requests,
) {
  if (project.lifecycleStatus == ProjectLifecycleStatus.archived ||
      project.phase?.state == ProjectState.completed) {
    return ProjectWorkspaceAction.projectComplete;
  }
  if (project.phase?.state == ProjectState.onHold) {
    return ProjectWorkspaceAction.projectOnHold;
  }
  if (!project.acceptedByProcurement) {
    return ProjectWorkspaceAction.acceptProject;
  }

  final executionAlreadyActive =
      project.lifecycleStatus == ProjectLifecycleStatus.active ||
      project.phase?.state == ProjectState.active;
  if ((plan == null || plan.status == MaterialPlanStatus.draft) &&
      !executionAlreadyActive) {
    return ProjectWorkspaceAction.prepareMaterialPlan;
  }
  switch (plan?.status) {
    case MaterialPlanStatus.submitted:
    case MaterialPlanStatus.procurementReview:
      return ProjectWorkspaceAction.reviewMaterialPlan;
    case MaterialPlanStatus.pendingEngineerApproval:
      return ProjectWorkspaceAction.approveMaterialPlan;
    case MaterialPlanStatus.rejected:
      return ProjectWorkspaceAction.reviseMaterialPlan;
    case MaterialPlanStatus.draft:
    case null:
      break;
    case MaterialPlanStatus.approved:
    case MaterialPlanStatus.superseded:
      break;
  }

  final open = requests.where(
    (request) =>
        request.status != RequestStatus.received &&
        request.status != RequestStatus.cancelled,
  );
  if (open.any((request) => request.status == RequestStatus.dispatched)) {
    return ProjectWorkspaceAction.confirmSiteReceipt;
  }
  if (open.any((request) => request.status == RequestStatus.draft)) {
    return ProjectWorkspaceAction.submitRequestDraft;
  }
  if (open.any(
    (request) =>
        request.status == RequestStatus.pending ||
        request.status == RequestStatus.sourcing ||
        request.status == RequestStatus.partial ||
        request.status == RequestStatus.onHold,
  )) {
    return ProjectWorkspaceAction.processMaterialRequests;
  }
  return ProjectWorkspaceAction.createMaterialRequest;
}

UserRole? _ownerRole(ProjectWorkspaceAction action) => switch (action) {
  ProjectWorkspaceAction.acceptProject ||
  ProjectWorkspaceAction.reviewMaterialPlan ||
  ProjectWorkspaceAction.processMaterialRequests => UserRole.procurement,
  ProjectWorkspaceAction.prepareMaterialPlan ||
  ProjectWorkspaceAction.approveMaterialPlan ||
  ProjectWorkspaceAction.reviseMaterialPlan ||
  ProjectWorkspaceAction.submitRequestDraft ||
  ProjectWorkspaceAction.confirmSiteReceipt ||
  ProjectWorkspaceAction.createMaterialRequest => UserRole.engineer,
  ProjectWorkspaceAction.projectOnHold => UserRole.admin,
  ProjectWorkspaceAction.projectComplete => null,
};

List<String> _ownerUserIds(Project project, ProjectWorkspaceAction action) {
  if (_ownerRole(action) != UserRole.engineer) return const [];
  final ids = <String>{
    ...project.designEngineerUserIds,
    ?project.assignedEngineerId,
  };
  return ids.toList(growable: false);
}

List<ProjectWorkspaceBlocker> _deriveBlockers(
  Project project,
  MaterialPlan? plan,
  List<MaterialRequest> requests,
) {
  return [
    if (!project.acceptedByProcurement)
      ProjectWorkspaceBlocker.procurementAcceptance,
    if (project.startDate == null) ProjectWorkspaceBlocker.startDateMissing,
    if (!project.buildings.any(
      (building) =>
          building.active && building.scope == ProjectBuildingScope.physical,
    ))
      ProjectWorkspaceBlocker.physicalBuildingMissing,
    if (project.designEngineerUserIds.isEmpty &&
        project.assignedEngineerId == null)
      ProjectWorkspaceBlocker.engineerAssignmentMissing,
    if (plan?.status == MaterialPlanStatus.rejected)
      ProjectWorkspaceBlocker.materialPlanChangesRequested,
    if (requests.any((request) => request.status == RequestStatus.onHold))
      ProjectWorkspaceBlocker.requestOnHold,
    if (project.phase?.state == ProjectState.onHold)
      ProjectWorkspaceBlocker.projectOnHold,
  ];
}

List<ProjectWorkspaceReadiness> _deriveReadiness(
  Project project,
  MaterialPlan? plan,
) {
  final responsibilityReady =
      project.projectManagerUserId != null &&
      (project.designEngineerUserIds.isNotEmpty ||
          project.assignedEngineerId != null);
  final buildingReady = project.buildings.any(
    (building) =>
        building.active && building.scope == ProjectBuildingScope.physical,
  );
  final planState = switch (plan?.status) {
    null || MaterialPlanStatus.draft => ProjectWorkspaceReadinessState.pending,
    MaterialPlanStatus.rejected => ProjectWorkspaceReadinessState.blocked,
    MaterialPlanStatus.approved => ProjectWorkspaceReadinessState.ready,
    _ => ProjectWorkspaceReadinessState.inProgress,
  };
  final executionReady =
      project.lifecycleStatus == ProjectLifecycleStatus.active ||
      plan?.status == MaterialPlanStatus.approved;

  return [
    ProjectWorkspaceReadiness(
      kind: ProjectWorkspaceReadinessKind.responsibility,
      state: responsibilityReady
          ? ProjectWorkspaceReadinessState.ready
          : ProjectWorkspaceReadinessState.blocked,
    ),
    ProjectWorkspaceReadiness(
      kind: ProjectWorkspaceReadinessKind.buildingScope,
      state: buildingReady
          ? ProjectWorkspaceReadinessState.ready
          : ProjectWorkspaceReadinessState.blocked,
    ),
    ProjectWorkspaceReadiness(
      kind: ProjectWorkspaceReadinessKind.procurementAcceptance,
      state: project.acceptedByProcurement
          ? ProjectWorkspaceReadinessState.ready
          : ProjectWorkspaceReadinessState.pending,
    ),
    ProjectWorkspaceReadiness(
      kind: ProjectWorkspaceReadinessKind.materialPlan,
      state: planState,
    ),
    ProjectWorkspaceReadiness(
      kind: ProjectWorkspaceReadinessKind.execution,
      state: executionReady
          ? ProjectWorkspaceReadinessState.ready
          : ProjectWorkspaceReadinessState.pending,
    ),
  ];
}
