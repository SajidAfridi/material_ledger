import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../data/accounts_receivables_repository.dart';
import '../domain/accounts_receivables_inputs.dart';
import '../domain/accounts_receivables_models.dart';
import 'accounts_controller.dart';

final class YorksAccountsReceivablesState {
  const YorksAccountsReceivablesState({
    this.status = YorksAccountsViewStatus.idle,
    this.claims,
    this.selectedClaim,
    this.invoices,
    this.selectedInvoice,
    this.ledger,
    this.error,
    this.isMutating = false,
  });

  final YorksAccountsViewStatus status;
  final YorksAccountsClaimsProjection? claims;
  final YorksAccountsClaimDetailProjection? selectedClaim;
  final YorksAccountsInvoicesProjection? invoices;
  final YorksAccountsInvoiceDetailProjection? selectedInvoice;
  final YorksAccountsReceivablesLedgerProjection? ledger;
  final YorksV1DomainException? error;
  final bool isMutating;

  bool get hasCommercialValues =>
      claims != null ||
      selectedClaim != null ||
      invoices != null ||
      selectedInvoice != null ||
      ledger != null;

  YorksAccountsReceivablesState copyWith({
    YorksAccountsViewStatus? status,
    YorksAccountsClaimsProjection? claims,
    YorksAccountsClaimDetailProjection? selectedClaim,
    YorksAccountsInvoicesProjection? invoices,
    YorksAccountsInvoiceDetailProjection? selectedInvoice,
    YorksAccountsReceivablesLedgerProjection? ledger,
    YorksV1DomainException? error,
    bool? isMutating,
    bool clearClaims = false,
    bool clearSelectedClaim = false,
    bool clearInvoices = false,
    bool clearSelectedInvoice = false,
    bool clearLedger = false,
    bool clearError = false,
  }) => YorksAccountsReceivablesState(
    status: status ?? this.status,
    claims: clearClaims ? null : claims ?? this.claims,
    selectedClaim: clearSelectedClaim
        ? null
        : selectedClaim ?? this.selectedClaim,
    invoices: clearInvoices ? null : invoices ?? this.invoices,
    selectedInvoice: clearSelectedInvoice
        ? null
        : selectedInvoice ?? this.selectedInvoice,
    ledger: clearLedger ? null : ledger ?? this.ledger,
    error: clearError ? null : error ?? this.error,
    isMutating: isMutating ?? this.isMutating,
  );
}

/// Project-scoped T03 application boundary.
///
/// Every mutation is server-confirmed and uses a device-persistent
/// idempotency lease. Access/session/feature loss clears the entire protected
/// T03 projection rather than retaining stale commercial metadata.
final class YorksAccountsReceivablesController
    extends StateNotifier<YorksAccountsReceivablesState> {
  YorksAccountsReceivablesController({
    required String projectId,
    required YorksAccountsReceivablesRepository repository,
    required YorksV1CriticalCommandKeyStore commandKeys,
  }) : _projectId = projectId.trim(),
       _repository = repository,
       _commandKeys = commandKeys,
       super(const YorksAccountsReceivablesState());

  final String _projectId;
  final YorksAccountsReceivablesRepository _repository;
  final YorksV1CriticalCommandKeyStore _commandKeys;

  Future<bool> loadClaims({
    YorksAccountsClaimStatus? status,
    YorksAccountsCompositeCursor? before,
    int limit = 50,
  }) => _load(
    () => _repository.listClaims(
      _projectId,
      status: status,
      before: before,
      limit: limit,
    ),
    (projection) => state.copyWith(
      status: YorksAccountsViewStatus.success,
      claims: projection,
      clearError: true,
    ),
  );

  Future<bool> loadClaim(String claimId) {
    final normalized = claimId.trim();
    if (normalized.isEmpty) return _rejectInvalidRead();
    return _load(
      () => _repository.getClaim(_projectId, normalized),
      (projection) => state.copyWith(
        status: YorksAccountsViewStatus.success,
        selectedClaim: projection,
        clearError: true,
      ),
    );
  }

  Future<bool> loadInvoices({
    YorksAccountsInvoiceStatus? status,
    YorksAccountsDueState? dueState,
    YorksAccountsCompositeCursor? before,
    int limit = 50,
  }) => _load(
    () => _repository.listInvoices(
      _projectId,
      status: status,
      dueState: dueState,
      before: before,
      limit: limit,
    ),
    (projection) => state.copyWith(
      status: YorksAccountsViewStatus.success,
      invoices: projection,
      clearError: true,
    ),
  );

  Future<bool> loadInvoice(String invoiceId) {
    final normalized = invoiceId.trim();
    if (normalized.isEmpty) return _rejectInvalidRead();
    return _load(
      () => _repository.getInvoice(_projectId, normalized),
      (projection) => state.copyWith(
        status: YorksAccountsViewStatus.success,
        selectedInvoice: projection,
        clearError: true,
      ),
    );
  }

  Future<bool> loadReceiptsAndPdc({
    String? invoiceId,
    YorksAccountsCompositeCursor? before,
    int limit = 50,
  }) => _load(
    () => _repository.listReceiptsAndPdc(
      _projectId,
      invoiceId: invoiceId,
      before: before,
      limit: limit,
    ),
    (projection) => state.copyWith(
      status: YorksAccountsViewStatus.success,
      ledger: projection,
      clearError: true,
    ),
  );

  Future<YorksAccountsReceivablesCommandResult?> createClaimDraft(
    YorksAccountsClaimDraftInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'create_client_claim_draft',
    entityId: _projectId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.createClaimDraft(input, idempotencyKey: key),
    reconcile: loadClaims,
  );

  Future<YorksAccountsReceivablesCommandResult?> updateClaimDraft(
    YorksAccountsClaimDraftInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'update_client_claim_draft',
    entityId: input.claimId ?? '',
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.updateClaimDraft(input, idempotencyKey: key),
    reconcile: () async {
      final claimId = input.claimId;
      return claimId == null ? loadClaims() : loadClaim(claimId);
    },
  );

  Future<YorksAccountsReceivablesCommandResult?> deleteClaimDraft(
    YorksAccountsEntityActionInput input,
  ) => _claimAction(
    input,
    operation: 'delete_client_claim_draft',
    invoke: (key) => _repository.deleteClaimDraft(input, idempotencyKey: key),
  );

  Future<YorksAccountsReceivablesCommandResult?> submitClaimToAccounts(
    YorksAccountsEntityActionInput input,
  ) => _claimAction(
    input,
    operation: 'submit_client_claim_to_accounts',
    invoke: (key) =>
        _repository.submitClaimToAccounts(input, idempotencyKey: key),
  );

  Future<YorksAccountsReceivablesCommandResult?> cancelClaim(
    YorksAccountsEntityActionInput input,
  ) => _claimAction(
    input,
    operation: 'cancel_client_claim',
    invoke: (key) => _repository.cancelClaim(input, idempotencyKey: key),
  );

  Future<YorksAccountsReceivablesCommandResult?> createInvoiceDraft(
    YorksAccountsInvoiceDraftInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'create_client_invoice_draft',
    entityId: input.claimId ?? '',
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.createInvoiceDraft(input, idempotencyKey: key),
    reconcile: loadInvoices,
  );

  Future<YorksAccountsReceivablesCommandResult?> updateInvoiceDraft(
    YorksAccountsInvoiceDraftInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'update_client_invoice_draft',
    entityId: input.invoiceId ?? '',
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.updateInvoiceDraft(input, idempotencyKey: key),
    reconcile: () async {
      final invoiceId = input.invoiceId;
      return invoiceId == null ? loadInvoices() : loadInvoice(invoiceId);
    },
  );

  Future<YorksAccountsReceivablesCommandResult?> submitInvoice(
    YorksAccountsInvoiceSubmitInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'submit_client_invoice',
    entityId: input.invoiceId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.submitInvoice(input, idempotencyKey: key),
    reconcile: () => loadInvoice(input.invoiceId),
  );

  Future<YorksAccountsReceivablesCommandResult?> markUnderCertification(
    YorksAccountsEntityActionInput input,
  ) => _invoiceAction(
    input,
    operation: 'mark_client_invoice_under_certification',
    invoke: (key) =>
        _repository.markInvoiceUnderCertification(input, idempotencyKey: key),
  );

  Future<YorksAccountsReceivablesCommandResult?> returnInvoice(
    YorksAccountsEntityActionInput input,
  ) => _invoiceAction(
    input,
    operation: 'return_client_invoice',
    invoke: (key) => _repository.returnInvoice(input, idempotencyKey: key),
  );

  Future<YorksAccountsReceivablesCommandResult?> cancelInvoice(
    YorksAccountsEntityActionInput input,
  ) => _invoiceAction(
    input,
    operation: 'cancel_client_invoice',
    invoke: (key) => _repository.cancelInvoice(input, idempotencyKey: key),
  );

  Future<YorksAccountsReceivablesCommandResult?> recordCertification(
    YorksAccountsCertificationInput input,
  ) {
    final selected = state.selectedInvoice?.invoice;
    if (selected != null &&
        selected.invoiceId == input.invoiceId.trim() &&
        selected.claimedExVat != null &&
        !input.isValidAgainstClaimed(selected.claimedExVat!)) {
      return _rejectInvalidCommand();
    }
    return _projectCommand(
      input.projectId,
      operation: 'record_client_certification',
      entityId: input.invoiceId,
      payload: input.idempotencyPayload(),
      invoke: (key) =>
          _repository.recordCertification(input, idempotencyKey: key),
      reconcile: () => _afterInvoiceMutation(input.invoiceId),
    );
  }

  Future<YorksAccountsReceivablesCommandResult?> recordPayment(
    YorksAccountsPaymentInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'record_client_payment',
    entityId: input.invoiceId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.recordPayment(input, idempotencyKey: key),
    reconcile: () => _afterInvoiceMutation(input.invoiceId),
  );

  Future<YorksAccountsReceivablesCommandResult?> reversePayment(
    YorksAccountsPaymentReversalInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'reverse_client_payment',
    entityId: input.originalPaymentId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.reversePayment(input, idempotencyKey: key),
    reconcile: () => _afterInvoiceMutation(input.invoiceId),
  );

  Future<YorksAccountsReceivablesCommandResult?> createPdc(
    YorksAccountsPdcCreateInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'create_client_pdc',
    entityId: input.invoiceId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.createPdc(input, idempotencyKey: key),
    reconcile: () => _afterInvoiceMutation(input.invoiceId),
  );

  Future<YorksAccountsReceivablesCommandResult?> transitionPdc(
    YorksAccountsPdcTransitionInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'transition_client_pdc',
    entityId: input.pdcId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.transitionPdc(input, idempotencyKey: key),
    reconcile: () async {
      final invoiceId = state.selectedInvoice?.invoice.invoiceId;
      return invoiceId == null
          ? loadReceiptsAndPdc()
          : _afterInvoiceMutation(invoiceId);
    },
  );

  Future<YorksAccountsReceivablesCommandResult?> replacePdc(
    YorksAccountsPdcReplacementInput input,
  ) => _projectCommand(
    input.projectId,
    operation: 'replace_client_pdc',
    entityId: input.originalPdcId,
    payload: input.idempotencyPayload(),
    invoke: (key) => _repository.replacePdc(input, idempotencyKey: key),
    reconcile: () async {
      final invoiceId = state.selectedInvoice?.invoice.invoiceId;
      return invoiceId == null
          ? loadReceiptsAndPdc()
          : _afterInvoiceMutation(invoiceId);
    },
  );

  /// Called by provider/session coordination before disposal if needed.
  void purgeAll() {
    state = const YorksAccountsReceivablesState();
  }

  Future<YorksAccountsReceivablesCommandResult?> _claimAction(
    YorksAccountsEntityActionInput input, {
    required String operation,
    required Future<YorksAccountsReceivablesCommandResult> Function(String key)
    invoke,
  }) => _projectCommand(
    input.projectId,
    operation: operation,
    entityId: input.entityId,
    payload: input.idempotencyPayload(),
    invoke: invoke,
    reconcile: () => loadClaims(),
  );

  Future<YorksAccountsReceivablesCommandResult?> _invoiceAction(
    YorksAccountsEntityActionInput input, {
    required String operation,
    required Future<YorksAccountsReceivablesCommandResult> Function(String key)
    invoke,
  }) => _projectCommand(
    input.projectId,
    operation: operation,
    entityId: input.entityId,
    payload: input.idempotencyPayload(),
    invoke: invoke,
    reconcile: () => loadInvoice(input.entityId),
  );

  Future<bool> _afterInvoiceMutation(String invoiceId) async {
    final detailLoaded = await loadInvoice(invoiceId);
    if (!detailLoaded) return false;
    return loadReceiptsAndPdc(invoiceId: invoiceId);
  }

  Future<bool> _load<T>(
    Future<T> Function() invoke,
    YorksAccountsReceivablesState Function(T value) success,
  ) async {
    state = state.copyWith(
      status: YorksAccountsViewStatus.loading,
      clearError: true,
    );
    try {
      final value = await invoke();
      state = success(value);
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

  Future<YorksAccountsReceivablesCommandResult?> _projectCommand(
    String inputProjectId, {
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required Future<YorksAccountsReceivablesCommandResult> Function(String key)
    invoke,
    required Future<bool> Function() reconcile,
  }) {
    if (!_matchesProject(inputProjectId) || entityId.trim().isEmpty) {
      return _rejectInvalidCommand();
    }
    return _runCommand(
      operation: operation,
      entityId: entityId,
      payload: payload,
      invoke: invoke,
      reconcile: reconcile,
    );
  }

  Future<YorksAccountsReceivablesCommandResult?> _runCommand({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required Future<YorksAccountsReceivablesCommandResult> Function(String key)
    invoke,
    required Future<bool> Function() reconcile,
  }) async {
    if (state.isMutating) return null;
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
        status: YorksAccountsViewStatus.success,
        isMutating: false,
        clearError: true,
      );
      await reconcile();
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

  bool _matchesProject(String projectId) =>
      _projectId.isNotEmpty && projectId.trim() == _projectId;

  Future<bool> _rejectInvalidRead() {
    _setFailure(
      const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput),
      commandMayHaveCommitted: false,
    );
    return Future<bool>.value(false);
  }

  Future<YorksAccountsReceivablesCommandResult?> _rejectInvalidCommand() {
    _setFailure(
      const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput),
      commandMayHaveCommitted: false,
    );
    return Future<YorksAccountsReceivablesCommandResult?>.value();
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
      state = YorksAccountsReceivablesState(status: status, error: error);
      return;
    }
    state = state.copyWith(status: status, error: error, isMutating: false);
  }
}
