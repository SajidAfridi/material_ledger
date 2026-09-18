import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';

void main() {
  group('Material Request creation-form approval preflight', () {
    test('offers Approve only to a policy-enabled authorized creator', () {
      expect(
        yorksV1CanOfferMaterialRequestCreationApproval(
          role: YorksV1Role.projectEngineer,
          publishedSelfApprovalEnabled: true,
          hasApprovalAccess: true,
          isNewDraft: true,
          isEditingBeforeApproval: false,
        ),
        isTrue,
      );
    });

    test('keeps Submit-only presentation for an exact Site Engineer', () {
      expect(
        yorksV1CanOfferMaterialRequestCreationApproval(
          role: YorksV1Role.siteEngineer,
          publishedSelfApprovalEnabled: true,
          hasApprovalAccess: true,
          isNewDraft: true,
          isEditingBeforeApproval: false,
        ),
        isFalse,
      );
    });

    test('fails closed for unpublished policy, missing access and edits', () {
      for (final conditions in [
        (policy: false, access: true, newDraft: true, editing: false),
        (policy: true, access: false, newDraft: true, editing: false),
        (policy: true, access: true, newDraft: false, editing: false),
        (policy: true, access: true, newDraft: true, editing: true),
      ]) {
        expect(
          yorksV1CanOfferMaterialRequestCreationApproval(
            role: YorksV1Role.projectEngineer,
            publishedSelfApprovalEnabled: conditions.policy,
            hasApprovalAccess: conditions.access,
            isNewDraft: conditions.newDraft,
            isEditingBeforeApproval: conditions.editing,
          ),
          isFalse,
        );
      }
    });
  });
}
