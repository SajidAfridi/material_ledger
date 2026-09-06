import '../models/yorks_v1_arrangement.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_logistics.dart';
import '../models/yorks_v1_material_request.dart';
import '../repositories/yorks_v1_arrangement_repository.dart';
import '../repositories/yorks_v1_logistics_repository.dart';
import '../repositories/yorks_v1_material_request_repository.dart';
import '../services/yorks_v1_critical_command_key_store.dart';

/// Presentation-facing boundary for critical Material Request transitions.
///
/// Widgets supply typed intent only. This controller owns persistent retry
/// keys and delegates the server-confirmed mutation to the correct repository.
class YorksV1MaterialWorkflowCommandController {
  const YorksV1MaterialWorkflowCommandController({
    required YorksV1MaterialRequestRepository materialRequests,
    required YorksV1ArrangementRepository arrangements,
    required YorksV1LogisticsRepository logistics,
    required YorksV1CriticalCommandKeyStore commandKeys,
  }) : _materialRequests = materialRequests,
       _arrangements = arrangements,
       _logistics = logistics,
       _commandKeys = commandKeys;

  final YorksV1MaterialRequestRepository _materialRequests;
  final YorksV1ArrangementRepository _arrangements;
  final YorksV1LogisticsRepository _logistics;
  final YorksV1CriticalCommandKeyStore _commandKeys;

  Future<YorksV1MaterialRequest> decideMaterialRequest(
    YorksV1DecideMaterialRequestInput input,
  ) => _run(
    operation: 'decide_material_request_${input.decision.wireValue}',
    entityId: input.requestId,
    payload: input.toRpcPayload(),
    invoke: (key) => _materialRequests.decideRequest(
      YorksV1DecideMaterialRequestInput(
        requestId: input.requestId,
        expectedVersion: input.expectedVersion,
        decision: input.decision,
        reason: input.reason,
        idempotencyKey: key,
      ),
    ),
  );

  Future<List<YorksV1MaterialRequestComment>> addMaterialRequestComment(
    YorksV1AddMaterialRequestCommentInput input,
  ) => _run(
    operation: 'add_material_request_comment',
    entityId: input.requestId,
    payload: input.toRpcPayload(),
    invoke: (key) => _materialRequests.addComment(
      YorksV1AddMaterialRequestCommentInput(
        requestId: input.requestId,
        body: input.body,
        mentionedAuthUserIds: input.mentionedAuthUserIds,
        attachmentIds: input.attachmentIds,
        parentCommentId: input.parentCommentId,
        contextType: input.contextType,
        contextEntityId: input.contextEntityId,
        idempotencyKey: key,
      ),
    ),
  );

  Future<YorksV1ArrangementWorkspace> beginArrangement(
    YorksV1BeginArrangementInput input,
  ) => _run(
    operation: 'begin_arrangement',
    entityId: input.requestId,
    payload: input.toRpcPayload(),
    invoke: (key) => _arrangements.begin(
      YorksV1BeginArrangementInput(
        requestId: input.requestId,
        expectedRequestVersion: input.expectedRequestVersion,
        idempotencyKey: key,
      ),
    ),
  );

  Future<YorksV1ArrangementWorkspace> saveArrangement(
    YorksV1SaveArrangementInput input,
  ) => _run(
    operation: 'save_arrangement',
    entityId: input.arrangementId,
    payload: input.toRpcPayload(),
    invoke: (key) => _arrangements.save(
      YorksV1SaveArrangementInput(
        requestId: input.requestId,
        arrangementId: input.arrangementId,
        expectedRequestVersion: input.expectedRequestVersion,
        expectedArrangementVersion: input.expectedArrangementVersion,
        lines: input.lines,
        idempotencyKey: key,
        procurementNote: input.procurementNote,
      ),
    ),
  );

  Future<YorksV1MaterialRequest> createReplacementMaterialRequest(
    YorksV1CreateReplacementMaterialRequestInput input,
  ) {
    final repository = _materialRequests;
    if (repository is! YorksV1MaterialRequestPhase3Repository) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    return _run(
      operation: 'create_replacement_material_request',
      entityId: input.sourceRequestId,
      payload: input.toRpcPayload(),
      invoke: (key) => (repository as YorksV1MaterialRequestPhase3Repository)
          .createReplacement(
            YorksV1CreateReplacementMaterialRequestInput(
              sourceRequestId: input.sourceRequestId,
              expectedSourceVersion: input.expectedSourceVersion,
              idempotencyKey: key,
            ),
          ),
    );
  }

  Future<YorksV1ArrangementWorkspace> decideArrangement(
    YorksV1DecideArrangementInput input,
  ) => _run(
    operation: 'decide_arrangement_${input.decision.wireValue}',
    entityId: input.arrangementId,
    payload: input.toRpcPayload(),
    invoke: (key) => _arrangements.decide(
      YorksV1DecideArrangementInput(
        requestId: input.requestId,
        arrangementId: input.arrangementId,
        expectedRequestVersion: input.expectedRequestVersion,
        expectedArrangementVersion: input.expectedArrangementVersion,
        decision: input.decision,
        idempotencyKey: key,
        reason: input.reason,
      ),
    ),
  );

  Future<YorksV1MaterialRequest> cancelMaterialRequest(
    YorksV1CancelMaterialRequestInput input,
  ) => _run(
    operation: 'cancel_material_request',
    entityId: input.requestId,
    payload: input.toRpcPayload(),
    invoke: (key) => _materialRequests.cancel(
      YorksV1CancelMaterialRequestInput(
        requestId: input.requestId,
        expectedVersion: input.expectedVersion,
        reason: input.reason,
        idempotencyKey: key,
      ),
    ),
  );

  Future<YorksV1MaterialRequest> closeMaterialRequest(
    YorksV1CloseMaterialRequestInput input,
  ) => _run(
    operation: 'close_material_request',
    entityId: input.requestId,
    payload: input.toRpcPayload(),
    invoke: (key) => _materialRequests.close(
      YorksV1CloseMaterialRequestInput(
        requestId: input.requestId,
        expectedVersion: input.expectedVersion,
        idempotencyKey: key,
      ),
    ),
  );

  Future<YorksV1LogisticsWorkspace> dispatch(YorksV1DispatchInput input) =>
      _run(
        operation: 'dispatch_materials',
        entityId: input.requestId,
        payload: input.toRpcPayload(),
        invoke: (key) => _logistics.dispatch(
          YorksV1DispatchInput(
            requestId: input.requestId,
            expectedRequestVersion: input.expectedRequestVersion,
            dispatchDate: input.dispatchDate,
            deliveryReference: input.deliveryReference,
            lines: input.lines,
            idempotencyKey: key,
            driverName: input.driverName,
            vehicleReference: input.vehicleReference,
          ),
        ),
      );

  Future<YorksV1LogisticsInventoryItem> createInventoryItem({
    required String requestLineId,
    required YorksV1InventoryAdjustmentInput input,
  }) {
    if (!input.createsItem) {
      throw ArgumentError.value(
        input.inventoryItemId,
        'input.inventoryItemId',
        'The arrangement create command must not target an existing item.',
      );
    }
    return _run(
      operation: 'create_arrangement_inventory_item',
      entityId: requestLineId,
      payload: input.toCreateItemRpcPayload(),
      invoke: (key) =>
          _logistics.adjustInventory(input.withIdempotencyKey(key)),
    );
  }

  Future<YorksV1LogisticsWorkspace> confirmReceipt(
    YorksV1ReceiptConfirmationInput input,
  ) => _run(
    operation: 'confirm_receipt',
    entityId: input.dispatchId,
    payload: input.toRpcPayload(),
    invoke: (key) => _logistics.confirmReceipt(
      YorksV1ReceiptConfirmationInput(
        requestId: input.requestId,
        dispatchId: input.dispatchId,
        expectedRequestVersion: input.expectedRequestVersion,
        expectedDispatchVersion: input.expectedDispatchVersion,
        lines: input.lines,
        idempotencyKey: key,
      ),
    ),
  );

  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  ) => _run(
    operation: 'generate_delivery_order',
    entityId: input.dispatchId,
    payload: input.toRpcPayload(),
    invoke: (key) => _logistics.generateDeliveryOrder(
      YorksV1DeliveryOrderGenerationInput(
        requestId: input.requestId,
        dispatchId: input.dispatchId,
        expectedRequestVersion: input.expectedRequestVersion,
        expectedDispatchVersion: input.expectedDispatchVersion,
        deliveryOrderReference: input.deliveryOrderReference,
        idempotencyKey: key,
      ),
    ),
  );

  Future<T> _run<T>({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
    required Future<T> Function(String idempotencyKey) invoke,
  }) async {
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
    return result;
  }
}
