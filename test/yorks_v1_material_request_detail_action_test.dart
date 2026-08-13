import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';

void main() {
  group('Yorks V1 Material Request detail primary action', () {
    test('moves Procurement from arrangement to dispatch after approval', () {
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.approvedForArrangement,
          role: YorksV1Role.procurement,
          canArrange: true,
          canDispatch: false,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: false,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.arrange,
      );
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.approved,
          role: YorksV1Role.procurement,
          canArrange: true,
          canDispatch: true,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: false,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.dispatch,
      );
    });

    test('keeps receipt review ahead of the optional delivery order', () {
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.dispatched,
          role: YorksV1Role.siteEngineer,
          canArrange: false,
          canDispatch: false,
          canConfirmReceipt: true,
          canGenerateDeliveryOrder: false,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.receiptReview,
      );
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.dispatched,
          role: YorksV1Role.seniorMechanicalEngineer,
          canArrange: false,
          canDispatch: false,
          canConfirmReceipt: true,
          canGenerateDeliveryOrder: true,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.receiptReview,
      );
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.received,
          role: YorksV1Role.projectManager,
          canArrange: false,
          canDispatch: false,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: true,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.generateDeliveryOrder,
      );
    });

    test('returns replacement dispatch after a partial receipt', () {
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.partiallyReceived,
          role: YorksV1Role.procurement,
          canArrange: false,
          canDispatch: true,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: true,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.dispatch,
      );
    });

    test('received requests close before optional document actions', () {
      expect(
        yorksV1CanOfferMaterialRequestClose(
          state: YorksV1MaterialRequestState.received,
          role: YorksV1Role.siteEngineer,
        ),
        isTrue,
      );
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.received,
          role: YorksV1Role.siteEngineer,
          canArrange: false,
          canDispatch: false,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: true,
          canClose: true,
        ),
        YorksV1MaterialRequestDetailPrimaryAction.close,
      );
      expect(
        yorksV1CanOfferMaterialRequestClose(
          state: YorksV1MaterialRequestState.received,
          role: YorksV1Role.procurement,
        ),
        isFalse,
      );
    });

    test('does not show an action the role or projection does not permit', () {
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.awaitingApproval,
          role: YorksV1Role.siteEngineer,
          canArrange: false,
          canDispatch: false,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: false,
        ),
        isNull,
      );
      expect(
        yorksV1MaterialRequestDetailPrimaryAction(
          state: YorksV1MaterialRequestState.approved,
          role: YorksV1Role.projectEngineer,
          canArrange: false,
          canDispatch: true,
          canConfirmReceipt: false,
          canGenerateDeliveryOrder: false,
        ),
        isNull,
      );
    });
  });
}
