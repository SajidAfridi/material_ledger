import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_arrangement_provider.dart';

void main() {
  test('engineering MR detail does not eagerly load Procurement workspace', () {
    for (final role in <YorksV1Role>[
      YorksV1Role.projectEngineer,
      YorksV1Role.siteEngineer,
      YorksV1Role.seniorMechanicalEngineer,
      YorksV1Role.projectManager,
      YorksV1Role.workshopInCharge,
      YorksV1Role.documentController,
    ]) {
      expect(
        yorksV1ShouldLoadArrangementWorkspaceForDetail(
          role: role,
          legacyArrangementReview: false,
        ),
        isFalse,
        reason: role.claimValue,
      );
    }
  });

  test('transactional and retained legacy paths still load the workspace', () {
    expect(
      yorksV1ShouldLoadArrangementWorkspaceForDetail(
        role: YorksV1Role.procurement,
        legacyArrangementReview: false,
      ),
      isTrue,
    );
    expect(
      yorksV1ShouldLoadArrangementWorkspaceForDetail(
        role: YorksV1Role.admin,
        legacyArrangementReview: false,
      ),
      isTrue,
    );
    expect(
      yorksV1ShouldLoadArrangementWorkspaceForDetail(
        role: YorksV1Role.projectEngineer,
        legacyArrangementReview: true,
      ),
      isTrue,
    );
  });
}
