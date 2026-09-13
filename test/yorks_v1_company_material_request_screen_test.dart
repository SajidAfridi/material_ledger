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
  testWidgets('desktop composer follows the familiar MR hierarchy', (
    tester,
  ) async {
    final repository = _CompanyRequestRepository();
    await _pumpComposer(
      tester,
      repository: repository,
      size: const Size(1366, 900),
    );

    expect(find.text('New Company Material Request'), findsOneWidget);
    expect(find.text('Request Information'), findsOneWidget);
    expect(find.text('Material items'), findsWidgets);
    expect(find.text('Request summary'), findsOneWidget);
    expect(find.text('Private draft'), findsOneWidget);
    expect(find.text('Submit for approval'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(
      find.text('Choose a category and responsible unit first'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('company-material-request-save-draft')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('company-material-request-submit')),
          )
          .onPressed,
      isNull,
    );

    await _completeDetails(tester);
    expect(repository.preflightCalls, 1);
    expect(find.textContaining('Nadia Khalid'), findsWidgets);
    await _completeFirstLine(tester);
    expect(repository.preflightCalls, 1);

    final save = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('company-material-request-save-draft')),
    );
    expect(save.onPressed, isNotNull);

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('company-material-request-submit')),
    );
    expect(submit.onPressed, isNotNull);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-submit')),
    );
    expect(find.text('Submit this company request?'), findsOneWidget);
    expect(find.textContaining('Nadia Khalid'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('company-material-request-confirm-submit')),
    );
    await tester.pumpAndSettle();
    expect(repository.submitCalls, 1);
    expect(find.text('Company request submitted'), findsOneWidget);
    expect(find.textContaining('CMR-0001'), findsOneWidget);
  });

  testWidgets('mobile composer uses Details, Items and Review steps', (
    tester,
  ) async {
    final repository = _CompanyRequestRepository();
    await _pumpComposer(
      tester,
      repository: repository,
      size: const Size(360, 800),
    );

    expect(find.text('Who and where is this for?'), findsOneWidget);
    expect(find.text('Details'), findsWidgets);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(
      find.text('A company request, not a project request'),
      findsOneWidget,
    );

    await _completeDetails(tester);
    expect(repository.preflightCalls, 1);
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('company-material-request-continue')),
    );
    expect(continueButton.onPressed, isNotNull);
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-continue')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Material basket'), findsOneWidget);

    await _completeFirstLine(tester);
    expect(repository.preflightCalls, 1);
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-review')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review and submit'), findsOneWidget);
    expect(find.text('Request summary'), findsOneWidget);
    expect(find.textContaining('Nadia Khalid'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Safety helmets'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Safety helmets'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('company-material-request-review-confirmation'),
      ),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await _tapVisible(
      tester,
      find.byKey(
        const ValueKey('company-material-request-review-confirmation'),
      ),
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('company-material-request-submit')),
    );
    expect(submit.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redesigned desktop and mobile states match visual evidence', (
    tester,
  ) async {
    await _pumpComposer(
      tester,
      repository: _CompanyRequestRepository(),
      size: const Size(1366, 900),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/company_requests/after_company_request_desktop.png',
      ),
    );

    await _pumpComposer(
      tester,
      repository: _CompanyRequestRepository(),
      size: const Size(360, 800),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/company_requests/after_company_request_mobile_details.png',
      ),
    );

    await _completeDetails(tester);
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-continue')),
    );
    await tester.pumpAndSettle();
    await _completeFirstLine(tester);
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-review')),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/company_requests/after_company_request_mobile_review.png',
      ),
    );
  });
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  required _CompanyRequestRepository repository,
  required Size size,
}) async {
  SharedPreferences.setMockInitialValues({'selected_language': 'en'});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
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
}

Future<void> _completeDetails(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('company-material-request-context')),
  );
  await tester.tap(find.text('Personal protective equipment · Workshop').last);
  await tester.pumpAndSettle();
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('company-material-request-beneficiary')),
  );
  await tester.tap(find.text('Amina Hassan').last);
  await tester.pumpAndSettle();
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('company-material-request-receiver')),
  );
  await tester.tap(find.text('Amina Hassan').last);
  await tester.pumpAndSettle();
  await _enterVisible(
    tester,
    find.byKey(const ValueKey('company-material-request-purpose')),
    'Workshop safety stock',
  );
  await _enterVisible(
    tester,
    find.byKey(const ValueKey('company-material-request-collection-point')),
    'Main workshop store',
  );
  await tester.pumpAndSettle();
}

Future<void> _completeFirstLine(WidgetTester tester) async {
  await _enterVisible(
    tester,
    _formFieldWithLabel('Item description'),
    'Safety helmets',
  );
  await _enterVisible(tester, _formFieldWithLabel('Quantity'), '12');
  await _enterVisible(tester, _formFieldWithLabel('Unit'), 'pcs');
  await tester.pumpAndSettle();
}

Finder _formFieldWithLabel(String label) =>
    find.widgetWithText(TextFormField, label);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterVisible(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pump();
}

class _CompanyRequestRepository
    implements YorksV1CompanyMaterialRequestRepository {
  int preflightCalls = 0;
  int submitCalls = 0;

  static const _person = YorksV1CompanyMaterialRequestPerson(
    authUserId: '10000000-0000-4000-8000-000000000002',
    displayName: 'Amina Hassan',
  );
  static const _approver = YorksV1CompanyMaterialRequestPerson(
    authUserId: '10000000-0000-4000-8000-000000000001',
    displayName: 'Nadia Khalid',
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
      approver: _approver,
    );
  }

  @override
  Future<YorksV1CompanyMaterialRequest> saveAndSubmit(
    YorksV1CompanyMaterialRequestDraft draft,
  ) async {
    submitCalls++;
    return _result(draft, state: 'awaiting_company_approval');
  }

  @override
  Future<YorksV1CompanyMaterialRequest> saveDraft(
    YorksV1CompanyMaterialRequestDraft draft,
  ) async => _result(draft, state: 'draft');

  YorksV1CompanyMaterialRequest _result(
    YorksV1CompanyMaterialRequestDraft draft, {
    required String state,
  }) => YorksV1CompanyMaterialRequest(
    id: draft.id,
    recordVersion: draft.recordVersion + 1,
    state: state,
    categoryName: 'Personal protective equipment',
    responsibleUnitName: 'Workshop',
    purpose: draft.purpose!,
    timing: draft.timing,
    deliveryCollectionPoint: draft.deliveryCollectionPoint!,
    beneficiary: _person,
    authorizedReceiver: _person,
    requesterDisplayName: 'Test requester',
    requesterExactRole: 'Site Engineer',
    lines: draft.lines,
    requestNumber: state == 'draft' ? null : 'CMR-0001',
    approver: state == 'draft' ? null : _approver,
    approvalPolicyVersion: state == 'draft' ? null : 'cmr-test-v1',
  );

  @override
  Future<YorksV1CompanyMaterialRequest> submit({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) => Future.error(UnimplementedError());
}
