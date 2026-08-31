import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_administration_models.dart';
import '../domain/workforce_configuration_models.dart';
import '../domain/workforce_foundation_models.dart';

enum YorksWorkforceAdministrationStatus {
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

final class YorksWorkforceAdministrationState {
  const YorksWorkforceAdministrationState({
    this.status = YorksWorkforceAdministrationStatus.idle,
    this.foundation,
    this.configuration,
    this.options,
    this.error,
    this.lastOperation,
    this.isOnline = true,
  });

  final YorksWorkforceAdministrationStatus status;
  final YorksWorkforceFoundationProjection? foundation;
  final YorksWorkforceConfigurationProjection? configuration;
  final YorksWorkforceAdministrationOptions? options;
  final YorksV1DomainException? error;
  final String? lastOperation;
  final bool isOnline;

  bool get hasConfirmedData => foundation != null && options != null;

  YorksWorkforceAdministrationState copyWith({
    YorksWorkforceAdministrationStatus? status,
    YorksWorkforceFoundationProjection? foundation,
    YorksWorkforceConfigurationProjection? configuration,
    YorksWorkforceAdministrationOptions? options,
    YorksV1DomainException? error,
    String? lastOperation,
    bool? isOnline,
    bool clearProtectedData = false,
    bool clearConfiguration = false,
    bool clearError = false,
    bool clearLastOperation = false,
  }) => YorksWorkforceAdministrationState(
    status: status ?? this.status,
    foundation: clearProtectedData ? null : foundation ?? this.foundation,
    configuration: clearProtectedData || clearConfiguration
        ? null
        : configuration ?? this.configuration,
    options: clearProtectedData ? null : options ?? this.options,
    error: clearError ? null : error ?? this.error,
    lastOperation: clearLastOperation
        ? null
        : lastOperation ?? this.lastOperation,
    isOnline: isOnline ?? this.isOnline,
  );
}

final class YorksWorkforceAdministrationController
    extends StateNotifier<YorksWorkforceAdministrationState> {
  YorksWorkforceAdministrationController({
    required YorksWorkforceRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
    required ConnectivityService connectivity,
    required bool canManageWorkers,
    required bool canManageTeams,
    required bool canManageConfiguration,
  }) : _repository = repository,
       _commandKeys = commandKeys,
       _connectivity = connectivity,
       _canManageWorkers = canManageWorkers,
       _canManageTeams = canManageTeams,
       _canManageConfiguration = canManageConfiguration,
       super(
         YorksWorkforceAdministrationState(isOnline: connectivity.isOnline),
       ) {
    _subscription = connectivity.onChange.listen(_onConnectivityChanged);
  }

  final YorksWorkforceRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;
  final ConnectivityService _connectivity;
  final bool _canManageWorkers;
  final bool _canManageTeams;
  final bool _canManageConfiguration;
  StreamSubscription<bool>? _subscription;
  int _generation = 0;

  bool get canManageWorkers => _canManageWorkers;
  bool get canManageTeams => _canManageTeams;
  bool get canManageConfiguration => _canManageConfiguration;
  bool get hasAnyAuthority =>
      _canManageWorkers || _canManageTeams || _canManageConfiguration;

  Future<bool> load({String? query}) async {
    if (!hasAnyAuthority) {
      purgeProtectedState();
      return false;
    }
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceAdministrationStatus.offline,
        isOnline: false,
      );
      return false;
    }
    final generation = ++_generation;
    state = state.copyWith(
      status: YorksWorkforceAdministrationStatus.loading,
      clearError: true,
      clearLastOperation: true,
      isOnline: true,
    );
    try {
      final foundationFuture = _repository.getFoundation(
        query: query,
        limit: 100,
      );
      final optionsFuture = _repository.getAdministrationOptions();
      final configurationFuture = _canManageConfiguration
          ? _repository.getConfiguration()
          : Future<YorksWorkforceConfigurationProjection?>.value();
      final results = await Future.wait<Object?>([
        foundationFuture,
        optionsFuture,
        configurationFuture,
      ]);
      if (generation != _generation) return false;
      state = YorksWorkforceAdministrationState(
        status: YorksWorkforceAdministrationStatus.ready,
        foundation: results[0] as YorksWorkforceFoundationProjection,
        options: results[1] as YorksWorkforceAdministrationOptions,
        configuration: results[2] as YorksWorkforceConfigurationProjection?,
        isOnline: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation != _generation) return false;
      _setFailure(error, commandMayHaveCommitted: false);
      return false;
    } catch (error) {
      if (generation != _generation) return false;
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

  Future<bool> saveWorker(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_worker',
    entityId: _entityId(payload, 'worker_id', 'worker_number'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageWorkers,
    invoke: (key) => _repository.saveWorker(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> saveTeam(Map<String, Object?> payload, {int? expectedVersion}) =>
      _runCommand(
        operation: 'save_workforce_team',
        entityId: _entityId(payload, 'team_id', 'team_code'),
        payload: payload,
        expectedVersion: expectedVersion,
        allowed: _canManageTeams,
        invoke: (key) => _repository.saveTeam(
          payload,
          expectedVersion: expectedVersion,
          idempotencyKey: key,
        ),
      );

  Future<bool> saveWorkerAssignment(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_worker_assignment',
    entityId: _entityId(payload, 'assignment_id', 'worker_id'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageWorkers || _canManageTeams,
    invoke: (key) => _repository.saveWorkerAssignment(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> transferWorkerAssignment(
    Map<String, Object?> payload, {
    String? expectedCurrentAssignmentId,
    int? expectedCurrentVersion,
  }) => _runCommand(
    operation: 'transfer_workforce_worker_assignment',
    entityId: _entityId(payload, 'worker_id', 'assignment_kind'),
    payload: {
      ...payload,
      'expected_current_assignment_id': expectedCurrentAssignmentId,
    },
    expectedVersion: expectedCurrentVersion,
    allowed: _canManageWorkers || _canManageTeams,
    invoke: (key) => _repository.transferWorkerAssignment(
      payload,
      expectedCurrentAssignmentId: expectedCurrentAssignmentId,
      expectedCurrentVersion: expectedCurrentVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> saveTrade(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_trade',
    entityId: _entityId(payload, 'trade_id', 'trade_code'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageConfiguration,
    invoke: (key) => _repository.saveTrade(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> saveInternalLocation(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_internal_location',
    entityId: _entityId(payload, 'internal_location_id', 'location_code'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageConfiguration,
    invoke: (key) => _repository.saveInternalLocation(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> saveCalendar(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_calendar',
    entityId: _entityId(payload, 'calendar_id', 'calendar_code'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageConfiguration,
    invoke: (key) => _repository.saveCalendar(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> saveShift(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_shift_template',
    entityId: _entityId(payload, 'shift_template_id', 'shift_code'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageConfiguration,
    invoke: (key) => _repository.saveShiftTemplate(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> saveTeamSchedule(
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => _runCommand(
    operation: 'save_workforce_team_schedule',
    entityId: _entityId(payload, 'team_schedule_link_id', 'team_id'),
    payload: payload,
    expectedVersion: expectedVersion,
    allowed: _canManageConfiguration,
    invoke: (key) => _repository.saveTeamSchedule(
      payload,
      expectedVersion: expectedVersion,
      idempotencyKey: key,
    ),
  );

  Future<bool> _runCommand({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required int? expectedVersion,
    required bool allowed,
    required Future<YorksWorkforceCommandResult> Function(String key) invoke,
  }) async {
    if (!allowed) {
      purgeProtectedState();
      return false;
    }
    state = state.copyWith(
      status: YorksWorkforceAdministrationStatus.saving,
      clearError: true,
      lastOperation: operation,
    );
    final commandPayload = <String, Object?>{
      ...payload,
      'expected_version': expectedVersion,
    };
    try {
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: entityId,
        payload: commandPayload,
      );
      await invoke(key);
      await _commandKeys.confirm(
        operation: operation,
        entityId: entityId,
        idempotencyKey: key,
      );
      final loaded = await load();
      if (loaded) {
        state = state.copyWith(
          status: YorksWorkforceAdministrationStatus.saved,
          lastOperation: operation,
        );
      }
      return loaded;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, commandMayHaveCommitted: true);
      return false;
    } catch (error) {
      _setFailure(
        YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        ),
        commandMayHaveCommitted: true,
      );
      return false;
    }
  }

  void purgeProtectedState({bool unavailable = false}) {
    _generation += 1;
    state = YorksWorkforceAdministrationState(
      status: unavailable
          ? YorksWorkforceAdministrationStatus.unavailable
          : YorksWorkforceAdministrationStatus.forbidden,
      isOnline: _connectivity.isOnline,
    );
  }

  void _setFailure(
    YorksV1DomainException error, {
    required bool commandMayHaveCommitted,
  }) {
    final status = switch (error.code) {
      YorksV1DomainErrorCode.unauthorized =>
        YorksWorkforceAdministrationStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksWorkforceAdministrationStatus.sessionExpired,
      YorksV1DomainErrorCode.offline =>
        YorksWorkforceAdministrationStatus.offline,
      YorksV1DomainErrorCode.conflict =>
        YorksWorkforceAdministrationStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksWorkforceAdministrationStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when commandMayHaveCommitted =>
        YorksWorkforceAdministrationStatus.uncertain,
      _ => YorksWorkforceAdministrationStatus.failure,
    };
    final clearProtected =
        status == YorksWorkforceAdministrationStatus.forbidden ||
        status == YorksWorkforceAdministrationStatus.sessionExpired ||
        status == YorksWorkforceAdministrationStatus.unavailable;
    state = state.copyWith(
      status: status,
      error: error,
      clearProtectedData: clearProtected,
      isOnline: _connectivity.isOnline,
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    state = state.copyWith(
      status:
          online && state.status == YorksWorkforceAdministrationStatus.offline
          ? YorksWorkforceAdministrationStatus.idle
          : !online
          ? YorksWorkforceAdministrationStatus.offline
          : state.status,
      isOnline: online,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

String _entityId(
  Map<String, Object?> payload,
  String idKey,
  String fallbackKey,
) {
  final id = payload[idKey]?.toString().trim();
  if (id != null && id.isNotEmpty) return id;
  final fallback = payload[fallbackKey]?.toString().trim();
  return fallback == null || fallback.isEmpty ? 'new' : 'new:$fallback';
}
