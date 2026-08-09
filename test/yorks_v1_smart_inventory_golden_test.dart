import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_inventory_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_repository_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final evidence in <({String name, Size size})>[
    (name: 'smart_inventory_desktop.png', size: const Size(1366, 768)),
    (name: 'smart_inventory_mobile.png', size: const Size(360, 800)),
  ]) {
    testWidgets('R38.3 smart warehouse — ${evidence.size}', (tester) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1LogisticsRepositoryProvider.overrideWithValue(
              const _GoldenInventoryRepository(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Warehouse Inventory'), findsOneWidget);
      expect(find.text('Stock quantity remains controlled'), findsOneWidget);
      expect(find.text('Incoming stock'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/r35/${evidence.name}'),
      );
    });
  }

  for (final evidence in <({String suffix, Size size})>[
    (suffix: 'desktop', size: const Size(1366, 768)),
    (suffix: 'mobile', size: const Size(360, 800)),
  ]) {
    testWidgets('R38.3 stock chooser and category create — ${evidence.size}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1LogisticsRepositoryProvider.overrideWithValue(
              const _GoldenInventoryRepository(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const YorksV1InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add / Receive stock').first);
      await tester.pumpAndSettle();
      expect(find.text('Create inventory item'), findsOneWidget);
      expect(find.text('Receive or adjust existing stock'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/smart_inventory_chooser_${evidence.suffix}.png',
        ),
      );

      await tester.tap(find.text('Create inventory item'));
      await tester.pumpAndSettle();
      expect(find.text('Item identity'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Start typing a category',
        ),
        'round ac terminal',
      );
      await tester.pumpAndSettle();
      expect(find.text('Air Terminals › Round'), findsOneWidget);
      expect(find.textContaining('Create “Round AC Terminal”'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/r35/smart_inventory_create_${evidence.suffix}.png',
        ),
      );
    });
  }
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

class _GoldenInventoryRepository implements YorksV1LogisticsRepository {
  const _GoldenInventoryRepository();

  @override
  Future<YorksV1InventoryWorkspace> getInventory({String? search}) async =>
      _workspace;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _workspace = YorksV1InventoryWorkspace(
  items: const [
    YorksV1LogisticsInventoryItem(
      id: 'item-1',
      itemCode: 'WH-DCT-001',
      description: 'GI duct sheet 24 gauge',
      categoryId: 'category-duct',
      categoryName: 'Ductwork & Accessories',
      brandOrigin: 'UAE',
      unit: 'Nos',
      minimumStock: '4',
      locationBin: 'A-01',
      isActive: true,
      onHandQuantity: '12',
      reservedQuantity: '3',
      availableQuantity: '9',
      recordVersion: 3,
    ),
    YorksV1LogisticsInventoryItem(
      id: 'item-2',
      itemCode: 'WH-AT-001',
      description: 'Round air diffuser 300 mm',
      categoryId: 'category-round',
      categoryName: 'Air Terminals - Round',
      categoryPath: 'Air Terminals › Round',
      brandOrigin: 'Yorks',
      unit: 'Nos',
      minimumStock: '3',
      locationBin: 'B-03',
      isActive: true,
      onHandQuantity: '4',
      reservedQuantity: '2',
      availableQuantity: '2',
      recordVersion: 2,
    ),
    YorksV1LogisticsInventoryItem(
      id: 'item-3',
      itemCode: 'WH-FAN-001',
      description: 'Inline ventilation fan 250 mm',
      categoryId: 'category-fan',
      categoryName: 'Fans & Equipment',
      brandOrigin: 'Systemair',
      unit: 'Nos',
      minimumStock: '1',
      locationBin: 'C-07',
      isActive: true,
      onHandQuantity: '0',
      reservedQuantity: '0',
      availableQuantity: '0',
      recordVersion: 1,
    ),
  ],
  categories: [
    _category(
      'category-round',
      'Round',
      1,
      parentCategoryId: 'category-air-terminals',
      parentName: 'Air Terminals',
      aliases: const ['Round AC Terminal'],
    ),
    _category('category-air-terminals', 'Air Terminals', 0),
    _category('category-duct', 'Ductwork & Accessories', 1),
    _category('category-fan', 'Fans & Equipment', 1),
    _category('category-general', 'General & Custom', 0),
  ],
  recentMovements: [
    YorksV1InventoryMovement(
      id: 'movement-1',
      inventoryItemId: 'item-1',
      itemCode: 'WH-DCT-001',
      itemDescription: 'GI duct sheet 24 gauge',
      unit: 'Nos',
      movementType: 'opening_balance',
      quantityDelta: '12',
      onHandAfterQuantity: '12',
      reason: 'Verified opening balance',
      actorDisplayName: 'Ali Raza',
      createdAt: DateTime.utc(2026, 8, 9, 10, 30),
    ),
    YorksV1InventoryMovement(
      id: 'movement-2',
      inventoryItemId: 'item-2',
      itemCode: 'WH-AT-001',
      itemDescription: 'Round air diffuser 300 mm',
      unit: 'Nos',
      movementType: 'adjustment',
      quantityDelta: '-2',
      onHandAfterQuantity: '4',
      reason: 'Issued to approved dispatch',
      actorDisplayName: 'Ali Raza',
      createdAt: DateTime.utc(2026, 8, 9, 9, 10),
    ),
  ],
  reservations: [
    YorksV1InventoryReservation(
      id: 'reservation-1',
      inventoryItemId: 'item-1',
      itemCode: 'WH-DCT-001',
      itemDescription: 'GI duct sheet 24 gauge',
      unit: 'Nos',
      requestId: 'request-1',
      requestNumber: 'YRA322-MR101',
      projectName: 'Al Dhafra Grid Substation HVAC Works',
      scopeName: 'Common / All Buildings',
      reservedQuantity: '3',
      remainingQuantity: '3',
      state: 'active',
      createdAt: DateTime.utc(2026, 8, 9, 8),
    ),
  ],
  summary: const YorksV1InventorySummary(
    totalActiveItems: 3,
    lowStockCount: 1,
    outOfStockCount: 1,
    reservedCount: 2,
    incomingCount: 0,
  ),
);

YorksV1InventoryCategory _category(
  String id,
  String name,
  int itemCount, {
  String? parentCategoryId,
  String? parentName,
  List<String> aliases = const [],
}) => YorksV1InventoryCategory(
  id: id,
  name: name,
  isSystem: true,
  isActive: true,
  recordVersion: 1,
  itemCount: itemCount,
  parentCategoryId: parentCategoryId,
  parentName: parentName,
  aliases: aliases,
  createdByDisplayName: 'Yorks standard',
  createdAt: DateTime.utc(2026, 8, 9),
);
