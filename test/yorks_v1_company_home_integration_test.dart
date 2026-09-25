import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_material_request_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_register.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'support/yorks_v1_permission_test_support.dart';

void main() {
  for (final width in [360.0, 1366.0]) {
    testWidgets(
      'Combined home keeps Company creation and one register at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Register();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              yorksV1FeatureFlagsProvider.overrideWithValue(
                const YorksV1FeatureFlags(
                  foundation: true,
                  projects: true,
                  boq: true,
                  excel: true,
                  requests: true,
                  arrangement: true,
                  logistics: true,
                  returnsDocuments: true,
                  documents: true,
                  companyMaterialRequests: true,
                ),
              ),
              yorksV1CurrentRoleProvider.overrideWithValue(
                YorksV1Role.siteEngineer,
              ),
              yorksV1CurrentPermissionSnapshotProvider.overrideWith(
                (ref) => YorksV1TestPermissionController(
                  yorksV1TrustedFeaturePermissionState(),
                ),
              ),
              yorksV1MaterialRequestRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: const MaterialApp(home: YorksV1MaterialRequestsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.loads, greaterThan(0));
        expect(
          find.byKey(const ValueKey('material-request-centre-create-company')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('material-request-use-switch')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Register
    implements
        YorksV1MaterialRequestRepository,
        YorksV1MaterialRequestPhase2Repository,
        YorksV1UnifiedMaterialRequestRegisterRepository {
  int loads = 0;
  @override
  Future<YorksV1MaterialRegisterPage> listMaterialRegister(
    YorksV1MaterialRegisterQuery query,
  ) async {
    loads++;
    return YorksV1MaterialRegisterPage(
      items: [],
      totalCount: 0,
      limit: 15,
      offset: 0,
      hasMore: false,
      metrics: const YorksV1MaterialRequestSummaryMetrics(
        total: 0,
        open: 0,
        inProgress: 0,
        dispatched: 0,
        received: 0,
        closed: 0,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
