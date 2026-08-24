import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_returns_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_return_workflow.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/yorks_v1_permission_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material Return Centre is usable on desktop and 360px mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const query = YorksV1MaterialReturnRegisterQuery(search: '');
    final item = YorksV1MaterialReturnRegisterItem(
      id: 'return-1',
      number: 'YRA313-RTN001',
      state: YorksV1ProjectMaterialReturnState.awaitingApproval,
      recordVersion: 2,
      projectId: 'project-1',
      projectReference: 'YRA-313',
      projectName: '132/22kV Substation at Riyadh City',
      scopeId: 'scope-1',
      scopeName: 'Common',
      purpose: 'Project close-out surplus materials',
      draftedByDisplayName: 'Site Engineer',
      lineCount: 4,
      totalQuantity: '18',
      updatedAt: DateTime.utc(2026, 8, 24),
      attentionOwner: 'Engineering approval',
    );

    for (final size in [const Size(1366, 768), const Size(360, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
            yorksV1CurrentPermissionSnapshotProvider.overrideWith(
              (ref) => YorksV1TestPermissionController(
                yorksV1TrustedFeaturePermissionState(
                  role: YorksV1Role.projectEngineer,
                ),
              ),
            ),
            yorksV1MaterialReturnRegisterProvider(
              query,
            ).overrideWith((ref) async => [item]),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const RepaintBoundary(
              key: ValueKey('material-return-centre-evidence'),
              child: YorksV1MaterialReturnsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Material Return Centre'), findsOneWidget);
      expect(find.text('YRA313-RTN001'), findsOneWidget);
      expect(find.textContaining('132/22kV Substation'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');
      await expectLater(
        find.byKey(const ValueKey('material-return-centre-evidence')),
        matchesGoldenFile(
          'goldens/r38/material_return_centre_${size.width.toInt()}x${size.height.toInt()}.png',
        ),
      );
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
