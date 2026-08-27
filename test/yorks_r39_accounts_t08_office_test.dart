import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/features/accounts/application/accounts_office_providers.dart';
import 'package:material_ledger/features/accounts/application/accounts_office_controller.dart';
import 'package:material_ledger/features/accounts/application/accounts_providers.dart';
import 'package:material_ledger/features/accounts/data/accounts_office_repository.dart';
import 'package:material_ledger/features/accounts/data/accounts_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_office_models.dart';
import 'package:material_ledger/features/accounts/presentation/screens/yorks_accounts_office_screen.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_accounts_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/services/app_config_service.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('office repository sends one canonical paginated RPC', () async {
    final rpc = _OfficeRpcClient(_officeJson());
    final repository = YorksSupabaseAccountsOfficeRepository(
      featureFlags: _flags(),
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    final result = await repository.getRegister(
      YorksAccountsOfficeSection.claims,
      const YorksAccountsOfficeFilters(
        search: ' Marina ',
        status: ' submitted ',
        limit: 20,
        offset: 40,
      ),
    );

    expect(result.section, YorksAccountsOfficeSection.claims);
    expect(rpc.functionName, 'v1_get_accounts_office_register');
    expect(rpc.parameters, {
      'p_section': 'claims',
      'p_search': 'Marina',
      'p_status': 'submitted',
      'p_limit': 20,
      'p_offset': 40,
    });
  });

  test('office models reject imprecise JSON numeric money', () {
    final malformed = _officeJson();
    (malformed['summary'] as Map<String, dynamic>)['amount'] = 1250.5;

    expect(
      () => YorksAccountsOfficeProjection.fromRpcJson(malformed),
      throwsFormatException,
    );
  });

  test(
    'newer office filters win when responses complete out of order',
    () async {
      final first = Completer<YorksAccountsOfficeProjection>();
      final second = Completer<YorksAccountsOfficeProjection>();
      final repository = _SequencedOfficeRepository([
        Future.value(
          YorksAccountsOfficeProjection.fromRpcJson(
            _officeJson(projectName: 'Previous result'),
          ),
        ),
        first.future,
        second.future,
      ]);
      final controller = YorksAccountsOfficeController(
        section: YorksAccountsOfficeSection.claims,
        repository: repository,
      );
      addTearDown(controller.dispose);

      expect(await controller.load(), isTrue);

      final olderLoad = controller.load(
        const YorksAccountsOfficeFilters(search: 'older', limit: 20),
      );
      expect(
        controller.state.projection?.items.single.projectName,
        'Previous result',
      );
      final newerLoad = controller.load(
        const YorksAccountsOfficeFilters(search: 'newer', limit: 20),
      );
      expect(
        controller.state.projection?.items.single.projectName,
        'Previous result',
      );

      second.complete(
        YorksAccountsOfficeProjection.fromRpcJson(
          _officeJson(projectName: 'Newer result'),
        ),
      );
      expect(await newerLoad, isTrue);
      expect(
        controller.state.projection?.items.single.projectName,
        'Newer result',
      );

      first.complete(
        YorksAccountsOfficeProjection.fromRpcJson(
          _officeJson(projectName: 'Stale result'),
        ),
      );
      expect(await olderLoad, isFalse);
      expect(controller.state.filters.search, 'newer');
      expect(
        controller.state.projection?.items.single.projectName,
        'Newer result',
      );
    },
  );

  test('office statuses are localized in every configured language', () {
    const statuses = [
      'expected',
      'received',
      'reversed',
      'deposited',
      'cleared',
      'bounced',
      'replaced',
      'current',
      'active',
      'archived',
      'recorded',
    ];
    for (final language in const [
      AppLanguage.arabic,
      AppLanguage.urdu,
      AppLanguage.hindi,
    ]) {
      for (final status in statuses) {
        expect(
          YorksV1AccountsStrings.text(language, 'status_$status'),
          isNot('status_$status'),
        );
      }
    }
  });

  test('due schedule records open their matching project account tab', () {
    YorksAccountsOfficeItem item(String recordKind) {
      final json = Map<String, dynamic>.from(
        (_officeJson()['items'] as List<dynamic>).single
            as Map<String, dynamic>,
      );
      json['record_kind'] = recordKind;
      return YorksAccountsOfficeItem.fromRpcJson(json);
    }

    expect(
      yorksAccountsOfficeItemRoute(
        YorksAccountsOfficeSection.dueSchedule,
        item('client_invoice_due'),
      ),
      RoutePaths.yorksV1ProjectAccountsInvoicesPath('project-1'),
    );
    expect(
      yorksAccountsOfficeItemRoute(
        YorksAccountsOfficeSection.dueSchedule,
        item('pdc_due'),
      ),
      RoutePaths.yorksV1ProjectAccountsReceiptsPdcPath('project-1'),
    );
    expect(
      yorksAccountsOfficeItemRoute(
        YorksAccountsOfficeSection.dueSchedule,
        item('supplier_bill_due'),
      ),
      RoutePaths.yorksV1ProjectAccountsSupplierBillsPath('project-1'),
    );
  });

  testWidgets('office claims render a dense desktop register', (tester) async {
    await _pumpOffice(tester, const Size(1366, 900));

    expect(find.text('Claims & Client Invoices'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('CLM-00048'), findsWidgets);
    expect(find.text('AED 1,702,910.00'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(YorksAccountsOfficeScreen),
      matchesGoldenFile(
        'goldens/yorks_r39_accounts_t08_office_claims_desktop.png',
      ),
    );
  });

  testWidgets('office claims become touch cards at 390px', (tester) async {
    await _pumpOffice(tester, const Size(390, 844));

    expect(find.byType(DataTable), findsNothing);
    await expectLater(
      find.byType(YorksAccountsOfficeScreen),
      matchesGoldenFile(
        'goldens/yorks_r39_accounts_t08_office_claims_mobile.png',
      ),
    );
    await tester.scrollUntilVisible(
      find.text('CLM-00048'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('CLM-00048'), findsOneWidget);
    expect(find.textContaining('Marina Gate Tower 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('office claims stay readable at tablet portrait width', (
    tester,
  ) async {
    await _pumpOffice(tester, const Size(900, 1024));

    expect(find.text('Claims & Client Invoices'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(YorksAccountsOfficeScreen),
      matchesGoldenFile(
        'goldens/yorks_r39_accounts_t08_office_claims_tablet.png',
      ),
    );
  });

  testWidgets('office refresh keeps confirmed rows visible with progress', (
    tester,
  ) async {
    final refresh = Completer<YorksAccountsOfficeProjection>();
    final repository = _SequencedOfficeRepository([
      Future.value(YorksAccountsOfficeProjection.fromRpcJson(_officeJson())),
      refresh.future,
    ]);
    await _pumpOffice(tester, const Size(900, 1024), repository: repository);

    await tester.enterText(find.byType(TextField), 'Marina');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('CLM-00048'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    refresh.complete(
      YorksAccountsOfficeProjection.fromRpcJson(
        _officeJson(projectName: 'Filtered project'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Filtered project'), findsWidgets);
  });
}

Future<void> _pumpOffice(
  WidgetTester tester,
  Size size, {
  YorksAccountsOfficeRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appVersionProvider.overrideWithValue(
          const AppVersionInfo(version: '1.0.0', build: 1),
        ),
        yorksV1AuthUserIdProvider.overrideWithValue('accountant-1'),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.accountant),
        yorksAccountsPermissionEpochProvider.overrideWith(
          (ref) => (
            revision: 1,
            trusted: true,
            stale: false,
            revisionSignalHealthy: true,
          ),
        ),
        yorksAccountsOfficeRepositoryProvider.overrideWithValue(
          repository ??
              _OfficeRepository(
                YorksAccountsOfficeProjection.fromRpcJson(_officeJson()),
              ),
        ),
      ],
      child: const MaterialApp(
        home: YorksAccountsOfficeScreen(
          section: YorksAccountsOfficeSection.claims,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _OfficeRepository implements YorksAccountsOfficeRepository {
  const _OfficeRepository(this.projection);

  final YorksAccountsOfficeProjection projection;

  @override
  Future<YorksAccountsOfficeProjection> getRegister(
    YorksAccountsOfficeSection section,
    YorksAccountsOfficeFilters filters,
  ) async => projection;
}

final class _SequencedOfficeRepository
    implements YorksAccountsOfficeRepository {
  _SequencedOfficeRepository(this.responses);

  final List<Future<YorksAccountsOfficeProjection>> responses;
  var _index = 0;

  @override
  Future<YorksAccountsOfficeProjection> getRegister(
    YorksAccountsOfficeSection section,
    YorksAccountsOfficeFilters filters,
  ) => responses[_index++];
}

final class _OfficeRpcClient implements YorksAccountsRpcClient {
  _OfficeRpcClient(this.response);

  final Map<String, dynamic> response;
  String? functionName;
  Map<String, Object?>? parameters;

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    this.functionName = functionName;
    this.parameters = parameters;
    return response;
  }
}

YorksV1FeatureFlags _flags() => const YorksV1FeatureFlags(
  foundation: true,
  projects: true,
  boq: true,
  excel: true,
  requests: true,
  arrangement: true,
  logistics: true,
  returnsDocuments: true,
  documents: true,
  accounts: true,
);

Map<String, dynamic> _officeJson({
  String projectName = 'Marina Gate Tower 2',
}) => {
  'schema_version': 8,
  'section': 'claims',
  'total': 1,
  'limit': 20,
  'offset': 40,
  'summary': {
    'amount': '1702910.00',
    'secondary_amount': '1180450.00',
    'balance_amount': '522460.00',
    'action_count': 1,
  },
  'items': [
    {
      'record_id': 'claim-48',
      'project_id': 'project-1',
      'project_reference': 'YRA-313',
      'project_name': projectName,
      'party': 'Al Reem Retail Plaza',
      'reference': 'CLM-00048',
      'secondary_reference': 'INV-0048',
      'status': 'submitted',
      'amount': '1702910.00',
      'secondary_amount': '1180450.00',
      'balance_amount': '522460.00',
      'event_date': '2026-08-01',
      'due_date': '2026-08-26',
      'occurred_at': '2026-08-12T09:45:00Z',
      'action_required': true,
      'record_kind': 'claim',
      'currency_code': 'AED',
      'metadata': <String, dynamic>{'record_version': 2},
    },
  ],
};
