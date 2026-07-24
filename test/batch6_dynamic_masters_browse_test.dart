import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/materials/presentation/screens/browse_materials_screen.dart';
import 'package:material_ledger/shared/models/material_item.dart';
import 'package:material_ledger/shared/models/material_master.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_master_provider.dart';
import 'package:material_ledger/shared/providers/permissions_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/services/material_catalogue_csv_export.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('deterministic legacy master migration', () {
    test('maps every legacy category into the approved HVAC rail', () {
      final ids = {
        for (final category in MaterialCategory.values)
          categoryMasterIdForLegacyLabel(category.label),
      };

      expect(ids, hasLength(8));
      expect(ids.every((id) => id.startsWith('cat-')), isTrue);
      expect(
        categoryMasterIdForLegacyLabel('Air Inlet & Outlet'),
        'cat-air-terminals',
      );
      expect(categoryMasterIdForLegacyLabel('Valves'), 'cat-piping-drain');
    });

    test('approved equivalents fold and unmatched units remain custom', () {
      expect(unitMasterIdForLegacySymbol('pcs'), 'unit-nos');
      expect(unitMasterIdForLegacySymbol('boxes'), 'unit-box');
      expect(unitMasterIdForLegacySymbol('ft'), 'custom-unit-ft');
      expect(unitMasterIdForLegacySymbol('m³'), 'custom-unit-m');
    });

    test(
      'legacy JSON gains stable IDs without changing its visible values',
      () {
        final now = DateTime.utc(2026, 7, 24).toIso8601String();
        final item = MaterialItem.fromJson({
          'id': 'legacy-1',
          'name': 'Legacy Pipe',
          'urduName': '',
          'category': 'Pipes & Tubing',
          'unit': 'ft',
          'quantity': 12,
          'createdAt': now,
          'updatedAt': now,
        });

        expect(item.category, MaterialCategory.pipes);
        expect(item.unit, MaterialUnit.feet);
        expect(item.categoryMasterId, 'cat-piping-drain');
        expect(item.unitMasterId, 'custom-unit-ft');
        expect(item.toJson()['unitMasterId'], 'custom-unit-ft');
      },
    );
  });

  group('master authorization and lifecycle', () {
    test('Admin can create and archive; records are not deleted', () async {
      final container = await _container(UserRole.admin);
      addTearDown(container.dispose);
      final notifier = container.read(materialCategoriesProvider.notifier);
      final before = container.read(materialCategoriesProvider).length;

      final id = await notifier.add(name: 'Test HVAC Category');
      await notifier.setArchived(id, true);

      final values = container.read(materialCategoriesProvider);
      expect(values, hasLength(before + 1));
      expect(values.singleWhere((value) => value.id == id).archived, isTrue);
    });

    test(
      'Procurement cannot mutate categories but can propose a unit',
      () async {
        final container = await _container(UserRole.procurement);
        addTearDown(container.dispose);

        await expectLater(
          container
              .read(materialCategoriesProvider.notifier)
              .add(name: 'Forbidden'),
          throwsStateError,
        );
        final id = await container
            .read(materialUnitsProvider.notifier)
            .add(name: 'Coil', symbol: 'coil');
        final unit = container
            .read(materialUnitsProvider)
            .singleWhere((value) => value.id == id);
        expect(unit.status, UnitReviewStatus.pendingReview);
        expect(
          container
              .read(selectableMaterialUnitsProvider)
              .map((value) => value.id),
          isNot(contains(id)),
        );
      },
    );

    test('master snapshots never contain commercial fields', () async {
      final container = await _container(UserRole.admin);
      addTearDown(container.dispose);
      container.read(materialCategoriesProvider);
      container.read(materialUnitsProvider);
      expect(container.read(materialCategoriesProvider), hasLength(8));
      expect(container.read(materialUnitsProvider), hasLength(18));
      expect(container.read(selectableMaterialUnitsProvider), hasLength(8));

      final prefs = container.read(sharedPreferencesProvider);
      final encoded = [
        prefs.getString('material_categories_v1'),
        prefs.getString('material_units_v1'),
      ].join();
      expect(encoded, isNot(contains('unitPrice')));
      expect(encoded, isNot(contains('unitCost')));
    });
  });

  group('role-safe catalogue CSV', () {
    final material = MaterialItem(
      id: 'mat-csv',
      name: 'Copper Pipe',
      urduName: '',
      category: MaterialCategory.pipes,
      unit: MaterialUnit.meters,
      quantity: 10,
      reservedQty: 2,
      unitPrice: 25,
      storeLocation: 'A-01',
    );
    final categories = {
      'cat-piping-drain': MaterialCategoryMaster(
        id: 'cat-piping-drain',
        name: 'Piping & Drain',
        sortOrder: 0,
        updatedAt: DateTime.utc(2026),
        updatedBy: 'Test',
      ),
    };
    final units = {
      'unit-meter': MaterialUnitMaster(
        id: 'unit-meter',
        name: 'Meter',
        symbol: 'm',
        sortOrder: 0,
        status: UnitReviewStatus.approved,
        updatedAt: DateTime.utc(2026),
        updatedBy: 'Test',
      ),
    };

    test('Engineer export has no cost schema or values', () {
      final csv = MaterialCatalogueCsvExport.build(
        materials: [material.withoutCommercials()],
        categories: categories,
        units: units,
        includeCommercials: false,
      );

      expect(csv, isNot(contains('Unit cost')));
      expect(csv, isNot(contains('Stock value')));
      expect(csv, isNot(contains('25.00')));
      expect(csv, contains('"Piping & Drain"'));
    });

    test('authorized export includes commercial columns', () {
      final csv = MaterialCatalogueCsvExport.build(
        materials: [material],
        categories: categories,
        units: units,
        includeCommercials: true,
      );

      expect(csv, contains('"Unit cost AED"'));
      expect(csv, contains('"25.00"'));
      expect(csv, contains('"250.00"'));
    });
  });

  testWidgets(
    'desktop Browse renders rail/list/inspector without Engineer cost',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = await _container(UserRole.engineer, canSeeCost: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Supply Air Grille');
      await tester.pump();

      expect(find.text('Browse Materials'), findsOneWidget);
      expect(find.text('All materials'), findsOneWidget);
      expect(find.text('Air Terminals'), findsWidgets);
      expect(find.text('Supply Air Grille (double deflection)'), findsWidgets);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Unit cost'), findsNothing);
      expect(find.text('Add material'), findsNothing);
    },
  );

  testWidgets('mobile Browse uses cards and a focused detail sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await _container(UserRole.engineer, canSeeCost: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.text('MATERIAL'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Supply Air Grille');
    await tester.pump();

    await tester.tap(find.text('Supply Air Grille (double deflection)').first);
    await tester.pumpAndSettle();
    expect(find.text('On hand'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);
    expect(find.text('Unit cost'), findsNothing);
  });
}

Future<ProviderContainer> _container(UserRole role, {bool? canSeeCost}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentRoleProvider.overrideWithValue(role),
      actorNameProvider.overrideWithValue('${role.label} Test'),
      if (canSeeCost != null)
        canViewCommercialsProvider.overrideWithValue(canSeeCost),
    ],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BrowseMaterialsScreen()),
    ),
  );
}
