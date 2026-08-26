import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../data/accounts_repository.dart';
import '../domain/accounts_inputs.dart';
import '../domain/accounts_models.dart';

enum YorksAccountsViewStatus {
  idle,
  loading,
  success,
  forbidden,
  offline,
  conflict,
  uncertain,
  sessionExpired,
  unavailable,
  failure,
}

final class YorksAccountsProjectState {
  const YorksAccountsProjectState({
    this.status = YorksAccountsViewStatus.idle,
    this.baseline,
    this.progress,
    this.revisionHistory,
    this.error,
    this.isMutating = false,
  });

  final YorksAccountsViewStatus status;
  final YorksAccountsBaselineProjection? baseline;
  final YorksAccountsProgressProjection? progress;
  final YorksAccountsProgressRevisionProjection? revisionHistory;
  final YorksV1DomainException? error;
  final bool isMutating;

  bool get hasProtectedValues =>
      baseline?.capabilities.canViewValues == true ||
      progress?.capabilities.canViewValues == true;

  YorksAccountsProjectState copyWith({
    YorksAccountsViewStatus? status,
    YorksAccountsBaselineProjection? baseline,
    YorksAccountsProgressProjection? progress,
    YorksAccountsProgressRevisionProjection? revisionHistory,
    YorksV1DomainException? error,
    bool? isMutating,
    bool clearBaseline = false,
    bool clearProgress = false,
    bool clearRevisionHistory = false,
    bool clearError = false,
  }) {
    return YorksAccountsProjectState(
      status: status ?? this.status,
      baseline: clearBaseline ? null : baseline ?? this.baseline,
      progress: clearProgress ? null : progress ?? this.progress,
      revisionHistory: clearRevisionHistory
          ? null
          : revisionHistory ?? this.revisionHistory,
      error: clearError ? null : error ?? this.error,
      isMutating: isMutating ?? this.isMutating,
    );
  }

  YorksAccountsProjectState withoutProtectedValues({
    YorksAccountsViewStatus? status,
    YorksV1DomainException? error,
  }) {
    return YorksAccountsProjectState(
      status: status ?? this.status,
      baseline: baseline?.withoutProtectedValues(),
      progress: progress?.withoutProtectedValues(),
      revisionHistory: null,
      error: error,
      isMutating: false,
    );
  }
}

/// R39 Accounts application boundary for one project.
///
/// Critical writes keep their key lease until a confirmed RPC response. A
/// network failure therefore enters [YorksAccountsViewStatus.uncertain] and a
/// retry of the same typed intent uses the same key/payload, allowing the
/// server's idempotency record to reconcile a lost response safely.
final class YorksAccountsProjectController
    extends StateNotifier<YorksAccountsProjectState> {
  YorksAccountsProjectController({
    required String projectId,
    required YorksAccountsRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
  }) : _projectId = projectId.trim(),
       _repository = repository,
       _commandKeys = commandKeys,
       super(const YorksAccountsProjectState());

  final String _projectId;
  final YorksAccountsRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;

  Future<bool> load({
    String? buildingScopeId,
    String? stageKey,
    String? actionOwner,
    bool? hasEvidence,
  }) async {
    state = state.copyWith(
      status: YorksAccountsViewStatus.loading,
      clearError: true,
    );
    try {
      var baseline = await _repository.getBaseline(_projectId);
      var progress = await _repository.listProgress(
        _projectId,
        buildingScopeId: buildingScopeId,
        stageKey: stageKey,
        actionOwner: actionOwner,
        hasEvidence: hasEvidence,
      );
      final baselineRevisionId = baseline.baseline?.revisionId;
      if (baselineRevisionId != progress.baselineRevisionId) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      if (!baseline.capabilities.canViewValues ||
          !progress.capabilities.canViewValues) {
        baseline = baseline.withoutProtectedValues();
        progress = progress.withoutProtectedValues();
      }
      state = YorksAccountsProjectState(
        status: YorksAccountsViewStatus.success,
        baseline: baseline,
        progress: progress,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, commandMayHaveCommitted: false);
      return false;
    } catch (error) {
      _setFailure(
        YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        ),
        commandMayHaveCommitted: false,
      );
      return false;
    }
  }

  Future<bool> loadRevisionHistory(
    String progressEntryId, {
    int? beforeRevisionNumber,
    int limit = 50,
  }) async {
    state = state.copyWith(
      status: YorksAccountsViewStatus.loading,
      clearError: true,
    );
    try {
      final history = await _repository.listProgressRevisions(
        _projectId,
        progressEntryId,
        beforeRevisionNumber: beforeRevisionNumber,
        limit: limit,
      );
      state = state.copyWith(
        status: YorksAccountsViewStatus.success,
        revisionHistory: history,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, commandMayHaveCommitted: false);
      return false;
    } catch (error) {
      _setFailure(
        YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        ),
        commandMayHaveCommitted: false,
      );
      return false;
    }
  }

  Future<YorksAccountsCommandResult?> initializeBaseline(
    YorksAccountsBaselineInput input,
  ) {
    if (!_matchesProject(input.projectId)) {
      return _rejectProjectMismatch();
    }
    return _runCommand(
      operation: 'initialize_project_commercial_baseline',
      entityId: input.projectId,
      payload: input.idempotencyPayload(),
      invoke: (key) =>
          _repository.initializeBaseline(input, idempotencyKey: key),
    );
  }

  Future<YorksAccountsCommandResult?> reviseBaseline(
    YorksAccountsBaselineInput input,
  ) {
    if (!_matchesProject(input.projectId)) {
      return _rejectProjectMismatch();
    }
    return _runCommand(
      operation: 'revise_project_commercial_baseline',
      entityId: input.projectId,
      payload: input.idempotencyPayload(),
      invoke: (key) => _repository.reviseBaseline(input, idempotencyKey: key),
    );
  }

  Future<YorksAccountsCommandResult?> suggestProgress(
    YorksAccountsProgressInput input,
  ) {
    if (!_matchesProject(input.projectId)) {
      return _rejectProjectMismatch();
    }
    return _runCommand(
      operation: 'suggest_billing_progress',
      entityId: input.progressEntryId,
      payload: input.idempotencyPayload(),
      invoke: (key) => _repository.suggestProgress(input, idempotencyKey: key),
    );
  }

  Future<YorksAccountsCommandResult?> confirmProgress(
    YorksAccountsProgressInput input,
  ) {
    if (!_matchesProject(input.projectId)) {
      return _rejectProjectMismatch();
    }
    return _runCommand(
      operation: 'confirm_billing_progress',
      entityId: input.progressEntryId,
      payload: input.idempotencyPayload(),
      invoke: (key) => _repository.confirmProgress(input, idempotencyKey: key),
    );
  }

  Future<YorksAccountsCommandResult?> reviewProgress(
    YorksAccountsReviewInput input,
  ) {
    if (!_matchesProject(input.projectId)) {
      return _rejectProjectMismatch();
    }
    return _runCommand(
      operation: 'review_commercial_progress',
      entityId: input.progressEntryId,
      payload: input.idempotencyPayload(),
      invoke: (key) => _repository.reviewProgress(input, idempotencyKey: key),
    );
  }

  /// Explicitly removes every cached monetary value when a capability/session
  /// refresh revokes protected access. Provider recreation on role changes also
  /// starts from an empty state, so commercial data cannot cross identities.
  void purgeProtectedValues() {
    state = state.withoutProtectedValues();
  }

  bool _matchesProject(String inputProjectId) =>
      _projectId.isNotEmpty && inputProjectId.trim() == _projectId;

  Future<YorksAccountsCommandResult?> _rejectProjectMismatch() {
    _setFailure(
      const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput),
      commandMayHaveCommitted: false,
    );
    return Future<YorksAccountsCommandResult?>.value();
  }

  Future<YorksAccountsCommandResult?> _runCommand({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required Future<YorksAccountsCommandResult> Function(String key) invoke,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: entityId,
        payload: payload,
      );
      final result = await invoke(key);
      await _commandKeys.confirm(
        operation: operation,
        entityId: entityId,
        idempotencyKey: key,
      );
      state = state.copyWith(isMutating: false, clearError: true);
      await load();
      return result;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, commandMayHaveCommitted: true);
      return null;
    } catch (error) {
      _setFailure(
        YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        ),
        commandMayHaveCommitted: true,
      );
      return null;
    }
  }

  void _setFailure(
    YorksV1DomainException error, {
    required bool commandMayHaveCommitted,
  }) {
    final status = switch (error.code) {
      YorksV1DomainErrorCode.unauthorized => YorksAccountsViewStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksAccountsViewStatus.sessionExpired,
      YorksV1DomainErrorCode.offline => YorksAccountsViewStatus.offline,
      YorksV1DomainErrorCode.conflict => YorksAccountsViewStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksAccountsViewStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when commandMayHaveCommitted =>
        YorksAccountsViewStatus.uncertain,
      _ => YorksAccountsViewStatus.failure,
    };
    if (status == YorksAccountsViewStatus.forbidden ||
        status == YorksAccountsViewStatus.sessionExpired ||
        status == YorksAccountsViewStatus.unavailable) {
      // These failures may mean the entire project/view scope was revoked, so
      // even non-money project and evidence metadata must leave memory.
      state = YorksAccountsProjectState(status: status, error: error);
      return;
    }
    state = state.copyWith(status: status, error: error, isMutating: false);
  }
}
