import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_company_material_request_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_configuration_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_company_material_request_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_company_material_request_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    var cache = File(Platform.resolvedExecutable).parent;
    while (!cache.path.endsWith('${Platform.pathSeparator}cache') &&
        cache.path != cache.parent.path) {
      cache = cache.parent;
    }
    final bytes = await File(
      '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await Future.wait([fonts.load(), arabic.load(), icons.load()]);
  });
  testWidgets(
    'saved company draft reopens with its protected details and lines',
    (tester) async {
      final draft = _CompanyRequestRepository()._result(
        const YorksV1CompanyMaterialRequestDraft(
          id: 'saved-draft',
          recordVersion: 2,
          submissionIdempotencyKey: 'key',
          categoryId: 'c1000000-0000-4000-8000-000000000001',
          responsibleUnitId: 'c1000000-0000-4000-8000-000000000002',
          purpose: 'Saved company need',
          deliveryCollectionPoint: 'Workshop',
          timing: YorksV1MaterialRequestTiming.normal,
          beneficiaryAuthUserId: 'person',
          authorizedReceiverAuthUserId: 'person',
          lines: [
            YorksV1CompanyMaterialRequestLine(
              id: 'line',
              displayOrder: 1,
              description: 'Saved helmets',
              quantity: '4',
              unit: 'pcs',
            ),
          ],
        ),
        state: 'draft',
      );
      final repository = _CompanyRequestRepository(request: draft);
      await _pumpComposer(
        tester,
        repository: repository,
        size: const Size(1366, 900),
        draftId: 'saved-draft',
      );
      expect(find.text('Saved company need'), findsOneWidget);
      expect(find.text('Saved helmets'), findsOneWidget);
      expect(repository.preflightCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dispatch reviews a partial selection and reuses its retry identity',
    (tester) async {
      final repository = _CompanyRequestRepository(
        request: _CompanyRequestRepository._fulfilmentRequest,
      )..failFirstDispatch = true;
      await _pumpApproval(
        tester,
        repository: repository,
        size: const Size(360, 800),
        child: const YorksV1CompanyMaterialRequestApprovalScreen(
          requestId: 'request',
        ),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Dispatch ready quantity'),
        );
        expect(repository.dispatchKeys.length, attempt);
        await tester.enterText(
          find.byKey(
            const ValueKey(
              'company-quantity-c1000000-0000-4000-8000-000000000021',
            ),
          ),
          '2',
        );
        await tester.tap(
          find.byKey(const ValueKey('company-operation-confirm')),
        );
        await tester.pumpAndSettle();
      }
      expect(repository.lastLines!.single['dispatch_qty'], '2');
      expect(repository.dispatchKeys, hasLength(2));
      expect(repository.dispatchKeys.first, repository.dispatchKeys.last);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'handover acknowledges the signed-in beneficiary despite a different receiver',
    (tester) async {
      final repository = _CompanyRequestRepository(request: _handoverRequest);
      await _pumpApproval(
        tester,
        repository: repository,
        actorId: 'beneficiary',
        size: const Size(360, 800),
        child: const YorksV1CompanyMaterialRequestApprovalScreen(
          requestId: 'handover',
        ),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirm beneficiary handover'),
      );
      expect(repository.handoverBasis, isNull);
      expect(find.textContaining('Confirm that you received'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('company-operation-confirm')));
      await tester.pumpAndSettle();
      expect(repository.handoverBasis, 'beneficiary_confirmed');
      expect(repository.lastLines!.single['quantity'], '3');
    },
  );

  testWidgets('receiver handover stays explicitly witnessed', (tester) async {
    final repository = _CompanyRequestRepository(request: _handoverRequest);
    await _pumpApproval(
      tester,
      repository: repository,
      actorId: 'receiver',
      size: const Size(360, 800),
      child: const YorksV1CompanyMaterialRequestApprovalScreen(
        requestId: 'handover',
      ),
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Confirm beneficiary handover'),
    );
    expect(find.textContaining('handed these items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('company-operation-confirm')));
    await tester.pumpAndSettle();
    expect(repository.handoverBasis, 'authorized_receiver_witnessed');
  });

  testWidgets('company detail supports RTL and large text at 360px', (
    tester,
  ) async {
    await _pumpApproval(
      tester,
      repository: _CompanyRequestRepository(),
      size: const Size(360, 800),
      languageCode: 'ar',
      child: const YorksV1CompanyMaterialRequestApprovalScreen(
        requestId: 'request',
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/company_requests/company_detail_rtl_mobile.png',
      ),
    );
    expect(tester.takeException(), isNull);
    await _pumpApproval(
      tester,
      repository: _CompanyRequestRepository(),
      size: const Size(360, 800),
      textScale: 2,
      child: const YorksV1CompanyMaterialRequestApprovalInboxScreen(),
    );
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('Request Information'), findsWidgets);
    expect(find.text('Material items'), findsWidgets);
    expect(find.text('Request summary'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('company-request-information-toggle')),
    );
    await tester.pumpAndSettle();
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
    expect(find.text('A company request, not a project request'), findsNothing);

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

  testWidgets('submitted Company request opens its tracked detail', (
    tester,
  ) async {
    final repository = _CompanyRequestRepository();
    await _pumpComposer(
      tester,
      repository: repository,
      size: const Size(1366, 900),
    );
    await _completeDetails(tester);
    await _completeFirstLine(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-submit')),
    );
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-confirm-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Company request submitted'), findsOneWidget);
    await tester.tap(find.text('View request'));
    await tester.pumpAndSettle();
    expect(find.text('Tracked Company request'), findsOneWidget);
  });

  testWidgets('catalogue search fills the normal technical fields', (
    tester,
  ) async {
    final repository = _CompanyRequestRepository();
    await _pumpComposer(
      tester,
      repository: repository,
      size: const Size(1366, 900),
    );
    await _completeDetails(tester);
    await _enterVisible(
      tester,
      _formFieldWithLabel('Item description').first,
      'helmet',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety helmets').last);
    await tester.pumpAndSettle();
    expect(find.text('Adjustable'), findsOneWidget);
    expect(find.text('H-700'), findsOneWidget);
    expect(find.text('3M / USA'), findsOneWidget);
  });

  testWidgets('unsaved company request requires an explicit exit decision', (
    tester,
  ) async {
    final repository = _CompanyRequestRepository();
    await _pumpComposer(
      tester,
      repository: repository,
      size: const Size(1366, 900),
    );

    await _enterVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-purpose')),
      'Unfinished company request',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-cancel')),
    );

    expect(find.text('Leave this company request?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const ValueKey('company-material-request-save-and-leave'),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-keep-editing')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unfinished company request'), findsOneWidget);

    await _completeDetails(tester);
    await _completeFirstLine(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-cancel')),
    );
    final saveAndLeave = tester.widget<FilledButton>(
      find.byKey(const ValueKey('company-material-request-save-and-leave')),
    );
    expect(saveAndLeave.onPressed, isNotNull);
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-save-and-leave')),
    );
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(find.text('Private company draft saved.'), findsOneWidget);
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

  testWidgets('protected exit decision is usable on desktop and mobile', (
    tester,
  ) async {
    await _pumpComposer(
      tester,
      repository: _CompanyRequestRepository(),
      size: const Size(1366, 900),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-purpose')),
      'Unfinished company request',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-cancel')),
    );
    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile(
        'goldens/company_requests/after_company_request_exit_desktop.png',
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('company-material-request-keep-editing')),
    );
    await tester.pumpAndSettle();

    await _pumpComposer(
      tester,
      repository: _CompanyRequestRepository(),
      size: const Size(360, 800),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-purpose')),
      'Unfinished company request',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-material-request-back')),
    );
    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile(
        'goldens/company_requests/after_company_request_exit_mobile.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new request options can recover without losing the register', (
    tester,
  ) async {
    final repository = _CompanyRequestRepository()..failDraftOptions = true;
    await _pumpApproval(
      tester,
      repository: repository,
      size: const Size(360, 800),
      child: const YorksV1CompanyMaterialRequestApprovalInboxScreen(),
    );
    expect(find.text('CMR-0001'), findsOneWidget);
    expect(find.text('New request options could not load.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('company-request-new-from-inbox')),
      findsNothing,
    );
    repository.failDraftOptions = false;
    await tester.tap(
      find.byKey(const ValueKey('company-request-options-retry')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('company-request-new-from-inbox')),
      findsOneWidget,
    );
    expect(find.text('New request options could not load.'), findsNothing);
    expect(find.text('CMR-0001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approval inbox stays usable at 360px', (tester) async {
    final repository = _CompanyRequestRepository();
    await _pumpApproval(
      tester,
      repository: repository,
      size: const Size(360, 800),
      child: const YorksV1CompanyMaterialRequestApprovalInboxScreen(),
    );

    expect(find.text('Company Material Requests'), findsOneWidget);
    expect(find.text('CMR-0001'), findsOneWidget);
    expect(find.textContaining('Workshop safety stock'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/company_requests/after_company_approval_inbox_mobile.png',
      ),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('company-register-issue_history')),
    );
    await tester.pumpAndSettle();
    expect(find.text('CM-ISS-0001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assigned approver confirms one server decision', (tester) async {
    final repository = _CompanyRequestRepository();
    await _pumpApproval(
      tester,
      repository: repository,
      size: const Size(1366, 900),
      child: const YorksV1CompanyMaterialRequestApprovalScreen(
        requestId: 'c1000000-0000-4000-8000-000000000010',
      ),
    );

    expect(find.text('CMR-0001'), findsOneWidget);
    expect(find.text('Safety helmets'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/company_requests/after_company_approval_detail_desktop.png',
      ),
    );
    await tester.tap(find.byKey(const ValueKey('company-approval-approve')));
    await tester.pumpAndSettle();
    expect(find.text('Approve this company request?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('company-approval-confirm-approve')),
    );
    await tester.pumpAndSettle();

    expect(repository.decisionCalls, 1);
    expect(
      repository.lastDecision,
      YorksV1CompanyMaterialRequestDecisionType.approved,
    );
    expect(find.text('Company approval decision recorded.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fulfilment actions stay usable on desktop and mobile', (
    tester,
  ) async {
    for (final size in [const Size(1366, 900), const Size(360, 800)]) {
      final repository = _CompanyRequestRepository(
        request: _CompanyRequestRepository._fulfilmentRequest,
      );
      await _pumpApproval(
        tester,
        repository: repository,
        size: size,
        child: const YorksV1CompanyMaterialRequestApprovalScreen(
          requestId: 'c1000000-0000-4000-8000-000000000010',
        ),
      );
      expect(find.text('Fulfilment'), findsNothing);
      expect(find.text('Arrange items'), findsOneWidget);
      expect(find.text('Dispatch ready quantity'), findsWidgets);
      expect(find.text('Withdraw remaining need'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          size.width < 500
              ? 'goldens/company_requests/after_company_fulfilment_mobile.png'
              : 'goldens/company_requests/after_company_fulfilment_desktop.png',
        ),
      );
      if (size.width < 500) {
        final withdrawalButton = find.widgetWithText(
          OutlinedButton,
          'Withdraw remaining need',
        );
        await _tapVisible(tester, withdrawalButton);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('company-operation-reason')),
          'No longer required',
        );
        await tester.enterText(
          find.byKey(
            const ValueKey(
              'company-quantity-c1000000-0000-4000-8000-000000000011',
            ),
          ),
          '2',
        );
        await tester.tap(
          find.byKey(const ValueKey('company-operation-confirm')),
        );
        await tester.pumpAndSettle();
        expect(repository.withdrawalCalls, 1);
      }
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  required _CompanyRequestRepository repository,
  required Size size,
  String? draftId,
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
        yorksV1ConfigurationUnitCodesProvider.overrideWith(
          (ref) async => const ['pcs', 'set', 'm'],
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: '/yorks/material-requests/company/new',
          routes: [
            GoRoute(
              path: '/yorks/material-requests/company/new',
              builder: (_, _) =>
                  YorksV1CompanyMaterialRequestScreen(draftId: draftId),
            ),
            GoRoute(
              path: '/yorks/material-requests/company/:requestId',
              builder: (_, _) => const Scaffold(
                body: Center(child: Text('Tracked Company request')),
              ),
            ),
            GoRoute(
              path: '/yorks/material-requests',
              builder: (_, _) => const Scaffold(body: Text('MR register')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApproval(
  WidgetTester tester, {
  required _CompanyRequestRepository repository,
  required Size size,
  required Widget child,
  String? actorId,
  String languageCode = 'en',
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({'selected_language': languageCode});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        yorksV1AuthUserIdProvider.overrideWithValue(actorId),
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1CompanyMaterialRequestRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
              textDirection: languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child,
            ),
          ),
        ),
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
    _formFieldWithLabel('Item description').first,
    'Safety helmets',
  );
  await _enterVisible(tester, _formFieldWithLabel('Quantity'), '12');
  final unitField = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'company-line-unit-',
        ),
  );
  await _tapVisible(tester, unitField);
  await tester.tap(find.text('pcs').last);
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
  _CompanyRequestRepository({this.request});

  final YorksV1CompanyMaterialRequest? request;
  bool failFirstDispatch = false;
  bool failDraftOptions = false;
  final List<String> dispatchKeys = [];
  List<Map<String, Object?>>? lastLines;
  String? handoverBasis;
  @override
  Future<YorksV1CompanyMaterialRequest> dispatch({
    required String requestId,
    required int expectedVersion,
    required List<Map<String, Object?>> lines,
    required String idempotencyKey,
  }) async {
    dispatchKeys.add(idempotencyKey);
    lastLines = lines;
    if (failFirstDispatch && dispatchKeys.length == 1) {
      throw Exception('temporary outage');
    }
    return request ?? _fulfilmentRequest;
  }

  @override
  Future<YorksV1CompanyMaterialRequest> confirmHandover({
    required String requestId,
    required int expectedVersion,
    required String acknowledgementBasis,
    required List<Map<String, Object?>> lines,
    required String idempotencyKey,
  }) async {
    handoverBasis = acknowledgementBasis;
    lastLines = lines;
    return request!;
  }

  int preflightCalls = 0;
  int submitCalls = 0;
  int saveCalls = 0;
  int decisionCalls = 0;
  int withdrawalCalls = 0;
  YorksV1CompanyMaterialRequestDecisionType? lastDecision;

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
  listDraftOptions() async {
    if (failDraftOptions) throw Exception('temporary options outage');
    return const [
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
  }

  @override
  Future<List<YorksV1MaterialRequestInventorySuggestion>> searchMaterials({
    required String categoryId,
    required String responsibleUnitId,
    required String query,
  }) async => const [
    YorksV1MaterialRequestInventorySuggestion(
      id: 'c1000000-0000-4000-8000-000000000090',
      itemCode: 'PPE-001',
      description: 'Safety helmets',
      brandOrigin: '3M / USA',
      size: 'Adjustable',
      model: 'H-700',
      unit: 'pcs',
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
  ) async {
    saveCalls++;
    return _result(draft, state: 'draft');
  }

  YorksV1CompanyMaterialRequest _result(
    YorksV1CompanyMaterialRequestDraft draft, {
    required String state,
  }) => YorksV1CompanyMaterialRequest(
    id: draft.id,
    recordVersion: draft.recordVersion + 1,
    state: state,
    categoryId: draft.categoryId,
    responsibleUnitId: draft.responsibleUnitId,
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

  @override
  Future<List<YorksV1CompanyMaterialRequestApprovalInboxItem>>
  listApprovalInbox() async => [
    YorksV1CompanyMaterialRequestApprovalInboxItem(
      id: 'c1000000-0000-4000-8000-000000000010',
      requestNumber: 'CMR-0001',
      recordVersion: 2,
      state: 'awaiting_company_approval',
      categoryName: 'Personal protective equipment',
      responsibleUnitName: 'Workshop',
      purpose: 'Workshop safety stock',
      requesterDisplayName: 'Test requester',
      beneficiaryDisplayName: 'Amina Hassan',
      submittedAt: DateTime.utc(2026, 9, 18, 9, 30),
      lineCount: 1,
    ),
  ];

  @override
  Future<List<YorksV1CompanyMaterialRequestApprovalInboxItem>> listRegister(
    YorksV1CompanyMaterialRequestRegisterView view, {
    int limit = 100,
  }) async => [
    YorksV1CompanyMaterialRequestApprovalInboxItem(
      id: 'c1000000-0000-4000-8000-000000000010',
      requestNumber:
          view == YorksV1CompanyMaterialRequestRegisterView.issueHistory
          ? 'CM-ISS-0001'
          : 'CMR-0001',
      recordVersion: 2,
      state: 'awaiting_company_approval',
      categoryName: 'Personal protective equipment',
      responsibleUnitName: 'Workshop',
      purpose: 'Workshop safety stock',
      requesterDisplayName: 'Test requester',
      beneficiaryDisplayName: 'Amina Hassan',
      submittedAt: DateTime.utc(2026, 9, 18, 9, 30),
      lineCount: 1,
    ),
  ];

  @override
  Future<YorksV1CompanyMaterialRequest> getRequest(String requestId) async =>
      request ?? _approvalRequest;

  @override
  Future<YorksV1CompanyMaterialRequest> decide({
    required String requestId,
    required int expectedVersion,
    required YorksV1CompanyMaterialRequestDecisionType decision,
    required String idempotencyKey,
    String? reason,
  }) async {
    decisionCalls++;
    lastDecision = decision;
    return YorksV1CompanyMaterialRequest(
      id: _approvalRequest.id,
      recordVersion: _approvalRequest.recordVersion + 1,
      state: decision == YorksV1CompanyMaterialRequestDecisionType.approved
          ? 'approved_for_procurement'
          : decision == YorksV1CompanyMaterialRequestDecisionType.returned
          ? 'returned_for_changes'
          : 'rejected',
      categoryName: _approvalRequest.categoryName,
      responsibleUnitName: _approvalRequest.responsibleUnitName,
      purpose: _approvalRequest.purpose,
      timing: _approvalRequest.timing,
      deliveryCollectionPoint: _approvalRequest.deliveryCollectionPoint,
      beneficiary: _approvalRequest.beneficiary,
      authorizedReceiver: _approvalRequest.authorizedReceiver,
      requesterDisplayName: _approvalRequest.requesterDisplayName,
      requesterExactRole: _approvalRequest.requesterExactRole,
      lines: _approvalRequest.lines,
      requestNumber: _approvalRequest.requestNumber,
      approver: _approvalRequest.approver,
      approvalPolicyVersion: _approvalRequest.approvalPolicyVersion,
    );
  }

  @override
  Future<YorksV1CompanyMaterialRequest> withdrawRemainder({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required List<Map<String, Object?>> lines,
    required String idempotencyKey,
  }) async {
    withdrawalCalls++;
    return request ?? _fulfilmentRequest;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  static const _approvalRequest = YorksV1CompanyMaterialRequest(
    id: 'c1000000-0000-4000-8000-000000000010',
    recordVersion: 2,
    state: 'awaiting_company_approval',
    categoryName: 'Personal protective equipment',
    responsibleUnitName: 'Workshop',
    purpose: 'Workshop safety stock',
    timing: YorksV1MaterialRequestTiming.normal,
    deliveryCollectionPoint: 'Main workshop store',
    beneficiary: _person,
    authorizedReceiver: _person,
    requesterDisplayName: 'Test requester',
    requesterExactRole: 'site_engineer',
    lines: [
      YorksV1CompanyMaterialRequestLine(
        id: 'c1000000-0000-4000-8000-000000000011',
        displayOrder: 1,
        description: 'Safety helmets',
        quantity: '12',
        unit: 'pcs',
      ),
    ],
    canDecide: true,
    requestNumber: 'CMR-0001',
    approver: _approver,
    approvalPolicyVersion: 'cmr-test-v1',
  );

  static const _fulfilmentRequest = YorksV1CompanyMaterialRequest(
    id: 'c1000000-0000-4000-8000-000000000010',
    recordVersion: 4,
    state: 'ready_for_delivery',
    categoryName: 'Personal protective equipment',
    responsibleUnitName: 'Workshop',
    purpose: 'Workshop safety stock',
    timing: YorksV1MaterialRequestTiming.normal,
    deliveryCollectionPoint: 'Main workshop store',
    beneficiary: _person,
    authorizedReceiver: _person,
    requesterDisplayName: 'Test requester',
    requesterExactRole: 'site_engineer',
    lines: [
      YorksV1CompanyMaterialRequestLine(
        id: 'c1000000-0000-4000-8000-000000000011',
        displayOrder: 1,
        description: 'Safety helmets',
        quantity: '12',
        unit: 'Nos',
        arrangedQuantity: '12',
        withdrawableQuantity: '12',
      ),
    ],
    canPlan: true,
    canDispatch: true,
    canWithdrawRemainder: true,
    requestNumber: 'CMR-0001',
    approver: _approver,
    approvalPolicyVersion: 'cmr-test-v1',
    currentSupplyPlan: {
      'id': 'c1000000-0000-4000-8000-000000000020',
      'plan_version': 1,
      'lines': [
        {
          'id': 'c1000000-0000-4000-8000-000000000021',
          'request_line_id': 'c1000000-0000-4000-8000-000000000011',
          'arranged_qty': '12',
          'dispatchable_qty': '12',
        },
      ],
    },
  );
}

const _handoverRequest = YorksV1CompanyMaterialRequest(
  id: 'handover',
  recordVersion: 7,
  state: 'awaiting_beneficiary_handover',
  categoryName: 'PPE',
  responsibleUnitName: 'Workshop',
  purpose: 'Safety helmets',
  timing: YorksV1MaterialRequestTiming.normal,
  deliveryCollectionPoint: 'Workshop',
  beneficiary: YorksV1CompanyMaterialRequestPerson(
    authUserId: 'beneficiary',
    displayName: 'Amina',
  ),
  authorizedReceiver: YorksV1CompanyMaterialRequestPerson(
    authUserId: 'receiver',
    displayName: 'Receiver',
  ),
  requesterDisplayName: 'Requester',
  requesterExactRole: 'site_engineer',
  canHandover: true,
  lines: [
    YorksV1CompanyMaterialRequestLine(
      id: 'line',
      displayOrder: 1,
      description: 'Safety helmets',
      quantity: '3',
      unit: 'pcs',
    ),
  ],
  unallocatedReceiptLines: [
    {'id': 'receipt-line', 'request_line_id': 'line', 'available_qty': '3'},
  ],
);
