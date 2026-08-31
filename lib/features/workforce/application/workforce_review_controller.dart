import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_daily_roster_models.dart';
import '../domain/workforce_review_models.dart';

enum YorksWorkforceReviewStatus {
  idle,
  loading,
  ready,
  saving,
  saved,
  offline,
  conflict,
  uncertain,
  forbidden,
  sessionExpired,
  unavailable,
  failure,
}

final class YorksWorkforceReviewState {
  const YorksWorkforceReviewState({
    this.status = YorksWorkforceReviewStatus.idle,
    this.lifecycle,
    this.queue,
    this.error,
    this.isOnline = true,
  });

  final YorksWorkforceReviewStatus status;
  final YorksWorkforceReviewLifecycle? lifecycle;
  final YorksWorkforceReviewQueue? queue;
  final YorksV1DomainException? error;
  final bool isOnline;

  bool get isBusy =>
      status == YorksWorkforceReviewStatus.loading ||
      status == YorksWorkforceReviewStatus.saving;

  YorksWorkforceReviewState copyWith({
    YorksWorkforceReviewStatus? status,
    YorksWorkforceReviewLifecycle? lifecycle,
    bool clearLifecycle = false,
    YorksWorkforceReviewQueue? queue,
    bool clearQueue = false,
    YorksV1DomainException? error,
    bool clearError = false,
    bool? isOnline,
  }) => YorksWorkforceReviewState(
    status: status ?? this.status,
    lifecycle: clearLifecycle ? null : lifecycle ?? this.lifecycle,
    queue: clearQueue ? null : queue ?? this.queue,
    error: clearError ? null : error ?? this.error,
    isOnline: isOnline ?? this.isOnline,
  );
}

final class YorksWorkforceReviewController
    extends StateNotifier<YorksWorkforceReviewState> {
  YorksWorkforceReviewController({
    required YorksWorkforceReviewRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
    required ConnectivityService connectivity,
  }) : _repository = repository,
       _commandKeys = commandKeys,
       _connectivity = connectivity,
       super(YorksWorkforceReviewState(isOnline: connectivity.isOnline)) {
    _connectivitySubscription = connectivity.onChange.listen(
      _onConnectivityChanged,
    );
  }

  final YorksWorkforceReviewRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connectivitySubscription;
  int _generation = 0;

  Future<bool> load({String? periodId}) async {
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceReviewStatus.offline,
        isOnline: false,
      );
      return false;
    }
    final generation = ++_generation;
    state = state.copyWith(
      status: YorksWorkforceReviewStatus.loading,
      clearError: true,
      isOnline: true,
    );
    try {
      final queue = await _repository.listMonthlyApprovalQueue();
      final normalizedPeriod = periodId?.trim();
      final lifecycle = normalizedPeriod == null || normalizedPeriod.isEmpty
          ? null
          : await _repository.getMonthlyLifecycle(normalizedPeriod);
      if (generation != _generation) return false;
      state = state.copyWith(
        status: YorksWorkforceReviewStatus.ready,
        queue: queue,
        lifecycle: lifecycle,
        clearLifecycle: lifecycle == null,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  Future<YorksWorkforceReviewLifecycle?> submit({
    required Iterable<String> warningIssueIds,
    required String reason,
  }) => _run(
    operation: 'submit_workforce_monthly_period',
    payload: {
      'warning_issue_ids': warningIssueIds.toList(growable: false),
      'reason': reason,
    },
    invoke: (lifecycle, key) => _repository.submitMonthlyPeriod(
      periodId: lifecycle.periodId,
      warningIssueIds: warningIssueIds,
      reason: reason,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> returnForCorrection({
    required Iterable<YorksWorkforceAffectedEntry> affectedEntries,
    required String reason,
    String? attachmentReference,
  }) => _run(
    operation: 'return_workforce_monthly_period',
    payload: {
      'affected_entries': affectedEntries
          .map((entry) => entry.toRpcJson())
          .toList(growable: false),
      'reason': reason,
      'attachment_reference': attachmentReference,
    },
    invoke: (lifecycle, key) => _repository.returnMonthlyPeriod(
      periodId: lifecycle.periodId,
      affectedEntries: affectedEntries,
      reason: reason,
      attachmentReference: attachmentReference,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> correctDuringReview({
    required String workDate,
    required YorksWorkforceDailyRosterSaveRow row,
    required String reason,
  }) => _run(
    operation: 'correct_workforce_monthly_entry_during_review',
    payload: {'work_date': workDate, 'row': row.toRpcJson(), 'reason': reason},
    invoke: (lifecycle, key) => _repository.correctMonthlyEntryDuringReview(
      periodId: lifecycle.periodId,
      workDate: workDate,
      row: row,
      reason: reason,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> verify(String reason) => _run(
    operation: 'verify_workforce_monthly_period',
    payload: {'reason': reason},
    invoke: (lifecycle, key) => _repository.verifyMonthlyPeriod(
      periodId: lifecycle.periodId,
      reason: reason,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> approveAndLock(String reason) => _run(
    operation: 'approve_lock_workforce_monthly_period',
    payload: {'reason': reason},
    invoke: (lifecycle, key) => _repository.approveAndLockMonthlyPeriod(
      periodId: lifecycle.periodId,
      reason: reason,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> requestReopen({
    required Iterable<YorksWorkforceAffectedEntry> affectedEntries,
    required String reason,
    String? attachmentReference,
  }) => _run(
    operation: 'request_workforce_monthly_reopen',
    payload: {
      'affected_entries': affectedEntries
          .map((entry) => entry.toRpcJson())
          .toList(growable: false),
      'reason': reason,
      'attachment_reference': attachmentReference,
    },
    invoke: (lifecycle, key) => _repository.requestMonthlyReopen(
      periodId: lifecycle.periodId,
      affectedEntries: affectedEntries,
      reason: reason,
      attachmentReference: attachmentReference,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> authorizeReopen({
    required String requestId,
    required String reason,
  }) => _run(
    operation: 'authorize_workforce_monthly_reopen',
    payload: {'request_id': requestId, 'reason': reason},
    invoke: (lifecycle, key) => _repository.authorizeMonthlyReopen(
      periodId: lifecycle.periodId,
      requestId: requestId,
      reason: reason,
      expectedVersion: lifecycle.recordVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceReviewLifecycle?> _run({
    required String operation,
    required Map<String, Object?> payload,
    required Future<YorksWorkforceReviewLifecycle> Function(
      YorksWorkforceReviewLifecycle lifecycle,
      String key,
    )
    invoke,
  }) async {
    final lifecycle = state.lifecycle;
    if (lifecycle == null || state.isBusy || !_connectivity.isOnline) {
      return null;
    }
    state = state.copyWith(
      status: YorksWorkforceReviewStatus.saving,
      clearError: true,
    );
    try {
      final commandPayload = {
        'period_id': lifecycle.periodId,
        'expected_version': lifecycle.recordVersion,
        ...payload,
      };
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: lifecycle.periodId,
        payload: commandPayload,
      );
      final result = await invoke(lifecycle, key);
      await _commandKeys.confirm(
        operation: operation,
        entityId: lifecycle.periodId,
        idempotencyKey: key,
      );
      state = state.copyWith(
        status: YorksWorkforceReviewStatus.saved,
        lifecycle: result,
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
    state = YorksWorkforceReviewState(
      status: unavailable
          ? YorksWorkforceReviewStatus.unavailable
          : YorksWorkforceReviewStatus.forbidden,
      isOnline: _connectivity.isOnline,
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    state = state.copyWith(
      status: online && state.status == YorksWorkforceReviewStatus.offline
          ? YorksWorkforceReviewStatus.ready
          : online
          ? state.status
          : YorksWorkforceReviewStatus.offline,
      isOnline: online,
    );
  }

  void _setFailure(YorksV1DomainException error, {required bool command}) {
    final next = switch (error.code) {
      YorksV1DomainErrorCode.unauthorized =>
        YorksWorkforceReviewStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksWorkforceReviewStatus.sessionExpired,
      YorksV1DomainErrorCode.offline => YorksWorkforceReviewStatus.offline,
      YorksV1DomainErrorCode.conflict => YorksWorkforceReviewStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksWorkforceReviewStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when command =>
        YorksWorkforceReviewStatus.uncertain,
      _ => YorksWorkforceReviewStatus.failure,
    };
    if (next == YorksWorkforceReviewStatus.forbidden ||
        next == YorksWorkforceReviewStatus.sessionExpired ||
        next == YorksWorkforceReviewStatus.unavailable) {
      _generation += 1;
      state = YorksWorkforceReviewState(
        status: next,
        error: error,
        isOnline: _connectivity.isOnline,
      );
      return;
    }
    state = state.copyWith(status: next, error: error);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
