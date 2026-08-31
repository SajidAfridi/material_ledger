import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_timesheet_models.dart';

enum YorksWorkforceTimesheetStatus {
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

final class YorksWorkforceTimesheetState {
  const YorksWorkforceTimesheetState({
    this.status = YorksWorkforceTimesheetStatus.idle,
    this.projection,
    this.currentDay,
    this.error,
    this.isMutating = false,
  });

  final YorksWorkforceTimesheetStatus status;
  final YorksWorkforceTimesheetProjection? projection;
  final YorksWorkforceTimesheetDay? currentDay;
  final YorksV1DomainException? error;
  final bool isMutating;

  YorksWorkforceTimesheetState copyWith({
    YorksWorkforceTimesheetStatus? status,
    YorksWorkforceTimesheetProjection? projection,
    YorksWorkforceTimesheetDay? currentDay,
    YorksV1DomainException? error,
    bool? isMutating,
    bool clearProjection = false,
    bool clearCurrentDay = false,
    bool clearError = false,
  }) => YorksWorkforceTimesheetState(
    status: status ?? this.status,
    projection: clearProjection ? null : projection ?? this.projection,
    currentDay: clearCurrentDay ? null : currentDay ?? this.currentDay,
    error: clearError ? null : error ?? this.error,
    isMutating: isMutating ?? this.isMutating,
  );
}

/// Route-less T04 application boundary.
///
/// Command leases are confirmed only after a strict authoritative response.
/// A transport failure therefore retains the same key and enters [uncertain],
/// allowing an identical retry to reconcile a server commit whose response was
/// lost without duplicating a revision or audit effect.
final class YorksWorkforceTimesheetController
    extends StateNotifier<YorksWorkforceTimesheetState> {
  YorksWorkforceTimesheetController({
    required YorksWorkforceRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
  }) : _repository = repository,
       _commandKeys = commandKeys,
       super(const YorksWorkforceTimesheetState());

  final YorksWorkforceRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;

  Future<bool> load({required String workDate, String? workerId}) async {
    state = state.copyWith(
      status: YorksWorkforceTimesheetStatus.loading,
      clearError: true,
    );
    try {
      final projection = await _repository.getTimesheetAllocations(
        workDate: workDate,
        workerId: workerId,
      );
      state = YorksWorkforceTimesheetState(
        status: YorksWorkforceTimesheetStatus.success,
        projection: projection,
        currentDay: projection.days.length == 1 ? projection.days.single : null,
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

  Future<YorksWorkforceTimesheetCommandResult?> save(
    YorksWorkforceTimesheetAllocationInput input, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_timesheet_allocations',
    entityId: input.attendanceDayId,
    payload: {...input.toRpcJson(), 'expected_version': expectedVersion},
    invoke: (key) => _repository.saveTimesheetAllocations(
      input,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceTimesheetCommandResult?> withdraw({
    required String attendanceDayId,
    required String reason,
    required int expectedVersion,
  }) => _runCommand(
    operation: 'withdraw_workforce_timesheet_allocations',
    entityId: attendanceDayId,
    payload: {
      'attendance_day_id': attendanceDayId.trim(),
      'reason': reason.trim(),
      'expected_version': expectedVersion,
    },
    invoke: (key) => _repository.withdrawTimesheetAllocations(
      attendanceDayId: attendanceDayId,
      reason: reason,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<YorksWorkforceTimesheetCommandResult?> _runCommand({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required Future<YorksWorkforceTimesheetCommandResult> Function(String key)
    invoke,
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
      state = state.copyWith(
        status: YorksWorkforceTimesheetStatus.success,
        currentDay: result.day,
        isMutating: false,
        clearError: true,
      );
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
      YorksV1DomainErrorCode.unauthorized =>
        YorksWorkforceTimesheetStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksWorkforceTimesheetStatus.sessionExpired,
      YorksV1DomainErrorCode.offline => YorksWorkforceTimesheetStatus.offline,
      YorksV1DomainErrorCode.conflict => YorksWorkforceTimesheetStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksWorkforceTimesheetStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when commandMayHaveCommitted =>
        YorksWorkforceTimesheetStatus.uncertain,
      _ => YorksWorkforceTimesheetStatus.failure,
    };
    if (status == YorksWorkforceTimesheetStatus.forbidden ||
        status == YorksWorkforceTimesheetStatus.sessionExpired ||
        status == YorksWorkforceTimesheetStatus.unavailable) {
      state = YorksWorkforceTimesheetState(status: status, error: error);
      return;
    }
    state = state.copyWith(status: status, error: error, isMutating: false);
  }
}
