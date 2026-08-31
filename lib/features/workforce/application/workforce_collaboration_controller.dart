import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_team_chat.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_collaboration_models.dart';

enum YorksWorkforceCollaborationStatus {
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

final class YorksWorkforceCollaborationState {
  const YorksWorkforceCollaborationState({
    this.status = YorksWorkforceCollaborationStatus.idle,
    this.projection,
    this.error,
    this.isOnline = true,
  });

  final YorksWorkforceCollaborationStatus status;
  final YorksWorkforceCollaborationProjection? projection;
  final YorksV1DomainException? error;
  final bool isOnline;

  bool get isBusy =>
      status == YorksWorkforceCollaborationStatus.loading ||
      status == YorksWorkforceCollaborationStatus.saving;

  YorksWorkforceCollaborationState copyWith({
    YorksWorkforceCollaborationStatus? status,
    YorksWorkforceCollaborationProjection? projection,
    bool clearProjection = false,
    YorksV1DomainException? error,
    bool clearError = false,
    bool? isOnline,
  }) => YorksWorkforceCollaborationState(
    status: status ?? this.status,
    projection: clearProjection ? null : projection ?? this.projection,
    error: clearError ? null : error ?? this.error,
    isOnline: isOnline ?? this.isOnline,
  );
}

final class YorksWorkforceCollaborationController
    extends StateNotifier<YorksWorkforceCollaborationState> {
  YorksWorkforceCollaborationController({
    required YorksWorkforceCollaborationRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
    required ConnectivityService connectivity,
  }) : _repository = repository,
       _commandKeys = commandKeys,
       _connectivity = connectivity,
       super(
         YorksWorkforceCollaborationState(isOnline: connectivity.isOnline),
       ) {
    _connectivitySubscription = connectivity.onChange.listen(
      _onConnectivityChanged,
    );
  }

  final YorksWorkforceCollaborationRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connectivitySubscription;
  int _generation = 0;

  Future<bool> load(String periodId) async {
    final normalized = periodId.trim();
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceCollaborationStatus.offline,
        isOnline: false,
      );
      return false;
    }
    final generation = ++_generation;
    state = state.copyWith(
      status: YorksWorkforceCollaborationStatus.loading,
      clearError: true,
      isOnline: true,
    );
    try {
      final projection = await _repository.getCollaboration(normalized);
      if (generation != _generation) return false;
      state = state.copyWith(
        status: YorksWorkforceCollaborationStatus.ready,
        projection: projection,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  Future<bool> openDiscussion(String periodId) async {
    final normalized = periodId.trim();
    if (state.isBusy || !_connectivity.isOnline) return false;
    state = state.copyWith(
      status: YorksWorkforceCollaborationStatus.saving,
      clearError: true,
    );
    const operation = 'open_workforce_timesheet_discussion';
    try {
      final payload = {'period_id': normalized};
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: normalized,
        payload: payload,
      );
      final result = await _repository.openDiscussion(
        periodId: normalized,
        idempotencyKey: key,
      );
      await _commandKeys.confirm(
        operation: operation,
        entityId: normalized,
        idempotencyKey: key,
      );
      final current = state.projection;
      state = state.copyWith(
        status: YorksWorkforceCollaborationStatus.saved,
        projection: YorksWorkforceCollaborationProjection(
          periodId: result.periodId,
          discussion: result.thread,
          documents: current?.documents ?? const [],
          notifications: current?.notifications ?? const [],
        ),
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, command: true);
      return false;
    }
  }

  Future<bool> sendMessage(YorksWorkforceDiscussionMessageInput input) async {
    final current = state.projection;
    final thread = current?.discussion;
    if (current == null ||
        thread == null ||
        state.isBusy ||
        !_connectivity.isOnline ||
        !input.isValid ||
        input.periodId.trim() != current.periodId) {
      return false;
    }
    state = state.copyWith(
      status: YorksWorkforceCollaborationStatus.saving,
      clearError: true,
    );
    const operation = 'send_workforce_timesheet_message';
    try {
      final payload = input.toRpcJson();
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: current.periodId,
        payload: payload,
      );
      final result = await _repository.sendDiscussionMessage(
        input,
        idempotencyKey: key,
      );
      await _commandKeys.confirm(
        operation: operation,
        entityId: current.periodId,
        idempotencyKey: key,
      );
      final messages = [
        ...thread.messages.where((item) => item.id != result.message.id),
        result.message,
      ];
      state = state.copyWith(
        status: YorksWorkforceCollaborationStatus.saved,
        projection: YorksWorkforceCollaborationProjection(
          periodId: current.periodId,
          discussion: YorksV1ChatThread(
            conversation: result.conversation,
            participants: thread.participants,
            messages: List.unmodifiable(messages),
          ),
          documents: current.documents,
          notifications: current.notifications,
        ),
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, command: true);
      return false;
    }
  }

  Future<bool> uploadEvidence(
    YorksWorkforceEvidenceUploadInput input, {
    required Uint8List bytes,
  }) async {
    final current = state.projection;
    if (current == null ||
        state.isBusy ||
        !_connectivity.isOnline ||
        !input.isValid ||
        input.periodId?.trim() != current.periodId) {
      return false;
    }
    state = state.copyWith(
      status: YorksWorkforceCollaborationStatus.saving,
      clearError: true,
    );
    const operation = 'upload_workforce_evidence';
    try {
      final payload = input.toRpcJson();
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: current.periodId,
        payload: payload,
      );
      final evidence = await _repository.uploadEvidence(
        input,
        bytes: bytes,
        idempotencyKey: key,
      );
      await _commandKeys.confirm(
        operation: operation,
        entityId: current.periodId,
        idempotencyKey: key,
      );
      state = state.copyWith(
        status: YorksWorkforceCollaborationStatus.saved,
        projection: YorksWorkforceCollaborationProjection(
          periodId: current.periodId,
          discussion: current.discussion,
          documents: evidence.documents,
          notifications: current.notifications,
        ),
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, command: true);
      return false;
    }
  }

  void purgeProtectedState({bool unavailable = false}) {
    _generation += 1;
    state = YorksWorkforceCollaborationState(
      status: unavailable
          ? YorksWorkforceCollaborationStatus.unavailable
          : YorksWorkforceCollaborationStatus.forbidden,
      isOnline: _connectivity.isOnline,
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    state = state.copyWith(
      status:
          online && state.status == YorksWorkforceCollaborationStatus.offline
          ? YorksWorkforceCollaborationStatus.ready
          : online
          ? state.status
          : YorksWorkforceCollaborationStatus.offline,
      isOnline: online,
    );
  }

  void _setFailure(YorksV1DomainException error, {required bool command}) {
    final next = switch (error.code) {
      YorksV1DomainErrorCode.unauthorized =>
        YorksWorkforceCollaborationStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksWorkforceCollaborationStatus.sessionExpired,
      YorksV1DomainErrorCode.offline =>
        YorksWorkforceCollaborationStatus.offline,
      YorksV1DomainErrorCode.conflict =>
        YorksWorkforceCollaborationStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksWorkforceCollaborationStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when command =>
        YorksWorkforceCollaborationStatus.uncertain,
      _ => YorksWorkforceCollaborationStatus.failure,
    };
    if (next == YorksWorkforceCollaborationStatus.forbidden ||
        next == YorksWorkforceCollaborationStatus.sessionExpired ||
        next == YorksWorkforceCollaborationStatus.unavailable) {
      _generation += 1;
      state = YorksWorkforceCollaborationState(
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
