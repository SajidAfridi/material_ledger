import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_monthly_period_models.dart';

enum YorksWorkforceMonthlyStatus {
  idle,
  loading,
  ready,
  validating,
  validated,
  offline,
  conflict,
  uncertain,
  forbidden,
  sessionExpired,
  unavailable,
  failure,
}

final class YorksWorkforceMonthlyState {
  const YorksWorkforceMonthlyState({
    this.status = YorksWorkforceMonthlyStatus.idle,
    this.periodMonth = '',
    this.selectedTeamId,
    this.teamProjection,
    this.filters,
    this.projection,
    this.issueProjection,
    this.workerDetail,
    this.selectedDate,
    this.error,
    this.isOnline = true,
  });

  final YorksWorkforceMonthlyStatus status;
  final String periodMonth;
  final String? selectedTeamId;
  final YorksWorkforceMonthlyTeamProjection? teamProjection;
  final YorksWorkforceMonthlyFilters? filters;
  final YorksWorkforceMonthlyProjection? projection;
  final YorksWorkforceMonthlyIssueProjection? issueProjection;
  final YorksWorkforceMonthlyWorkerDetail? workerDetail;
  final String? selectedDate;
  final YorksV1DomainException? error;
  final bool isOnline;

  bool get isBusy =>
      status == YorksWorkforceMonthlyStatus.loading ||
      status == YorksWorkforceMonthlyStatus.validating;
  bool get canLoadMore =>
      projection != null && projection!.workers.length < projection!.totalCount;
  bool get canLoadMoreIssues =>
      issueProjection != null &&
      issueProjection!.issues.length < issueProjection!.totalCount;
  bool get canValidate =>
      isOnline && projection?.capabilities.canValidate == true && !isBusy;

  YorksWorkforceMonthlyState copyWith({
    YorksWorkforceMonthlyStatus? status,
    String? periodMonth,
    String? selectedTeamId,
    bool clearSelectedTeam = false,
    YorksWorkforceMonthlyTeamProjection? teamProjection,
    bool clearTeamProjection = false,
    YorksWorkforceMonthlyFilters? filters,
    bool clearFilters = false,
    YorksWorkforceMonthlyProjection? projection,
    bool clearProjection = false,
    YorksWorkforceMonthlyIssueProjection? issueProjection,
    bool clearIssueProjection = false,
    YorksWorkforceMonthlyWorkerDetail? workerDetail,
    bool clearWorkerDetail = false,
    String? selectedDate,
    bool clearSelectedDate = false,
    YorksV1DomainException? error,
    bool clearError = false,
    bool? isOnline,
  }) => YorksWorkforceMonthlyState(
    status: status ?? this.status,
    periodMonth: periodMonth ?? this.periodMonth,
    selectedTeamId: clearSelectedTeam
        ? null
        : selectedTeamId ?? this.selectedTeamId,
    teamProjection: clearTeamProjection
        ? null
        : teamProjection ?? this.teamProjection,
    filters: clearFilters ? null : filters ?? this.filters,
    projection: clearProjection ? null : projection ?? this.projection,
    issueProjection: clearIssueProjection
        ? null
        : issueProjection ?? this.issueProjection,
    workerDetail: clearWorkerDetail ? null : workerDetail ?? this.workerDetail,
    selectedDate: clearSelectedDate ? null : selectedDate ?? this.selectedDate,
    error: clearError ? null : error ?? this.error,
    isOnline: isOnline ?? this.isOnline,
  );
}

final class YorksWorkforceMonthlyController
    extends StateNotifier<YorksWorkforceMonthlyState> {
  YorksWorkforceMonthlyController({
    required YorksWorkforceRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
    required ConnectivityService connectivity,
    DateTime Function()? clock,
  }) : _repository = repository,
       _commandKeys = commandKeys,
       _connectivity = connectivity,
       _clock = clock ?? DateTime.now,
       super(
         YorksWorkforceMonthlyState(
           periodMonth: _month((clock ?? DateTime.now)()),
           isOnline: connectivity.isOnline,
         ),
       ) {
    _connectivitySubscription = connectivity.onChange.listen(
      _onConnectivityChanged,
    );
  }

  static const operation = 'validate_workforce_monthly_period';

  final YorksWorkforceRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;
  final ConnectivityService _connectivity;
  final DateTime Function() _clock;
  StreamSubscription<bool>? _connectivitySubscription;
  int _generation = 0;

  Future<bool> initialize() => loadTeams(periodMonth: state.periodMonth);

  Future<bool> loadTeams({
    required String periodMonth,
    String query = '',
  }) async {
    final generation = ++_generation;
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.offline,
        periodMonth: periodMonth,
        isOnline: false,
      );
      return false;
    }
    state = state.copyWith(
      status: YorksWorkforceMonthlyStatus.loading,
      periodMonth: periodMonth,
      isOnline: true,
      clearError: true,
      clearIssueProjection: true,
      clearWorkerDetail: true,
      clearSelectedDate: true,
    );
    try {
      final teams = await _repository.listMonthlyTeams(
        YorksWorkforceMonthlyTeamFilters(
          periodMonth: periodMonth,
          query: query,
          limit: yorksWorkforceMonthlyMaxPageSize,
        ),
      );
      if (generation != _generation) return false;
      final priorTeam = state.selectedTeamId;
      final selected = teams.teams.any((item) => item.id == priorTeam)
          ? priorTeam
          : teams.teams.firstOrNull?.id;
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.ready,
        teamProjection: teams,
        selectedTeamId: selected,
        clearSelectedTeam: selected == null,
        clearProjection: true,
        clearFilters: true,
      );
      if (selected == null) return true;
      return await _loadPeriod(
        generation: generation,
        filters: YorksWorkforceMonthlyFilters(
          teamId: selected,
          periodMonth: periodMonth,
        ),
      );
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    } catch (error) {
      if (generation == _generation) {
        _setFailure(
          YorksV1DomainException(
            YorksV1DomainErrorCode.backendUnavailable,
            cause: error,
          ),
          command: false,
        );
      }
      return false;
    }
  }

  Future<bool> changeMonth(String periodMonth) =>
      loadTeams(periodMonth: periodMonth);

  Future<bool> changeTeam(String teamId) {
    final normalized = teamId.trim();
    final teams = state.teamProjection?.teams ?? const [];
    if (!teams.any((item) => item.id == normalized)) return Future.value(false);
    return loadPeriod(
      YorksWorkforceMonthlyFilters(
        teamId: normalized,
        periodMonth: state.periodMonth,
      ),
    );
  }

  Future<bool> changeFilters(YorksWorkforceMonthlyFilters filters) =>
      loadPeriod(filters.copyWith(workerOffset: 0));

  Future<bool> loadPeriod(YorksWorkforceMonthlyFilters filters) async {
    final generation = ++_generation;
    return _loadPeriod(generation: generation, filters: filters);
  }

  Future<bool> _loadPeriod({
    required int generation,
    required YorksWorkforceMonthlyFilters filters,
  }) async {
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.offline,
        isOnline: false,
      );
      return false;
    }
    final sameContext =
        state.selectedTeamId == filters.teamId &&
        state.periodMonth == filters.periodMonth;
    state = state.copyWith(
      status: YorksWorkforceMonthlyStatus.loading,
      periodMonth: filters.periodMonth,
      selectedTeamId: filters.teamId,
      filters: filters,
      isOnline: true,
      clearProjection: !sameContext,
      clearIssueProjection: true,
      clearWorkerDetail: true,
      clearSelectedDate: true,
      clearError: true,
    );
    try {
      final projection = await _repository.getMonthlyPeriod(filters);
      if (generation != _generation) return false;
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.ready,
        projection: projection,
        filters: filters,
        clearIssueProjection: true,
        clearWorkerDetail: true,
        clearSelectedDate: true,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    } catch (error) {
      if (generation == _generation) {
        _setFailure(
          YorksV1DomainException(
            YorksV1DomainErrorCode.backendUnavailable,
            cause: error,
          ),
          command: false,
        );
      }
      return false;
    }
  }

  Future<bool> loadMoreWorkers() async {
    final current = state.projection;
    final filters = state.filters;
    if (current == null ||
        filters == null ||
        !state.canLoadMore ||
        state.isBusy) {
      return false;
    }
    final generation = ++_generation;
    final nextFilters = filters.copyWith(workerOffset: current.workers.length);
    try {
      final next = await _repository.getMonthlyPeriod(nextFilters);
      if (generation != _generation) return false;
      if (!_sameMonthlyAuthority(current, next)) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      final known = current.workers.map((item) => item.workerId).toSet();
      if (next.workers.any((item) => !known.add(item.workerId))) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.ready,
        projection: YorksWorkforceMonthlyProjection(
          schemaVersion: next.schemaVersion,
          authorizationMode: next.authorizationMode,
          actorAuthUserId: next.actorAuthUserId,
          serverTime: next.serverTime,
          filters: filters,
          capabilities: next.capabilities,
          period: next.period,
          summary: next.summary,
          issueCounts: next.issueCounts,
          totalCount: next.totalCount,
          workers: [...current.workers, ...next.workers],
        ),
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  Future<bool> loadIssues({
    YorksWorkforceMonthlyIssueSeverity? severity,
    String? issueCode,
    String? workerId,
  }) async {
    final period = state.projection?.period;
    if (period == null || state.isBusy || !_connectivity.isOnline) return false;
    final generation = ++_generation;
    final filters = YorksWorkforceMonthlyIssueFilters(
      periodId: period.id,
      validationRunId: period.currentValidationRunId,
      severity: severity,
      issueCode: issueCode,
      workerId: workerId,
    );
    try {
      final projection = await _repository.listMonthlyIssues(filters);
      if (generation != _generation) return false;
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.ready,
        issueProjection: projection,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  Future<bool> loadMoreIssues() async {
    final current = state.issueProjection;
    if (current == null || !state.canLoadMoreIssues || state.isBusy) {
      return false;
    }
    final generation = ++_generation;
    final filters = current.filters.copyWith(offset: current.issues.length);
    try {
      final next = await _repository.listMonthlyIssues(filters);
      if (generation != _generation) return false;
      if (next.filters.periodId != current.filters.periodId ||
          next.filters.validationRunId != current.filters.validationRunId ||
          next.totalCount != current.totalCount) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      final known = current.issues.map((item) => item.id).toSet();
      if (next.issues.any((item) => !known.add(item.id))) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      state = state.copyWith(
        issueProjection: YorksWorkforceMonthlyIssueProjection(
          schemaVersion: next.schemaVersion,
          authorizationMode: next.authorizationMode,
          actorAuthUserId: next.actorAuthUserId,
          serverTime: next.serverTime,
          filters: current.filters,
          totalCount: next.totalCount,
          issues: [...current.issues, ...next.issues],
        ),
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  /// Loads the complete current issue-id set for a severity. Submission uses
  /// this instead of the visible page so warning acknowledgement is exact and
  /// cannot silently omit a later page.
  Future<List<String>?> loadAllIssueIds(
    YorksWorkforceMonthlyIssueSeverity severity,
  ) async {
    final period = state.projection?.period;
    if (period == null || state.isBusy || !_connectivity.isOnline) return null;
    final generation = ++_generation;
    final collected = <YorksWorkforceMonthlyIssue>[];
    var offset = 0;
    int? total;
    try {
      do {
        final filters = YorksWorkforceMonthlyIssueFilters(
          periodId: period.id,
          validationRunId: period.currentValidationRunId,
          severity: severity,
          limit: yorksWorkforceMonthlyMaxPageSize,
          offset: offset,
        );
        final page = await _repository.listMonthlyIssues(filters);
        if (generation != _generation) return null;
        total ??= page.totalCount;
        if (page.totalCount != total) {
          throw const YorksV1DomainException(YorksV1DomainErrorCode.conflict);
        }
        collected.addAll(page.issues);
        offset = collected.length;
      } while (offset < total);
      final unique = collected.map((issue) => issue.id).toSet();
      if (unique.length != collected.length) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      state = state.copyWith(
        issueProjection: YorksWorkforceMonthlyIssueProjection(
          schemaVersion: 1,
          authorizationMode: 'enforced_t06',
          actorAuthUserId: state.projection!.actorAuthUserId,
          serverTime: state.projection!.serverTime,
          filters: YorksWorkforceMonthlyIssueFilters(
            periodId: period.id,
            validationRunId: period.currentValidationRunId,
            severity: severity,
            limit: yorksWorkforceMonthlyMaxPageSize,
          ),
          totalCount: collected.length,
          issues: collected,
        ),
        clearError: true,
      );
      return collected.map((issue) => issue.id).toList(growable: false);
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return null;
    }
  }

  Future<bool> openWorker(String workerId) async {
    final period = state.projection?.period;
    if (period == null || state.isBusy || !_connectivity.isOnline) return false;
    if (!state.projection!.workers.any((item) => item.workerId == workerId)) {
      return false;
    }
    final generation = ++_generation;
    try {
      final detail = await _repository.getMonthlyWorkerDetail(
        periodId: period.id,
        validationRunId: period.currentValidationRunId,
        workerId: workerId,
      );
      if (generation != _generation) return false;
      state = state.copyWith(
        workerDetail: detail,
        selectedDate: detail.days.firstOrNull?.workDate,
        clearSelectedDate: detail.days.isEmpty,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  void selectDate(String workDate) {
    if (state.workerDetail?.days.any((day) => day.workDate == workDate) ==
        true) {
      state = state.copyWith(selectedDate: workDate);
    }
  }

  void closeWorker() =>
      state = state.copyWith(clearWorkerDetail: true, clearSelectedDate: true);

  Future<YorksWorkforceMonthlyValidationResult?> validatePeriod() async {
    final projection = state.projection;
    final teamId = state.selectedTeamId;
    if (teamId == null ||
        !state.canValidate ||
        !_connectivity.isOnline ||
        projection == null) {
      return null;
    }
    final expectedVersion = projection.period?.recordVersion;
    final payload = <String, Object?>{
      'team_id': teamId,
      'period_month': state.periodMonth,
      'expected_period_version': expectedVersion,
    };
    state = state.copyWith(
      status: YorksWorkforceMonthlyStatus.validating,
      clearError: true,
    );
    try {
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: '$teamId:${state.periodMonth}',
        payload: payload,
      );
      final result = await _repository.validateMonthlyPeriod(
        teamId: teamId,
        periodMonth: state.periodMonth,
        expectedPeriodVersion: expectedVersion,
        idempotencyKey: key,
      );
      await _commandKeys.confirm(
        operation: operation,
        entityId: '$teamId:${state.periodMonth}',
        idempotencyKey: key,
      );
      state = state.copyWith(
        status: YorksWorkforceMonthlyStatus.validated,
        projection: result.projection,
        filters: result.projection.filters,
        clearIssueProjection: true,
        clearWorkerDetail: true,
        clearSelectedDate: true,
        clearError: true,
      );
      return result;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, command: true);
      return null;
    } catch (error) {
      _setFailure(
        YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        ),
        command: true,
      );
      return null;
    }
  }

  void purgeProtectedState({bool unavailable = false}) {
    _generation += 1;
    state = YorksWorkforceMonthlyState(
      status: unavailable
          ? YorksWorkforceMonthlyStatus.unavailable
          : YorksWorkforceMonthlyStatus.forbidden,
      periodMonth: _month(_clock()),
      isOnline: _connectivity.isOnline,
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    state = state.copyWith(
      status: online && state.status == YorksWorkforceMonthlyStatus.offline
          ? YorksWorkforceMonthlyStatus.ready
          : online
          ? state.status
          : YorksWorkforceMonthlyStatus.offline,
      isOnline: online,
    );
  }

  void _setFailure(YorksV1DomainException error, {required bool command}) {
    final status = switch (error.code) {
      YorksV1DomainErrorCode.unauthorized =>
        YorksWorkforceMonthlyStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksWorkforceMonthlyStatus.sessionExpired,
      YorksV1DomainErrorCode.offline => YorksWorkforceMonthlyStatus.offline,
      YorksV1DomainErrorCode.conflict => YorksWorkforceMonthlyStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksWorkforceMonthlyStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when command =>
        YorksWorkforceMonthlyStatus.uncertain,
      _ => YorksWorkforceMonthlyStatus.failure,
    };
    if (status == YorksWorkforceMonthlyStatus.forbidden ||
        status == YorksWorkforceMonthlyStatus.sessionExpired ||
        status == YorksWorkforceMonthlyStatus.unavailable) {
      _generation += 1;
      state = YorksWorkforceMonthlyState(
        status: status,
        periodMonth: _month(_clock()),
        error: error,
        isOnline: _connectivity.isOnline,
      );
      return;
    }
    state = state.copyWith(
      status: status,
      error: error,
      isOnline: _connectivity.isOnline,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

bool _sameMonthlyAuthority(
  YorksWorkforceMonthlyProjection left,
  YorksWorkforceMonthlyProjection right,
) =>
    left.actorAuthUserId == right.actorAuthUserId &&
    left.filters.teamId == right.filters.teamId &&
    left.filters.periodMonth == right.filters.periodMonth &&
    left.period?.id == right.period?.id &&
    left.period?.recordVersion == right.period?.recordVersion &&
    left.period?.currentValidationRunId ==
        right.period?.currentValidationRunId &&
    left.totalCount == right.totalCount;

String _month(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-01';
