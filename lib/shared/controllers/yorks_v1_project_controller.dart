import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_project.dart';
import '../models/yorks_v1_role.dart';
import '../repositories/yorks_v1_project_repository.dart';

enum YorksV1ProjectCommandOperation {
  none,
  createProject,
  updateProject,
  archiveProject,
  assignProjectMember,
  revokeProjectMember,
  setProjectState,
}

enum YorksV1ProjectCommandStatus { idle, saving, succeeded, failed }

/// Non-presentational command state for the V1 project workflows. Presentation
/// maps its machine-readable fields to localized feedback and retry actions.
class YorksV1ProjectCommandState {
  const YorksV1ProjectCommandState({
    this.operation = YorksV1ProjectCommandOperation.none,
    this.status = YorksV1ProjectCommandStatus.idle,
    this.errorCode,
    this.validationErrors = const {},
    this.latestProject,
    this.latestMember,
  });

  final YorksV1ProjectCommandOperation operation;
  final YorksV1ProjectCommandStatus status;
  final YorksV1DomainErrorCode? errorCode;
  final Set<YorksV1ProjectValidationCode> validationErrors;
  final YorksV1Project? latestProject;
  final YorksV1ProjectMember? latestMember;
}

/// UI-facing project command boundary. It makes client eligibility explicit,
/// but never substitutes that check for the RLS/RPC authority on the server.
class YorksV1ProjectCommandController
    extends StateNotifier<YorksV1ProjectCommandState> {
  YorksV1ProjectCommandController({
    required YorksV1ProjectRepository repository,
    required YorksV1Role? Function() currentRole,
  }) : _repository = repository,
       _currentRole = currentRole,
       super(const YorksV1ProjectCommandState());

  final YorksV1ProjectRepository _repository;
  final YorksV1Role? Function() _currentRole;

  Future<YorksV1ProjectCreationResult> createProject(
    YorksV1ProjectCreationInput input,
  ) async {
    final role = _requireRole(
      YorksV1ProjectCommandOperation.createProject,
      (role) => role.canCreateProject,
    );
    if (!input.initialMembersAllowedFor(role)) {
      _failed(
        YorksV1ProjectCommandOperation.createProject,
        YorksV1DomainErrorCode.unauthorized,
      );
      throw const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized);
    }
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      _invalid(YorksV1ProjectCommandOperation.createProject, validationErrors);
    }
    _saving(YorksV1ProjectCommandOperation.createProject);
    try {
      final result = await _repository.createProject(input);
      state = YorksV1ProjectCommandState(
        operation: YorksV1ProjectCommandOperation.createProject,
        status: YorksV1ProjectCommandStatus.succeeded,
        latestProject: result.project,
      );
      return result;
    } on YorksV1DomainException catch (error) {
      _failed(YorksV1ProjectCommandOperation.createProject, error.code);
      rethrow;
    }
  }

  Future<YorksV1ProjectMembershipResult> assignProjectMember(
    YorksV1AssignProjectMemberInput input,
  ) async {
    _requireRole(
      YorksV1ProjectCommandOperation.assignProjectMember,
      (role) => role.canManageProjectMembers,
    );
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      _invalid(
        YorksV1ProjectCommandOperation.assignProjectMember,
        validationErrors,
      );
    }
    _saving(YorksV1ProjectCommandOperation.assignProjectMember);
    try {
      final result = await _repository.assignProjectMember(input);
      state = YorksV1ProjectCommandState(
        operation: YorksV1ProjectCommandOperation.assignProjectMember,
        status: YorksV1ProjectCommandStatus.succeeded,
        latestProject: result.project,
        latestMember: result.member,
      );
      return result;
    } on YorksV1DomainException catch (error) {
      _failed(YorksV1ProjectCommandOperation.assignProjectMember, error.code);
      rethrow;
    }
  }

  Future<YorksV1ProjectMembershipResult> revokeProjectMember(
    YorksV1RevokeProjectMemberInput input,
  ) async {
    _requireRole(
      YorksV1ProjectCommandOperation.revokeProjectMember,
      // A base Site Engineer can hold the active Project Engineer membership
      // required by this project-scoped command. The RPC remains authoritative
      // and denies a Site Engineer without that dated membership.
      (role) => role.canManageProjectMembers,
    );
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      _invalid(
        YorksV1ProjectCommandOperation.revokeProjectMember,
        validationErrors,
      );
    }
    _saving(YorksV1ProjectCommandOperation.revokeProjectMember);
    try {
      final result = await _repository.revokeProjectMember(input);
      state = YorksV1ProjectCommandState(
        operation: YorksV1ProjectCommandOperation.revokeProjectMember,
        status: YorksV1ProjectCommandStatus.succeeded,
        latestProject: result.project,
        latestMember: result.member,
      );
      return result;
    } on YorksV1DomainException catch (error) {
      _failed(YorksV1ProjectCommandOperation.revokeProjectMember, error.code);
      rethrow;
    }
  }

  Future<YorksV1Project> setProjectState(
    YorksV1SetProjectStateInput input,
  ) async {
    final role = _requireRole(
      YorksV1ProjectCommandOperation.setProjectState,
      (role) => role.canSetProjectState,
    );
    // Archiving is a closure correction boundary. The client guards it early
    // for clarity; the trusted RPC enforces the same rule under its row lock.
    if (input.targetState == YorksV1ProjectLifecycle.archived &&
        role != YorksV1Role.admin) {
      _failed(
        YorksV1ProjectCommandOperation.setProjectState,
        YorksV1DomainErrorCode.unauthorized,
      );
      throw const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized);
    }
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      _invalid(
        YorksV1ProjectCommandOperation.setProjectState,
        validationErrors,
      );
    }
    _saving(YorksV1ProjectCommandOperation.setProjectState);
    try {
      final project = await _repository.setProjectState(input);
      state = YorksV1ProjectCommandState(
        operation: YorksV1ProjectCommandOperation.setProjectState,
        status: YorksV1ProjectCommandStatus.succeeded,
        latestProject: project,
      );
      return project;
    } on YorksV1DomainException catch (error) {
      _failed(YorksV1ProjectCommandOperation.setProjectState, error.code);
      rethrow;
    }
  }

  Future<YorksV1Project> updateProject(YorksV1ProjectUpdateInput input) async {
    _requireRole(
      YorksV1ProjectCommandOperation.updateProject,
      (role) => role.isEngineering || role == YorksV1Role.admin,
    );
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      _invalid(YorksV1ProjectCommandOperation.updateProject, validationErrors);
    }
    _saving(YorksV1ProjectCommandOperation.updateProject);
    try {
      final project = await _repository.updateProject(input);
      state = YorksV1ProjectCommandState(
        operation: YorksV1ProjectCommandOperation.updateProject,
        status: YorksV1ProjectCommandStatus.succeeded,
        latestProject: project,
      );
      return project;
    } on YorksV1DomainException catch (error) {
      _failed(YorksV1ProjectCommandOperation.updateProject, error.code);
      rethrow;
    }
  }

  Future<YorksV1Project> archiveProject(
    YorksV1ArchiveProjectInput input,
  ) async {
    final role = _requireRole(
      YorksV1ProjectCommandOperation.archiveProject,
      (role) => role == YorksV1Role.admin,
    );
    if (role != YorksV1Role.admin) {
      _failed(
        YorksV1ProjectCommandOperation.archiveProject,
        YorksV1DomainErrorCode.unauthorized,
      );
      throw const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized);
    }
    final validationErrors = input.validate();
    if (validationErrors.isNotEmpty) {
      _invalid(YorksV1ProjectCommandOperation.archiveProject, validationErrors);
    }
    _saving(YorksV1ProjectCommandOperation.archiveProject);
    try {
      final project = await _repository.archiveProject(input);
      state = YorksV1ProjectCommandState(
        operation: YorksV1ProjectCommandOperation.archiveProject,
        status: YorksV1ProjectCommandStatus.succeeded,
        latestProject: project,
      );
      return project;
    } on YorksV1DomainException catch (error) {
      _failed(YorksV1ProjectCommandOperation.archiveProject, error.code);
      rethrow;
    }
  }

  void reset() => state = const YorksV1ProjectCommandState();

  YorksV1Role _requireRole(
    YorksV1ProjectCommandOperation operation,
    bool Function(YorksV1Role role) predicate,
  ) {
    final role = _currentRole();
    if (role == null) {
      _failed(operation, YorksV1DomainErrorCode.unauthenticated);
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unauthenticated,
      );
    }
    if (!predicate(role)) {
      _failed(operation, YorksV1DomainErrorCode.unauthorized);
      throw const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized);
    }
    return role;
  }

  Never _invalid(
    YorksV1ProjectCommandOperation operation,
    Set<YorksV1ProjectValidationCode> validationErrors,
  ) {
    state = YorksV1ProjectCommandState(
      operation: operation,
      status: YorksV1ProjectCommandStatus.failed,
      errorCode: YorksV1DomainErrorCode.invalidInput,
      validationErrors: Set.unmodifiable(validationErrors),
    );
    throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
  }

  void _saving(YorksV1ProjectCommandOperation operation) {
    state = YorksV1ProjectCommandState(
      operation: operation,
      status: YorksV1ProjectCommandStatus.saving,
    );
  }

  void _failed(
    YorksV1ProjectCommandOperation operation,
    YorksV1DomainErrorCode code,
  ) {
    state = YorksV1ProjectCommandState(
      operation: operation,
      status: YorksV1ProjectCommandStatus.failed,
      errorCode: code,
    );
  }
}
