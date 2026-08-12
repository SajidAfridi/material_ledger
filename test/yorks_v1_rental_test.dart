import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/rentals/presentation/screens/yorks_v1_rental_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_boq_workbook.dart';
import 'package:material_ledger/shared/models/yorks_v1_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_rental.dart';
import 'package:material_ledger/shared/models/yorks_v1_rental_workbook.dart';
import 'package:material_ledger/shared/providers/yorks_v1_documents_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_rental_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_documents_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_rental_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_rental_workbook_service.dart';

void main() {
  setUpAll(() async {
    final nexus = FontLoader('NexusSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final cache = _flutterCacheDirectory();
    final icons = await File(
      '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons)));
    await Future.wait([nexus.load(), arabic.load(), materialIcons.load()]);
  });

  group('R38.4 rental workbook contract', () {
    const codec = YorksV1RentalWorkbookCodec();

    test('template contains the five exact controlled worksheets', () {
      final workbook = const YorksV1BoqWorkbookCodec().decode(
        bytes: codec.buildImportTemplate(),
        fileName: 'Yorks_Rental_Properties_Import.xlsx',
      );

      expect(
        workbook.sheets.map((sheet) => sheet.name),
        containsAllInOrder(const [
          YorksV1RentalWorkbookCodec.instructionsSheet,
          YorksV1RentalWorkbookCodec.propertySheet,
          YorksV1RentalWorkbookCodec.paymentSheet,
          YorksV1RentalWorkbookCodec.chequeSheet,
          YorksV1RentalWorkbookCodec.listsSheet,
        ]),
      );
      expect(
        _sheet(workbook, YorksV1RentalWorkbookCodec.propertySheet).rows.first,
        YorksV1RentalWorkbookCodec.propertyHeaders,
      );
      expect(
        _sheet(workbook, YorksV1RentalWorkbookCodec.paymentSheet).rows.first,
        YorksV1RentalWorkbookCodec.paymentHeaders,
      );
      expect(
        _sheet(workbook, YorksV1RentalWorkbookCodec.chequeSheet).rows.first,
        YorksV1RentalWorkbookCodec.chequeHeaders,
      );
    });

    test('preview classifies Create/Update and never mutates repository', () {
      final repository = _RentalFixtureRepository();
      final bytes = _workbook({
        YorksV1RentalWorkbookCodec.instructionsSheet: const [
          ['Instructions'],
        ],
        YorksV1RentalWorkbookCodec.propertySheet: [
          YorksV1RentalWorkbookCodec.propertyHeaders,
          _propertyRow(action: 'Update', unitCode: 'RU-004'),
          _propertyRow(action: 'Create', unitCode: 'RU-005'),
        ],
        YorksV1RentalWorkbookCodec.paymentSheet: [
          YorksV1RentalWorkbookCodec.paymentHeaders,
        ],
        YorksV1RentalWorkbookCodec.chequeSheet: [
          YorksV1RentalWorkbookCodec.chequeHeaders,
        ],
        YorksV1RentalWorkbookCodec.listsSheet: const [
          ['Import Action'],
        ],
      });

      final preview = codec.preview(
        selected: YorksV1RentalSelectedWorkbook(
          fileName: 'rentals.xlsx',
          bytes: bytes,
        ),
        portfolio: rentalPortfolioFixture,
      );

      expect(preview.canConfirm, isTrue);
      expect(preview.updatedPropertyCount, 1);
      expect(preview.newPropertyCount, 1);
      expect(repository.importCalls, isEmpty);
      expect(preview.toRpcPayload()['properties'], hasLength(2));
    });

    test('duplicate payment identity blocks confirm before server commit', () {
      final payment = [
        'RU-004',
        '2026-08-01',
        '14000',
        '2026-08-11',
        'Bank Transfer',
        'BANK-101',
        'August rent',
      ];
      final preview = codec.preview(
        selected: YorksV1RentalSelectedWorkbook(
          fileName: 'duplicate-payment.xlsx',
          bytes: _workbook({
            YorksV1RentalWorkbookCodec.instructionsSheet: const [
              ['Instructions'],
            ],
            YorksV1RentalWorkbookCodec.propertySheet: [
              YorksV1RentalWorkbookCodec.propertyHeaders,
            ],
            YorksV1RentalWorkbookCodec.paymentSheet: [
              YorksV1RentalWorkbookCodec.paymentHeaders,
              payment,
              payment,
            ],
            YorksV1RentalWorkbookCodec.chequeSheet: [
              YorksV1RentalWorkbookCodec.chequeHeaders,
            ],
            YorksV1RentalWorkbookCodec.listsSheet: const [
              ['Import Action'],
            ],
          }),
        ),
        portfolio: rentalPortfolioFixture,
      );

      expect(preview.canConfirm, isFalse);
      expect(
        preview.issues.map((issue) => issue.message),
        contains('The same rent receipt is duplicated in this workbook.'),
      );
    });

    test('all five export registers produce readable Excel workbooks', () {
      final data = <String, dynamic>{
        'properties': [
          {'Unit Code': 'RU-004', 'Property': 'Mussafah Shop 04'},
        ],
        'periods': [
          {'Unit Code': 'RU-004', 'Period': '2026-08'},
        ],
        'payments': [
          {'Unit Code': 'RU-004', 'Amount': 14000},
        ],
        'cheques': [
          {'Unit Code': 'RU-004', 'Cheque No.': 'PDC-001'},
        ],
        'lease_expiry': [
          {'Unit Code': 'RU-004', 'Lease End': '2027-07-31'},
        ],
      };

      for (final register in YorksV1RentalExportRegister.values) {
        final bytes = codec.buildExport(register: register, data: data);
        final workbook = const YorksV1BoqWorkbookCodec().decode(
          bytes: bytes,
          fileName: '${register.name}.xlsx',
        );
        expect(workbook.sheets, hasLength(1));
        expect(workbook.sheets.single.rows, hasLength(2));
      }
    });
  });

  for (final evidence in <({String suffix, Size size})>[
    (suffix: 'desktop', size: const Size(1366, 768)),
    (suffix: 'mobile', size: const Size(360, 800)),
  ]) {
    testWidgets('R38.4 rental register — ${evidence.size}', (tester) async {
      await _setViewport(tester, evidence.size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yorksV1RentalRepositoryProvider.overrideWithValue(
              _RentalFixtureRepository(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1RentalDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rental Properties'), findsWidgets);
      expect(find.text('Property & Rent Register'), findsOneWidget);
      expect(find.text('Mussafah Shop 04'), findsOneWidget);
      expect(find.text('AED 14,000.00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r38_4/rental_register_${evidence.suffix}.png',
        ),
      );
    });

    testWidgets('R38.4 property register — ${evidence.size}', (tester) async {
      await _setViewport(tester, evidence.size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yorksV1RentalRepositoryProvider.overrideWithValue(
              _RentalFixtureRepository(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1RentalDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Property register'));
      await tester.pumpAndSettle();

      expect(find.text('Property & Rent Register'), findsOneWidget);
      expect(find.textContaining('RU-004'), findsWidgets);
      expect(find.text('AED 14,000.00'), findsWidgets);
      if (evidence.size.width >= 1040) {
        expect(find.textContaining('TC-RU-004-2026'), findsOneWidget);
        expect(find.text('NEXT CDC / PDC'), findsOneWidget);
        expect(find.text('LEASE'), findsOneWidget);
      } else {
        expect(find.textContaining('Mussafah M-37'), findsOneWidget);
        expect(find.text('OUTSTANDING'), findsWidgets);
        expect(find.text('LEASE END'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r38_4/rental_property_register_${evidence.suffix}.png',
        ),
      );
    });

    testWidgets('R38.4 rental property detail — ${evidence.size}', (
      tester,
    ) async {
      await _setViewport(tester, evidence.size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yorksV1RentalRepositoryProvider.overrideWithValue(
              _RentalFixtureRepository(),
            ),
            yorksV1RentalDocumentsRepositoryProvider.overrideWithValue(
              const _RentalFixtureDocumentsRepository(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1RentalPropertyScreen(propertyId: 'property-4'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mussafah Shop 04'), findsOneWidget);
      expect(find.text('Current Rent Position'), findsOneWidget);
      expect(find.text('Tenant & Lease'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r38_4/rental_detail_${evidence.suffix}.png'),
      );
    });
  }

  testWidgets('lease documents use the controlled Yorks document workspace', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yorksV1RentalRepositoryProvider.overrideWithValue(
            _RentalFixtureRepository(),
          ),
          yorksV1RentalDocumentsRepositoryProvider.overrideWithValue(
            const _RentalFixtureDocumentsRepository(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const YorksV1RentalPropertyScreen(propertyId: 'property-4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    expect(find.text('Lease Documents'), findsOneWidget);
    expect(find.text('No lease documents attached'), findsOneWidget);
    expect(find.text('Controlled document boundary'), findsOneWidget);
    expect(find.textContaining('Private, versioned'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Directory _flutterCacheDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 8; level++) {
    if (directory.path.endsWith('${Platform.pathSeparator}cache')) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate the Flutter cache from the test runner');
}

YorksV1BoqWorkbookSheet _sheet(
  YorksV1BoqParsedWorkbook workbook,
  String name,
) => workbook.sheets.singleWhere((sheet) => sheet.name == name);

List<String> _propertyRow({required String action, required String unitCode}) {
  return [
    action,
    unitCode,
    unitCode == 'RU-004' ? 'Mussafah Shop 04' : 'Mussafah Shop 05',
    'Shop',
    unitCode == 'RU-004' ? 'M37-S04' : 'M37-S05',
    'Mussafah M-37',
    'Vacant',
    '',
    '',
    '',
    '',
    'TC-$unitCode-2026',
    'Tenancy Contract',
    'Draft',
    '',
    '',
    '',
    '14000',
    '1',
    '5',
    '0',
    'Bank Transfer',
    'Monthly',
    '12',
    '5',
    '90',
    '',
  ];
}

Uint8List _workbook(Map<String, List<List<String>>> sheets) {
  final names = sheets.keys.toList();
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('[Content_Types].xml', _contentTypes(names.length)),
    )
    ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
    ..addFile(ArchiveFile.string('xl/workbook.xml', _workbookXml(names)))
    ..addFile(
      ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        _workbookRelationships(names.length),
      ),
    );
  for (var index = 0; index < names.length; index++) {
    archive.addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet${index + 1}.xml',
        _sheetXml(sheets[names[index]]!),
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _sheetXml(List<List<String>> rows) {
  final out = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var row = 0; row < rows.length; row++) {
    out.write('<row r="${row + 1}">');
    for (var column = 0; column < rows[row].length; column++) {
      out.write(
        '<c r="${_column(column)}${row + 1}" t="inlineStr"><is><t xml:space="preserve">${_xml(rows[row][column])}</t></is></c>',
      );
    }
    out.write('</row>');
  }
  out.write('</sheetData></worksheet>');
  return out.toString();
}

String _contentTypes(int count) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${[for (var index = 1; index <= count; index++) '<Override PartName="/xl/worksheets/sheet$index.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>';

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>';

String _workbookXml(List<String> names) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${[for (var index = 0; index < names.length; index++) '<sheet name="${_xml(names[index])}" sheetId="${index + 1}" r:id="rId${index + 1}"/>'].join()}</sheets></workbook>';

String _workbookRelationships(int count) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var index = 1; index <= count; index++) '<Relationship Id="rId$index" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$index.xml"/>'].join()}</Relationships>';

String _column(int index) {
  var value = index + 1;
  var result = '';
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final rentalPortfolioFixture = YorksV1RentalPortfolio.fromJson({
  'as_of': '2026-08-11T08:31:00Z',
  'summary': {
    'total_properties': 2,
    'occupied': 1,
    'monthly_rent_roll': 22000,
    'collected_this_month': 8000,
    'outstanding': 14000,
    'security_deposits': 16000,
    'expiring_within_90': 1,
    'cheque_attention': 1,
  },
  'properties': [
    {
      'id': 'property-4',
      'unit_code': 'RU-004',
      'property_name': 'Mussafah Shop 04',
      'property_type': 'Shop',
      'municipality_number': 'M37-S04',
      'location': 'Mussafah M-37',
      'occupancy_state': 'vacant',
      'is_archived': false,
      'record_version': 3,
      'contract_number': 'TC-RU-004-2026',
      'contract_type': 'Tenancy Contract',
      'contract_status': 'Draft',
      'monthly_rent': 14000,
      'security_deposit': 0,
      'monthly_due_day': 1,
      'grace_period_days': 5,
      'default_payment_method': 'Bank Transfer',
      'annual_escalation_percent': 5,
      'renewal_notice_days': 90,
      'current_due': 14000,
      'current_paid': 0,
      'outstanding': 14000,
    },
    {
      'id': 'property-1',
      'unit_code': 'RU-001',
      'property_name': 'Al Dhafra Shop 12',
      'property_type': 'Shop',
      'municipality_number': 'AD-887-321',
      'location': 'Al Dhafra, Abu Dhabi',
      'occupancy_state': 'occupied',
      'is_archived': false,
      'record_version': 5,
      'lease_id': 'lease-1',
      'tenant_name': 'Gulf Air Ducts Co.',
      'contract_number': 'CTR-2026-001',
      'contract_type': 'Lease',
      'contract_status': 'Active',
      'lease_start': '2026-01-01',
      'lease_end': '2026-12-31',
      'monthly_rent': 8000,
      'security_deposit': 16000,
      'monthly_due_day': 5,
      'grace_period_days': 5,
      'default_payment_method': 'PDC',
      'annual_escalation_percent': 5,
      'renewal_notice_days': 60,
      'current_due': 8000,
      'current_paid': 8000,
      'outstanding': 0,
      'next_cheque_date': '2026-09-05',
      'next_cheque_number': 'PDC-009',
    },
  ],
  'recent_payments': [
    {
      'id': 'receipt-1',
      'property_id': 'property-1',
      'period_id': 'period-1',
      'period_month': '2026-08-01',
      'amount_received': 8000,
      'payment_date': '2026-08-05',
      'payment_method': 'PDC',
      'reference': 'PDC-008',
      'unit_code': 'RU-001',
      'property_name': 'Al Dhafra Shop 12',
    },
  ],
  'cheques': [
    {
      'id': 'cheque-1',
      'property_id': 'property-1',
      'lease_id': 'lease-1',
      'period_id': 'period-1',
      'cheque_number': 'PDC-009',
      'cheque_type': 'PDC',
      'bank_name': 'ADCB',
      'cheque_date': '2026-09-05',
      'amount': 8000,
      'status': 'received',
      'record_version': 1,
      'unit_code': 'RU-001',
      'property_name': 'Al Dhafra Shop 12',
      'tenant_name': 'Gulf Air Ducts Co.',
    },
  ],
});

final rentalPropertyDetailFixture = YorksV1RentalPropertyDetail.fromJson({
  'property': {
    'id': 'property-4',
    'unit_code': 'RU-004',
    'property_name': 'Mussafah Shop 04',
    'property_type': 'Shop',
    'municipality_number': 'M37-S04',
    'location': 'Mussafah M-37',
    'occupancy_state': 'vacant',
    'is_archived': false,
    'record_version': 3,
    'updated_at': '2026-08-11T08:31:00Z',
  },
  'lease': {
    'id': 'lease-4',
    'contract_number': 'TC-RU-004-2026',
    'contract_type': 'Tenancy Contract',
    'contract_status': 'Draft',
    'monthly_rent': 14000,
    'security_deposit': 0,
    'monthly_due_day': 1,
    'grace_period_days': 5,
    'default_payment_method': 'Bank Transfer',
    'payment_frequency': 'Monthly',
    'contract_cheque_count': 12,
    'annual_escalation_percent': 5,
    'renewal_notice_days': 90,
  },
  'periods': [
    {
      'id': 'period-4',
      'period_month': '2026-08-01',
      'due_date': '2026-08-01',
      'amount_due': 14000,
      'amount_paid': 0,
      'balance': 14000,
      'status': 'due',
    },
  ],
  'receipts': [],
  'cheques': [],
  'activity': [
    {
      'id': 'activity-4',
      'event_type': 'rental_property_created',
      'actor_role': 'admin',
      'actor_name': 'Faisal Ahmed',
      'occurred_at': '2026-08-11T08:31:00Z',
    },
  ],
});

class _RentalFixtureRepository implements YorksV1RentalRepository {
  final importCalls = <Map<String, Object?>>[];

  @override
  Future<YorksV1RentalPortfolio> getPortfolio() async => rentalPortfolioFixture;

  @override
  Future<YorksV1RentalPropertyDetail> getProperty(String propertyId) async =>
      rentalPropertyDetailFixture;

  @override
  Future<YorksV1RentalPropertyDetail> saveProperty(
    YorksV1RentalPropertyInput input, {
    required int? expectedVersion,
    required String idempotencyKey,
  }) async => rentalPropertyDetailFixture;

  @override
  Future<void> recordPayment({
    required String periodId,
    required double amount,
    required DateTime paymentDate,
    required String paymentMethod,
    required String? reference,
    required String? note,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> saveCheque({
    required Map<String, Object?> payload,
    required int? expectedVersion,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> transitionCheque({
    required String chequeId,
    required int expectedVersion,
    required YorksV1RentalChequeStatus nextStatus,
    required String? reason,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> archiveProperty({
    required String propertyId,
    required int expectedVersion,
    required String reason,
    required String idempotencyKey,
  }) async {}

  @override
  Future<Map<String, dynamic>> getExportData() async => const {};

  @override
  Future<void> importWorkbook({
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    importCalls.add({...payload, 'idempotency_key': idempotencyKey});
  }
}

class _RentalFixtureDocumentsRepository
    implements YorksV1RentalDocumentsRepository {
  const _RentalFixtureDocumentsRepository();

  @override
  Future<YorksV1DocumentWorkspace> getRentalWorkspace(String propertyId) async {
    return YorksV1DocumentWorkspace(
      projectId: propertyId,
      documents: const [],
      auditEntries: const [],
    );
  }

  @override
  Future<YorksV1DocumentWorkspace> uploadRental(
    YorksV1DocumentUploadInput input,
  ) => getRentalWorkspace(input.projectId);

  @override
  Future<Uint8List> downloadDocument({
    required String bucketId,
    required String objectPath,
  }) async => Uint8List(0);
}
