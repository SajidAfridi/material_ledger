import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/workforce_report_service.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_report_models.dart';

enum YorksWorkforceReportStatus {
  idle,
  loading,
  generating,
  ready,
  exporting,
  offline,
  conflict,
  uncertain,
  forbidden,
  sessionExpired,
  unavailable,
  failure,
}

final class YorksWorkforceReportState {
  const YorksWorkforceReportState({
    this.status = YorksWorkforceReportStatus.idle,
    this.artifact,
    this.history,
    this.excelBytes,
    this.pdfBytes,
    this.error,
    this.isOnline = true,
  });

  final YorksWorkforceReportStatus status;
  final YorksWorkforceReportArtifact? artifact;
  final YorksWorkforceReportHistory? history;
  final Uint8List? excelBytes;
  final Uint8List? pdfBytes;
  final YorksV1DomainException? error;
  final bool isOnline;

  bool get isBusy =>
      status == YorksWorkforceReportStatus.loading ||
      status == YorksWorkforceReportStatus.generating ||
      status == YorksWorkforceReportStatus.exporting;

  YorksWorkforceReportState copyWith({
    YorksWorkforceReportStatus? status,
    YorksWorkforceReportArtifact? artifact,
    bool clearArtifact = false,
    YorksWorkforceReportHistory? history,
    bool clearHistory = false,
    Uint8List? excelBytes,
    Uint8List? pdfBytes,
    bool clearBytes = false,
    YorksV1DomainException? error,
    bool clearError = false,
    bool? isOnline,
  }) => YorksWorkforceReportState(
    status: status ?? this.status,
    artifact: clearArtifact ? null : artifact ?? this.artifact,
    history: clearHistory ? null : history ?? this.history,
    excelBytes: clearBytes ? null : excelBytes ?? this.excelBytes,
    pdfBytes: clearBytes ? null : pdfBytes ?? this.pdfBytes,
    error: clearError ? null : error ?? this.error,
    isOnline: isOnline ?? this.isOnline,
  );
}

final class YorksWorkforceReportController
    extends StateNotifier<YorksWorkforceReportState> {
  YorksWorkforceReportController({
    required YorksWorkforceReportRepository repository,
    required YorksWorkforceReportBinaryService binaryService,
    required YorksV1CriticalCommandKeyStore commandKeys,
    required ConnectivityService connectivity,
  }) : _repository = repository,
       _binaryService = binaryService,
       _commandKeys = commandKeys,
       _connectivity = connectivity,
       super(YorksWorkforceReportState(isOnline: connectivity.isOnline)) {
    _connectivitySubscription = connectivity.onChange.listen(
      _onConnectivityChanged,
    );
  }

  final YorksWorkforceReportRepository _repository;
  final YorksWorkforceReportBinaryService _binaryService;
  final YorksV1CriticalCommandKeyStore _commandKeys;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connectivitySubscription;
  int _generation = 0;

  Future<bool> loadHistory({int limit = 25, int offset = 0}) async {
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceReportStatus.offline,
        isOnline: false,
      );
      return false;
    }
    final generation = ++_generation;
    state = state.copyWith(
      status: YorksWorkforceReportStatus.loading,
      clearError: true,
      isOnline: true,
    );
    try {
      final history = await _repository.listReportArtifacts(
        limit: limit,
        offset: offset,
      );
      if (generation != _generation) return false;
      state = state.copyWith(
        status: YorksWorkforceReportStatus.ready,
        history: history,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation == _generation) _setFailure(error, command: false);
      return false;
    }
  }

  Future<bool> generate(YorksWorkforceReportRequest request) async {
    if (state.isBusy || !_connectivity.isOnline) {
      if (!_connectivity.isOnline) {
        state = state.copyWith(
          status: YorksWorkforceReportStatus.offline,
          isOnline: false,
        );
      }
      return false;
    }
    Map<String, Object?> payload;
    try {
      payload = request.toRpcJson();
    } on FormatException {
      state = state.copyWith(
        status: YorksWorkforceReportStatus.failure,
        error: const YorksV1DomainException(
          YorksV1DomainErrorCode.invalidInput,
        ),
      );
      return false;
    }
    state = state.copyWith(
      status: YorksWorkforceReportStatus.generating,
      clearArtifact: true,
      clearBytes: true,
      clearError: true,
    );
    const operation = 'generate_workforce_report';
    final entityId = [
      request.kind.wire,
      request.periodMonth,
      request.workDate,
      request.teamId,
      request.projectId,
      request.workerId,
      ...request.snapshotIds,
    ].whereType<String>().join('|');
    try {
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: entityId,
        payload: payload,
      );
      final artifact = await _repository.generateReport(
        request,
        idempotencyKey: key,
      );
      await _commandKeys.confirm(
        operation: operation,
        entityId: entityId,
        idempotencyKey: key,
      );
      state = state.copyWith(artifact: artifact, clearError: true);
      final excel = _binaryService.buildExcel(artifact);
      final pdf = await _binaryService.buildPdf(artifact);
      state = state.copyWith(
        status: YorksWorkforceReportStatus.ready,
        artifact: artifact,
        excelBytes: excel,
        pdfBytes: pdf,
        clearError: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, command: true);
      return false;
    } catch (error) {
      state = state.copyWith(
        status: YorksWorkforceReportStatus.failure,
        error: YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
          cause: error,
        ),
      );
      return false;
    }
  }

  Future<bool> saveExcel() => _issueAndRun(
    format: YorksWorkforceReportFormat.xlsx,
    action: YorksWorkforceReportAction.download,
    localAction: (artifact, bytes) =>
        _binaryService.saveExcelBytes(bytes, artifact),
  );

  Future<bool> savePdf() => _issueAndRun(
    format: YorksWorkforceReportFormat.pdf,
    action: YorksWorkforceReportAction.download,
    localAction: (artifact, bytes) =>
        _binaryService.savePdfBytes(bytes, artifact),
  );

  Future<bool> previewPdf() => _issueAndRun(
    format: YorksWorkforceReportFormat.pdf,
    action: YorksWorkforceReportAction.preview,
  );

  Future<bool> printPdf() => _issueAndRun(
    format: YorksWorkforceReportFormat.pdf,
    action: YorksWorkforceReportAction.print,
    localAction: (_, bytes) => _binaryService.printPdfBytes(bytes),
  );

  Future<bool> sharePdf() => _issueAndRun(
    format: YorksWorkforceReportFormat.pdf,
    action: YorksWorkforceReportAction.share,
    localAction: (artifact, bytes) =>
        _binaryService.sharePdfBytes(bytes, artifact),
  );

  void selectHistoryArtifact(YorksWorkforceReportArtifact artifact) {
    if (state.isBusy) return;
    state = state.copyWith(
      status: YorksWorkforceReportStatus.ready,
      artifact: artifact,
      clearBytes: true,
      clearError: true,
    );
  }

  Future<bool> prepareSelectedArtifact() async {
    final artifact = state.artifact;
    if (artifact == null || state.isBusy) return false;
    state = state.copyWith(status: YorksWorkforceReportStatus.exporting);
    try {
      final excel = _binaryService.buildExcel(artifact);
      final pdf = await _binaryService.buildPdf(artifact);
      state = state.copyWith(
        status: YorksWorkforceReportStatus.ready,
        excelBytes: excel,
        pdfBytes: pdf,
        clearError: true,
      );
      return true;
    } catch (error) {
      _binaryFailure(error);
      return false;
    }
  }

  void purgeProtectedState({bool unavailable = false}) {
    _generation += 1;
    state = YorksWorkforceReportState(
      status: unavailable
          ? YorksWorkforceReportStatus.unavailable
          : YorksWorkforceReportStatus.forbidden,
      isOnline: _connectivity.isOnline,
    );
  }

  Future<bool> _issueAndRun({
    required YorksWorkforceReportFormat format,
    required YorksWorkforceReportAction action,
    Future<void> Function(YorksWorkforceReportArtifact, Uint8List)? localAction,
  }) async {
    final artifact = state.artifact;
    final bytes = format == YorksWorkforceReportFormat.xlsx
        ? state.excelBytes
        : state.pdfBytes;
    if (artifact == null || bytes == null || state.isBusy) return false;
    if (!_connectivity.isOnline) {
      state = state.copyWith(
        status: YorksWorkforceReportStatus.offline,
        isOnline: false,
      );
      return false;
    }
    final request = YorksWorkforceReportIssueRequest(
      artifactId: artifact.artifactId,
      format: format,
      action: action,
    );
    final payload = request.toRpcJson();
    const operation = 'issue_workforce_report_export';
    final entityId = '${artifact.artifactId}|${format.name}|${action.name}';
    state = state.copyWith(status: YorksWorkforceReportStatus.exporting);
    try {
      final key = await _commandKeys.acquire(
        operation: operation,
        entityId: entityId,
        payload: payload,
      );
      final receipt = await _repository.issueReportExport(
        request,
        idempotencyKey: key,
      );
      if (receipt.sourceHash != artifact.sourceHash) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      await _commandKeys.confirm(
        operation: operation,
        entityId: entityId,
        idempotencyKey: key,
      );
      if (localAction != null) await localAction(artifact, bytes);
      state = state.copyWith(status: YorksWorkforceReportStatus.ready);
      return true;
    } on YorksV1DomainException catch (error) {
      _setFailure(error, command: true);
      return false;
    } catch (error) {
      _binaryFailure(error);
      return false;
    }
  }

  void _binaryFailure(Object error) {
    state = state.copyWith(
      status: YorksWorkforceReportStatus.failure,
      error: YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      ),
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    state = state.copyWith(
      status: online && state.status == YorksWorkforceReportStatus.offline
          ? YorksWorkforceReportStatus.idle
          : online
          ? state.status
          : YorksWorkforceReportStatus.offline,
      isOnline: online,
    );
  }

  void _setFailure(YorksV1DomainException error, {required bool command}) {
    final status = switch (error.code) {
      YorksV1DomainErrorCode.unauthorized =>
        YorksWorkforceReportStatus.forbidden,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksWorkforceReportStatus.sessionExpired,
      YorksV1DomainErrorCode.offline => YorksWorkforceReportStatus.offline,
      YorksV1DomainErrorCode.conflict => YorksWorkforceReportStatus.conflict,
      YorksV1DomainErrorCode.featureDisabled =>
        YorksWorkforceReportStatus.unavailable,
      YorksV1DomainErrorCode.backendUnavailable when command =>
        YorksWorkforceReportStatus.uncertain,
      _ => YorksWorkforceReportStatus.failure,
    };
    state = state.copyWith(status: status, error: error);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
