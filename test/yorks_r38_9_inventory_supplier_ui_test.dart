import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_inventory_supplier_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_inventory_supplier.dart';
import 'package:material_ledger/shared/models/yorks_v1_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_document_file_service_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_documents_repository_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_inventory_supplier_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_inventory_workbook_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_inventory_supplier_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_documents_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_document_file_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_inventory_workbook_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadGoldenFonts);

  late SharedPreferences preferences;
  late _FakeSupplierRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = _FakeSupplierRepository();
  });

  testWidgets(
    '390px supplier directory pins Unknown Supplier without page overflow',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      String? openedSupplier;

      await _pump(
        tester,
        preferences: preferences,
        repository: repository,
        child: YorksV1InventorySupplierDirectoryScreen(
          onExportRegister: () {},
          onImportReceipt: () {},
          onOpenSupplier: (value) => openedSupplier = value,
        ),
      );

      expect(find.text('Suppliers'), findsWidgets);
      expect(find.text('Unknown Supplier'), findsOneWidget);
      expect(find.text('Identity missing'), findsWidgets);
      expect(find.text('Export Supplier Register'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('supplier-directory-search')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Unknown Supplier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unknown Supplier'));
      await tester.pump();
      expect(openedSupplier, 'supplier-unknown');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('directory adapts to three card columns at desktop width', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));

    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      child: YorksV1InventorySupplierDirectoryScreen(
        onExportRegister: () {},
        onImportReceipt: () {},
        onOpenSupplier: (_) {},
      ),
    );

    expect(find.text('TROX Middle East LLC'), findsOneWidget);
    expect(find.text('Kitz Co.'), findsOneWidget);
    expect(find.text('Unknown Supplier'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory primary actions meet touch and keyboard access', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    var exports = 0;
    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      child: YorksV1InventorySupplierDirectoryScreen(
        onExportRegister: () => exports += 1,
        onImportReceipt: () {},
        onAddSupplier: () {},
      ),
    );

    final primary = find.byKey(const ValueKey('supplier-directory-export'));
    final size = tester.getSize(primary);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    expect(await _tabToFinder(tester, primary), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(exports, 1);
  });

  testWidgets(
    'default register export uses the complete authorized directory',
    (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final fileService = _FakeSupplierRegisterFileService();

      await _pump(
        tester,
        preferences: preferences,
        repository: repository,
        fileService: fileService,
        child: const YorksV1InventorySupplierDirectoryScreen(),
      );

      await tester.tap(find.text('Export Supplier Register'));
      await tester.pumpAndSettle();

      expect(fileService.savedSuppliers.map((entry) => entry.id), [
        'supplier-unknown',
        'supplier-kitz',
        'supplier-trox',
      ]);
      expect(fileService.savedUnitTotals, hasLength(1));
      expect(fileService.savedUnitTotals.single.unit, 'Nos');
      expect(find.text('Workbook export is ready.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('mobile supplier folder renders document cards and local tabs', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final documents = _FakeSupplierDocumentsRepository(
      classification: YorksV1DocumentClassification.operational,
      entityType: YorksV1DocumentEntityType.supplier,
      entityId: 'supplier-trox',
    );

    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      documentsRepository: documents,
      child: YorksV1InventorySupplierFolderScreen(
        supplierId: 'supplier-trox',
        initialSection: YorksV1InventorySupplierFolderSection.documents,
        onAddDocument: () {},
        onImportReceipt: () {},
        onOpenDocument: (_) {},
      ),
    );

    expect(find.text('TROX Middle East LLC'), findsOneWidget);
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('DN-TROX-8421.pdf'), findsOneWidget);
    expect(find.text('Delivery Note'), findsWidgets);
    expect(find.text('DN-TROX-8421'), findsWidgets);
    expect(find.text('Signed delivery evidence'), findsOneWidget);
    expect(find.byKey(const ValueKey('supplier-folder-tabs')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop item action opens the authoritative supplier trail', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      child: const YorksV1InventorySupplierFolderScreen(
        supplierId: 'supplier-trox',
        initialSection: YorksV1InventorySupplierFolderSection.itemsReceived,
      ),
    );

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('supplier-item-trail-item-1')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Supplier workspace could not be loaded.'), findsNothing);
    expect(find.textContaining('AIR-LIGR-0001'), findsWidgets);
    expect(find.text('8 Nos'), findsWidgets);
    expect(find.text('SRB-2026-0042'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile receipt action opens a bounded batch detail sheet', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      child: const YorksV1InventorySupplierFolderScreen(
        supplierId: 'supplier-trox',
        initialSection: YorksV1InventorySupplierFolderSection.receiptBatches,
      ),
    );

    await tester.tap(find.text('SRB-2026-0042').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('supplier-batch-add-document')),
      findsOneWidget,
    );
    expect(find.text('Linear Supply Air Grille'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop destination opens the canonical linked material request',
    (tester) async {
      await _setViewport(tester, const Size(1440, 900));
      final router = GoRouter(
        initialLocation: '/folder',
        routes: [
          GoRoute(
            path: '/folder',
            builder: (context, state) =>
                const YorksV1InventorySupplierFolderScreen(
                  supplierId: 'supplier-trox',
                  initialSection:
                      YorksV1InventorySupplierFolderSection.destinations,
                ),
          ),
          GoRoute(
            path: '/yorks/material-requests/:requestId',
            builder: (context, state) => Text(
              'request:${state.pathParameters['requestId']}',
              textDirection: TextDirection.ltr,
            ),
          ),
          GoRoute(
            path: '/yorks/projects/:projectId',
            builder: (context, state) => Text(
              'project:${state.pathParameters['projectId']}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pump(
        tester,
        preferences: preferences,
        repository: repository,
        router: router,
        child: const SizedBox.shrink(),
      );

      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('supplier-destination-destination-1')),
          )
          .onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('request:request-1'), findsOneWidget);
      expect(find.text('project:project-1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('destination falls back to its authoritative linked project', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    repository.destinationRequestId = '';
    final router = GoRouter(
      initialLocation: '/folder',
      routes: [
        GoRoute(
          path: '/folder',
          builder: (context, state) =>
              const YorksV1InventorySupplierFolderScreen(
                supplierId: 'supplier-trox',
                initialSection:
                    YorksV1InventorySupplierFolderSection.destinations,
              ),
        ),
        GoRoute(
          path: '/yorks/material-requests/:requestId',
          builder: (context, state) => Text(
            'request:${state.pathParameters['requestId']}',
            textDirection: TextDirection.ltr,
          ),
        ),
        GoRoute(
          path: '/yorks/projects/:projectId',
          builder: (context, state) => Text(
            'project:${state.pathParameters['projectId']}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      router: router,
      child: const SizedBox.shrink(),
    );

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('supplier-destination-destination-1')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('project:project-1'), findsOneWidget);
    expect(find.textContaining('request:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile destination preserves the callback override seam', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    String? openedDestination;

    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      child: YorksV1InventorySupplierFolderScreen(
        supplierId: 'supplier-trox',
        initialSection: YorksV1InventorySupplierFolderSection.destinations,
        onOpenDestination: (value) => openedDestination = value,
      ),
    );

    await tester.tap(find.text('Linear Supply Air Grille'));
    await tester.pump();

    expect(openedDestination, 'destination-1');
    expect(tester.takeException(), isNull);
  });

  for (final revision
      in <
        ({
          YorksV1DocumentClassification classification,
          YorksV1DocumentEntityType entityType,
          String entityId,
        })
      >[
        (
          classification: YorksV1DocumentClassification.commercial,
          entityType: YorksV1DocumentEntityType.supplier,
          entityId: 'supplier-trox',
        ),
        (
          classification: YorksV1DocumentClassification.adminRestricted,
          entityType: YorksV1DocumentEntityType.supplierReceiptBatch,
          entityId: 'batch-1',
        ),
      ]) {
    testWidgets(
      'new revision preserves ${revision.classification.wireValue} ${revision.entityType.wireValue} target',
      (tester) async {
        await _setViewport(tester, const Size(1440, 900));
        final documents = _FakeSupplierDocumentsRepository(
          classification: revision.classification,
          entityType: revision.entityType,
          entityId: revision.entityId,
        );
        final files = _FakeDocumentFileService();

        await _pump(
          tester,
          preferences: preferences,
          repository: repository,
          documentsRepository: documents,
          documentFileService: files,
          child: const YorksV1InventorySupplierFolderScreen(
            supplierId: 'supplier-trox',
            initialSection: YorksV1InventorySupplierFolderSection.documents,
          ),
        );

        tester
            .widget<IconButton>(
              find.byKey(
                const ValueKey('supplier-document-replace-document-1'),
              ),
            )
            .onPressed!();
        await tester.pumpAndSettle();

        final typeField = tester
            .widget<DropdownButtonFormField<YorksV1SupplierDocumentType>>(
              find.byKey(const ValueKey('supplier-document-type')),
            );
        expect(typeField.onChanged, isNull);
        expect(files.selectCalls, 0);
        await tester.enterText(
          find.byKey(const ValueKey('supplier-document-business-reference')),
          'DN-TROX-8421-REV2',
        );
        await tester.enterText(
          find.byKey(const ValueKey('supplier-document-notes')),
          'Corrected signed copy',
        );
        await tester.tap(
          find.byKey(const ValueKey('supplier-document-options-continue')),
        );
        await tester.pumpAndSettle();

        final input = documents.lastUpload;
        expect(input, isNotNull);
        expect(input!.documentId, 'document-1');
        expect(input.classification, revision.classification);
        expect(input.entityType, revision.entityType);
        expect(input.entityId, revision.entityId);
        expect(
          input.supplierDocumentType,
          YorksV1SupplierDocumentType.deliveryNote,
        );
        expect(input.businessReference, 'DN-TROX-8421-REV2');
        expect(input.supplierDocumentNotes, 'Corrected signed copy');
        expect(files.selectCalls, 1);
        expect(
          find.text('Controlled document version uploaded.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 6));
      },
    );
  }

  testWidgets('new document chooses classification and optional batch link', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final documents = _FakeSupplierDocumentsRepository(
      classification: YorksV1DocumentClassification.operational,
      entityType: YorksV1DocumentEntityType.supplier,
      entityId: 'supplier-trox',
    );
    final files = _FakeDocumentFileService();
    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      documentsRepository: documents,
      documentFileService: files,
      child: const YorksV1InventorySupplierFolderScreen(
        supplierId: 'supplier-trox',
        initialSection: YorksV1InventorySupplierFolderSection.documents,
      ),
    );

    await tester.tap(find.text('Add Document').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester
        .widget<DropdownButtonFormField<YorksV1DocumentClassification>>(
          find.byType(DropdownButtonFormField<YorksV1DocumentClassification>),
        )
        .onChanged!(YorksV1DocumentClassification.commercial);
    tester
        .widget<DropdownButtonFormField<String?>>(
          find.byKey(const ValueKey('supplier-document-receipt-batch')),
        )
        .onChanged!('batch-1');
    await tester.enterText(
      find.byKey(const ValueKey('supplier-document-business-reference')),
      'DN-TROX-9000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('supplier-document-notes')),
      'Received at Warehouse A',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('supplier-document-options-continue')),
    );
    await tester.pumpAndSettle();

    final input = documents.lastUpload;
    expect(input, isNotNull);
    expect(input!.documentId, isNull);
    expect(input.classification, YorksV1DocumentClassification.commercial);
    expect(input.entityType, YorksV1DocumentEntityType.supplierReceiptBatch);
    expect(input.entityId, 'batch-1');
    expect(
      input.supplierDocumentType,
      YorksV1SupplierDocumentType.deliveryNote,
    );
    expect(input.businessReference, 'DN-TROX-9000');
    expect(input.supplierDocumentNotes, 'Received at Warehouse A');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('invoice upload enforces commercial classification', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final documents = _FakeSupplierDocumentsRepository(
      classification: YorksV1DocumentClassification.operational,
      entityType: YorksV1DocumentEntityType.supplier,
      entityId: 'supplier-trox',
    );
    final files = _FakeDocumentFileService();
    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      documentsRepository: documents,
      documentFileService: files,
      child: const YorksV1InventorySupplierFolderScreen(
        supplierId: 'supplier-trox',
        initialSection: YorksV1InventorySupplierFolderSection.documents,
      ),
    );

    await tester.tap(find.text('Add Document').last);
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<YorksV1SupplierDocumentType>>(
          find.byKey(const ValueKey('supplier-document-type')),
        )
        .onChanged!(YorksV1SupplierDocumentType.invoice);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final classification = tester
        .widget<DropdownButtonFormField<YorksV1DocumentClassification>>(
          find.byType(DropdownButtonFormField<YorksV1DocumentClassification>),
        );
    expect(classification.onChanged, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('supplier-document-business-reference')),
      'INV-2026-0042',
    );
    await tester.tap(
      find.byKey(const ValueKey('supplier-document-options-continue')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final input = documents.lastUpload;
    expect(input, isNotNull);
    expect(input!.supplierDocumentType, YorksV1SupplierDocumentType.invoice);
    expect(input.classification, YorksV1DocumentClassification.commercial);
    expect(input.businessReference, 'INV-2026-0042');
    await tester.pump(const Duration(seconds: 6));
  });

  for (final viewport in <Size>[const Size(820, 1180), const Size(1024, 768)]) {
    testWidgets(
      'supplier overview remains bounded at ${viewport.width.toInt()}px',
      (tester) async {
        await _setViewport(tester, viewport);

        await _pump(
          tester,
          preferences: preferences,
          repository: repository,
          textScaleFactor: 1.2,
          child: YorksV1InventorySupplierFolderScreen(
            supplierId: 'supplier-trox',
            onAddDocument: () {},
            onImportReceipt: () {},
          ),
        );

        expect(find.text('Supplier position'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('supplier-folder-tabs')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('non-inventory role fails closed before loading supplier data', (
    tester,
  ) async {
    await _pump(
      tester,
      preferences: preferences,
      repository: repository,
      role: YorksV1Role.projectEngineer,
      child: const YorksV1InventorySupplierDirectoryScreen(),
    );

    expect(find.text('Restricted'), findsOneWidget);
    expect(find.text('Add Supplier'), findsNothing);
    expect(repository.directoryCalls, 0);
  });

  for (final visual in <({String name, Size size})>[
    (name: 'desktop_1440', size: const Size(1440, 1000)),
    (name: 'tablet_820', size: const Size(820, 1000)),
    (name: 'mobile_360', size: const Size(360, 900)),
  ]) {
    testWidgets('supplier directory visual ${visual.name}', (tester) async {
      await _setViewport(tester, visual.size);
      await _pump(
        tester,
        preferences: preferences,
        repository: repository,
        child: YorksV1InventorySupplierDirectoryScreen(
          onExportRegister: () {},
          onImportReceipt: () {},
          onAddSupplier: () {},
          onOpenSupplier: (_) {},
        ),
      );

      await expectLater(
        find.byType(YorksV1InventorySupplierDirectoryScreen),
        matchesGoldenFile(
          'goldens/r38_9/supplier_directory_${visual.name}.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final visual in <({String name, Size size})>[
    (name: 'desktop_1440', size: const Size(1440, 1000)),
    (name: 'mobile_360', size: const Size(360, 900)),
  ]) {
    testWidgets('Unknown Supplier folder visual ${visual.name}', (
      tester,
    ) async {
      await _setViewport(tester, visual.size);
      await _pump(
        tester,
        preferences: preferences,
        repository: repository,
        child: YorksV1InventorySupplierFolderScreen(
          supplierId: 'supplier-unknown',
          onAddDocument: () {},
          onImportReceipt: () {},
          onOpenItemTrail: (_) {},
          onOpenReceiptBatch: (_) {},
          onOpenDocument: (_) {},
          onOpenDestination: (_) {},
        ),
      );

      await expectLater(
        find.byType(YorksV1InventorySupplierFolderScreen),
        matchesGoldenFile(
          'goldens/r38_9/unknown_supplier_folder_${visual.name}.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _loadGoldenFonts() async {
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

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<bool> _tabToFinder(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (_primaryFocusIsWithin(finder)) return true;
  }
  return false;
}

bool _primaryFocusIsWithin(Finder finder) {
  final target = finder.evaluate().single;
  Element? current = FocusManager.instance.primaryFocus?.context as Element?;
  while (current != null) {
    if (identical(current, target)) return true;
    Element? parent;
    current.visitAncestorElements((ancestor) {
      parent = ancestor;
      return false;
    });
    current = parent;
  }
  return false;
}

Future<void> _pump(
  WidgetTester tester, {
  required SharedPreferences preferences,
  required YorksV1InventorySupplierRepository repository,
  required Widget child,
  YorksV1InventoryWorkbookFileService? fileService,
  YorksV1SupplierDocumentsRepository? documentsRepository,
  YorksV1DocumentFileService? documentFileService,
  GoRouter? router,
  YorksV1Role role = YorksV1Role.admin,
  double textScaleFactor = 1,
}) async {
  Widget mediaBuilder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
    child: child!,
  );
  final app = router == null
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: mediaBuilder,
          home: child,
        )
      : MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: mediaBuilder,
          routerConfig: router,
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1CurrentRoleProvider.overrideWithValue(role),
        yorksV1InventorySupplierRepositoryProvider.overrideWithValue(
          repository,
        ),
        if (fileService != null)
          yorksV1InventoryWorkbookFileServiceProvider.overrideWithValue(
            fileService,
          ),
        if (documentsRepository != null)
          yorksV1SupplierDocumentsRepositoryProvider.overrideWithValue(
            documentsRepository,
          ),
        if (documentFileService != null)
          yorksV1DocumentFileServiceProvider.overrideWithValue(
            documentFileService,
          ),
      ],
      child: app,
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSupplierRegisterFileService
    implements
        YorksV1InventoryWorkbookFileService,
        YorksV1InventorySupplierRegisterFileService {
  List<YorksV1InventorySupplierDirectoryEntry> savedSuppliers = const [];
  List<YorksV1InventorySupplierUnitTotal> savedUnitTotals = const [];

  @override
  Future<bool> saveSupplierRegister({
    required List<YorksV1InventorySupplierDirectoryEntry> suppliers,
    required List<YorksV1InventorySupplierUnitTotal> unitTotals,
    DateTime? generatedAt,
  }) async {
    savedSuppliers = suppliers;
    savedUnitTotals = unitTotals;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentFileService implements YorksV1DocumentFileService {
  int selectCalls = 0;

  @override
  Future<YorksV1SelectedDocument?> selectDocument() async {
    selectCalls += 1;
    return YorksV1SelectedDocument(
      fileName: 'revision.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  Future<bool> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async => true;

  @override
  Future<YorksV1SelectedDocument?> selectImage() async => null;
}

class _FakeSupplierDocumentsRepository
    implements YorksV1SupplierDocumentsRepository {
  _FakeSupplierDocumentsRepository({
    required YorksV1DocumentClassification classification,
    required YorksV1DocumentEntityType entityType,
    required String entityId,
  }) : workspace = YorksV1DocumentWorkspace(
         projectId: 'supplier-trox',
         documents: [
           YorksV1Document(
             id: 'document-1',
             classification: classification,
             createdAt: DateTime.utc(2026, 8, 20),
             currentVersion: YorksV1DocumentVersion(
               id: 'version-1',
               revisionNumber: 1,
               bucketId: 'supplier-documents',
               objectPath: 'supplier-trox/document-1/version-1.pdf',
               fileName: 'DN-TROX-8421.pdf',
               mimeType: 'application/pdf',
               byteSize: 3,
               sha256: 'hash',
               origin: YorksV1DocumentOrigin.uploaded,
               uploadedAt: DateTime.utc(2026, 8, 20),
               uploadedByAuthUserId: 'user-1',
               uploadedByRole: 'admin',
               uploadedByDisplayName: 'Owner',
               supplierDocumentType: YorksV1SupplierDocumentType.deliveryNote,
               businessReference: 'DN-TROX-8421',
               supplierDocumentNotes: 'Signed delivery evidence',
             ),
             links: [
               YorksV1DocumentLink(
                 id: 'link-1',
                 projectId: 'supplier-trox',
                 entityType: entityType,
                 entityId: entityId,
                 linkedAt: DateTime.utc(2026, 8, 20),
               ),
             ],
           ),
         ],
         auditEntries: const [],
       );

  final YorksV1DocumentWorkspace workspace;
  YorksV1DocumentUploadInput? lastUpload;

  @override
  Future<YorksV1DocumentWorkspace> getSupplierWorkspace(
    String supplierId,
  ) async => workspace;

  @override
  Future<YorksV1DocumentWorkspace> uploadSupplier(
    YorksV1DocumentUploadInput input,
  ) async {
    lastUpload = input;
    return workspace;
  }

  @override
  Future<Uint8List> downloadDocument({
    required String bucketId,
    required String objectPath,
  }) async => Uint8List.fromList([1, 2, 3]);
}

class _FakeSupplierRepository implements YorksV1InventorySupplierRepository {
  int directoryCalls = 0;
  String destinationRequestId = 'request-1';
  String destinationProjectId = 'project-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<YorksV1InventorySupplierDirectoryWorkspace> getDirectory({
    String? search,
    YorksV1InventorySupplierStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    directoryCalls += 1;
    final suppliers = [_trox, _kitz, _unknown]
        .where(
          (supplier) =>
              (status == null || supplier.status == status) &&
              (search == null ||
                  supplier.name.toLowerCase().contains(search.toLowerCase())),
        )
        .toList(growable: false);
    return YorksV1InventorySupplierDirectoryWorkspace(
      summary: const YorksV1InventorySupplierDirectorySummary(
        activeSuppliers: 2,
        receiptBatches: 4,
        distinctItems: 7,
        documentsMissing: 2,
        inactiveOrReview: 0,
        identityMissing: 1,
      ),
      unitTotals: const [
        YorksV1InventorySupplierUnitTotal(
          unit: 'Nos',
          acceptedQuantity: '18',
          damagedQuantity: '1',
          rejectedQuantity: '0',
        ),
      ],
      suppliers: suppliers,
      totalCount: suppliers.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<YorksV1InventorySupplierFolderWorkspace> getFolder({
    required String supplierId,
    required YorksV1InventorySupplierFolderSection section,
    int limit = 50,
    int offset = 0,
  }) async => YorksV1InventorySupplierFolderWorkspace(
    supplier: supplierId == _unknown.id ? _unknown : _trox,
    unitTotals: const [
      YorksV1InventorySupplierUnitTotal(
        unit: 'Nos',
        acceptedQuantity: '18',
        damagedQuantity: '1',
        rejectedQuantity: '0',
      ),
    ],
    items: const [
      YorksV1InventorySupplierItemReceipt(
        inventoryItemId: 'item-1',
        itemCode: 'AIR-LIGR-0001',
        description: 'Linear Supply Air Grille',
        size: '600 × 600 mm',
        modelTag: 'TROX-AIR-01',
        unit: 'Nos',
        acceptedQuantity: '10',
        currentOnHand: '8',
        receiptBatchCount: 1,
        lastReceiptAt: null,
      ),
    ],
    batches: [
      YorksV1InventorySupplierReceiptBatch(
        id: 'batch-1',
        receiptNumber: 'SRB-2026-0042',
        sourceType: 'external_supplier',
        supplierReference: 'DN-TROX-8421',
        receivedDate: DateTime.utc(2026, 8, 18),
        location: 'Warehouse A',
        status: 'completed',
        lineCount: 2,
        documentCount: 2,
        deliveredQuantity: '19',
        acceptedQuantity: '18',
        damagedQuantity: '1',
        rejectedQuantity: '0',
        unit: 'Nos',
        receivedByDisplayName: 'Ali Raza',
        createdAt: DateTime.utc(2026, 8, 18, 5, 20),
      ),
    ],
    documents: [
      YorksV1InventorySupplierDocument(
        documentId: 'document-1',
        versionId: 'document-version-1',
        fileName: 'DN-TROX-8421.pdf',
        mimeType: 'application/pdf',
        byteSize: 48214,
        revisionNumber: 1,
        classification: 'operational',
        uploadedAt: DateTime.utc(2026, 8, 18, 5, 25),
        uploadedByDisplayName: 'Ali Raza',
        receiptBatchId: 'batch-1',
      ),
    ],
    destinations: [
      YorksV1InventorySupplierDestination(
        id: 'destination-1',
        supplierId: 'supplier-trox',
        inventoryItemId: 'item-1',
        receiptLineId: 'receipt-line-1',
        receiptBatchId: 'batch-1',
        dispatchLineId: 'dispatch-line-1',
        dispatchId: 'dispatch-1',
        requestId: destinationRequestId,
        projectId: destinationProjectId,
        scopeId: 'scope-1',
        itemDescription: 'Linear Supply Air Grille',
        quantity: '4',
        unit: 'Nos',
        projectReference: 'YRA-313',
        projectName: 'Nexus Phase 1',
        scopeName: 'Common',
        requestNumber: 'YRA-313-MR001',
        dispatchNumber: 'YRA-313-DSP001',
        state: 'received',
        dispatchedAt: DateTime.utc(2026, 8, 19),
      ),
    ],
    activity: [
      YorksV1InventorySupplierActivity(
        id: 'activity-1',
        eventType: 'supplier_receipt_confirmed',
        entityType: 'supplier_receipt_batch',
        entityId: 'batch-1',
        actorDisplayName: 'Ali Raza',
        actorRole: 'procurement',
        reason: null,
        occurredAt: DateTime.utc(2026, 8, 18, 5, 25),
      ),
    ],
    totalCount: 1,
    limit: limit,
    offset: offset,
  );

  @override
  Future<YorksV1InventorySupplierItemTrailWorkspace> getItemTrail({
    required String supplierId,
    required String inventoryItemId,
    YorksV1InventorySupplierItemTrailSection section =
        YorksV1InventorySupplierItemTrailSection.receiptLines,
    int limit = 50,
    int offset = 0,
  }) async => YorksV1InventorySupplierItemTrailWorkspace(
    supplier: _trox,
    item: const YorksV1InventorySupplierTrailItem(
      id: 'item-1',
      itemCode: 'AIR-LIGR-0001',
      description: 'Linear Supply Air Grille',
      brandOrigin: 'TROX UAE',
      size: '600 × 600 mm',
      modelTag: 'TROX-AIR-01',
      unit: 'Nos',
      currentOnHand: '8',
      reservedQuantity: '2',
      availableQuantity: '6',
    ),
    receiptLines: [
      YorksV1InventorySupplierTrailReceiptLine(
        id: 'receipt-line-1',
        receiptBatchId: 'batch-1',
        receiptNumber: 'SRB-2026-0042',
        sourceType: 'external_supplier',
        supplierReference: 'DN-TROX-8421',
        receivedDate: DateTime.utc(2026, 8, 18),
        location: 'Warehouse A',
        sourceRowNumber: 2,
        deliveredQuantity: '10',
        acceptedQuantity: '10',
        damagedQuantity: '0',
        rejectedQuantity: '0',
        allocatedQuantity: '4',
        remainingAcceptedQuantity: '6',
        unit: 'Nos',
        trackingMode: 'bulk',
        serialNumber: null,
        batchLotNumber: null,
      ),
    ],
    movements: const [],
    reservations: const [],
    destinations: const [],
    provenanceGaps: const [],
    activity: const [],
    section: section,
    totalCount: 1,
    limit: limit,
    offset: offset,
  );

  @override
  Future<YorksV1InventorySupplierReceiptBatchDetailWorkspace>
  getReceiptBatchDetail({
    required String supplierId,
    required String receiptBatchId,
    YorksV1InventorySupplierReceiptBatchDetailSection section =
        YorksV1InventorySupplierReceiptBatchDetailSection.lines,
    int limit = 50,
    int offset = 0,
  }) async => YorksV1InventorySupplierReceiptBatchDetailWorkspace(
    supplier: _trox,
    batch: YorksV1InventorySupplierReceiptBatchDetailHeader(
      id: 'batch-1',
      receiptNumber: 'SRB-2026-0042',
      sourceType: 'external_supplier',
      supplierReference: 'DN-TROX-8421',
      receivedDate: DateTime.utc(2026, 8, 18),
      location: 'Warehouse A',
      status: 'completed',
      lineCount: 1,
      documentCount: 1,
      receivedByAuthUserId: 'user-1',
      receivedByDisplayName: 'Ali Raza',
      receivedByRole: 'procurement',
      createdAt: DateTime.utc(2026, 8, 18, 5, 20),
      unitTotals: const [
        YorksV1InventorySupplierUnitTotal(
          unit: 'Nos',
          acceptedQuantity: '10',
          damagedQuantity: '0',
          rejectedQuantity: '0',
        ),
      ],
    ),
    lines: const [
      YorksV1InventorySupplierReceiptBatchDetailLine(
        id: 'receipt-line-1',
        inventoryItemId: 'item-1',
        sourceRowNumber: 2,
        itemCode: 'AIR-LIGR-0001',
        description: 'Linear Supply Air Grille',
        categoryName: 'Air Terminals',
        brandOrigin: 'TROX UAE',
        size: '600 × 600 mm',
        modelTag: 'TROX-AIR-01',
        unit: 'Nos',
        deliveredQuantity: '10',
        acceptedQuantity: '10',
        damagedQuantity: '0',
        rejectedQuantity: '0',
        currentOnHand: '8',
        allocatedQuantity: '4',
        trackingMode: 'bulk',
        serialNumber: null,
        batchLotNumber: null,
        location: 'Warehouse A',
        notes: null,
      ),
    ],
    documents: [
      YorksV1InventorySupplierDocument(
        documentId: 'document-1',
        versionId: 'document-version-1',
        fileName: 'DN-TROX-8421.pdf',
        mimeType: 'application/pdf',
        byteSize: 48214,
        revisionNumber: 1,
        classification: 'operational',
        uploadedAt: DateTime.utc(2026, 8, 18, 5, 25),
        uploadedByDisplayName: 'Ali Raza',
        receiptBatchId: 'batch-1',
      ),
    ],
    activity: const [],
    section: section,
    totalCount: 1,
    limit: limit,
    offset: offset,
  );

  @override
  Future<YorksV1InventorySupplierDirectoryEntry> createSupplier(
    YorksV1InventorySupplierCreateInput input,
  ) async => _trox;

  @override
  Future<YorksV1InventorySupplierImportResult> importInventory(
    YorksV1InventorySupplierImportInput input,
  ) async => _importResult;

  @override
  Future<YorksV1InventorySupplierImportResult> importPrepared({
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async => _importResult;
}

final _trox = YorksV1InventorySupplierDirectoryEntry(
  id: 'supplier-trox',
  code: 'SUP-001',
  name: 'TROX Middle East LLC',
  description: 'Air terminals, grilles and dampers',
  status: YorksV1InventorySupplierStatus.active,
  isSystemUnknown: false,
  receiptBatchCount: 2,
  distinctItemCount: 4,
  missingDocumentCount: 0,
  reconciliationCount: 0,
  lastReceiptAt: DateTime.utc(2026, 8, 18),
  aliases: const ['TROX UAE', 'TROX'],
  recordVersion: 1,
);

final _kitz = YorksV1InventorySupplierDirectoryEntry(
  id: 'supplier-kitz',
  code: 'SUP-002',
  name: 'Kitz Co.',
  description: 'Valves and piping accessories',
  status: YorksV1InventorySupplierStatus.active,
  isSystemUnknown: false,
  receiptBatchCount: 1,
  distinctItemCount: 2,
  missingDocumentCount: 1,
  reconciliationCount: 0,
  lastReceiptAt: DateTime.utc(2026, 8, 14),
  aliases: const ['Kitz'],
  recordVersion: 1,
);

final _unknown = YorksV1InventorySupplierDirectoryEntry(
  id: 'supplier-unknown',
  code: 'SUP-UNKNOWN',
  name: 'Unknown Supplier',
  description: null,
  status: YorksV1InventorySupplierStatus.identityMissing,
  isSystemUnknown: true,
  receiptBatchCount: 1,
  distinctItemCount: 1,
  missingDocumentCount: 1,
  reconciliationCount: 3,
  lastReceiptAt: DateTime.utc(2026, 8, 20),
  aliases: const [],
  recordVersion: 1,
);

const _importResult = YorksV1InventorySupplierImportResult(
  importBatchId: 'import-1',
  rowCount: 1,
  createdItems: 0,
  updatedItems: 1,
  createdSuppliers: 0,
  createdCategories: 0,
  receiptBatches: 1,
  movements: 1,
  warningCount: 0,
  excludedCount: 0,
);
