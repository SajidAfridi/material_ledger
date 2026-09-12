import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_company_material_request_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_company_material_request_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_company_material_request_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final evidence in <({String name, Size size})>[
    (name: 'desktop', size: const Size(1366, 900)),
    (name: 'mobile', size: const Size(360, 800)),
  ]) {
    testWidgets('Company request composer is usable at ${evidence.name}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'selected_language': 'en'});
      final preferences = await SharedPreferences.getInstance();
      final repository = _CompanyRequestRepository();
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1CompanyMaterialRequestRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1CompanyMaterialRequestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Company use'), findsOneWidget);
      expect(find.text('Category and responsible unit'), findsWidgets);
      expect(find.text('Material items'), findsOneWidget);
      expect(find.text('Save private draft'), findsOneWidget);
      expect(find.text('Submit for Company approval'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('company-material-request-context')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Personal protective equipment · Workshop').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('company-material-request-beneficiary')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amina Hassan').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('company-material-request-receiver')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amina Hassan').last);
      await tester.pumpAndSettle();

      expect(repository.preflightCalls, 1);
      await tester.scrollUntilVisible(
        find.text('Resolved approver: Nadia Khalid'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Resolved approver: Nadia Khalid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _CompanyRequestRepository
    implements YorksV1CompanyMaterialRequestRepository {
  int preflightCalls = 0;

  static const _person = YorksV1CompanyMaterialRequestPerson(
    authUserId: '10000000-0000-4000-8000-000000000002',
    displayName: 'Amina Hassan',
  );

  @override
  Future<List<YorksV1CompanyMaterialRequestDraftOption>>
  listDraftOptions() async => const [
    YorksV1CompanyMaterialRequestDraftOption(
      categoryId: 'c1000000-0000-4000-8000-000000000001',
      categoryCode: 'ppe',
      categoryName: 'Personal protective equipment',
      responsibleUnitId: 'c1000000-0000-4000-8000-000000000002',
      responsibleUnitCode: 'WORKSHOP',
      responsibleUnitName: 'Workshop',
      beneficiaries: [_person],
      receivers: [_person],
    ),
  ];

  @override
  Future<YorksV1CompanyMaterialRequestApprovalPreflight> preflightApproval({
    required String categoryId,
    required String responsibleUnitId,
    required String beneficiaryAuthUserId,
    required String authorizedReceiverAuthUserId,
  }) async {
    preflightCalls++;
    return const YorksV1CompanyMaterialRequestApprovalPreflight(
      approvalRouteId: 'c1000000-0000-4000-8000-000000000003',
      policyVersion: 'cmr-test-v1',
      approver: YorksV1CompanyMaterialRequestPerson(
        authUserId: '10000000-0000-4000-8000-000000000001',
        displayName: 'Nadia Khalid',
      ),
    );
  }

  @override
  Future<YorksV1CompanyMaterialRequest> saveAndSubmit(
    YorksV1CompanyMaterialRequestDraft draft,
  ) => Future.error(UnimplementedError());

  @override
  Future<YorksV1CompanyMaterialRequest> saveDraft(
    YorksV1CompanyMaterialRequestDraft draft,
  ) => Future.error(UnimplementedError());

  @override
  Future<YorksV1CompanyMaterialRequest> submit({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) => Future.error(UnimplementedError());
}
