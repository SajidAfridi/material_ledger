import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/features/inventory/presentation/widgets/add_material_sheet.dart';
import 'package:material_ledger/shared/models/app_strings.dart';
import 'package:material_ledger/shared/models/commercial_record.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/role_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/commercial_records_provider.dart';
import 'package:material_ledger/shared/providers/goods_receipt_provider.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/permissions_provider.dart';
import 'package:material_ledger/shared/providers/project_cost_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';
import 'package:material_ledger/shared/providers/role_permissions_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/services/commercial_csv_export.dart';
import 'package:material_ledger/shared/sync/mutation_op.dart';
import 'package:material_ledger/shared/sync/sync_backend.dart';
import 'package:material_ledger/shared/sync/supabase_bootstrap.dart';

const _password = 'test-only-local-password';

class _RecordingBackend implements SyncBackend {
  final operations = <MutationOp>[];

  @override
  Future<void> apply(MutationOp op) async {
    operations.add(op);
  }
}

Future<(ProviderContainer, SharedPreferences)> _testContainer({
  SyncBackend? backend,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      localDemoPasswordProvider.overrideWithValue(_password),
      if (backend != null) syncBackendProvider.overrideWithValue(backend),
    ],
  );
  return (container, preferences);
}

Future<void> _signIn(ProviderContainer container, String email) async {
  final result = await container
      .read(authControllerProvider)
      .signIn(email: email, password: _password);
  expect(result, SignInResult.ok);
}

void main() {
  group('commercial capability boundary', () {
    test(
      'Engineer receives no material cost in state or operational cache',
      () async {
        final (container, preferences) = await _testContainer();
        addTearDown(container.dispose);
        await _signIn(container, 'imrankhan@gmail.com');

        final materials = container.read(materialsProvider);
        expect(container.read(canViewCommercialsProvider), isFalse);
        expect(materials.every((material) => material.unitPrice == 0), isTrue);

        final stored =
            jsonDecode(preferences.getString('materials_list_v3')!) as List;
        expect(
          stored.cast<Map>().every((row) => !row.containsKey('unitPrice')),
          isTrue,
        );
        expect(
          preferences.containsKey(commercialLocalDevelopmentCacheKey),
          isFalse,
        );
      },
    );

    test(
      'Admin sees protected cost in memory while shared cache stays clean',
      () async {
        final (container, preferences) = await _testContainer();
        addTearDown(container.dispose);
        await _signIn(container, 'owner@gmail.com');

        container.read(materialsProvider);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(canViewCommercialsProvider), isTrue);
        expect(container.read(materialUnitCostProvider('mat-001')), 45);
        expect(
          container
              .read(materialsWithCommercialsProvider)
              .firstWhere((material) => material.id == 'mat-001')
              .unitPrice,
          45,
        );
        expect(
          container
              .read(materialsProvider)
              .firstWhere((material) => material.id == 'mat-001')
              .unitPrice,
          0,
        );
        expect(
          (jsonDecode(preferences.getString('materials_list_v3')!) as List)
              .cast<Map>()
              .every((row) => !row.containsKey('unitPrice')),
          isTrue,
        );
      },
    );

    test('Engineer cannot create a commercial record', () async {
      final (container, _) = await _testContainer();
      addTearDown(container.dispose);
      await _signIn(container, 'imrankhan@gmail.com');

      await expectLater(
        container
            .read(commercialRecordsProvider.notifier)
            .setMaterialUnitCost('mat-001', 99),
        throwsA(isA<CommercialAccessDenied>()),
      );
      expect(container.read(commercialRecordsProvider), isEmpty);
    });

    test('viewCommercials without goods remains read-only', () async {
      final (container, _) = await _testContainer();
      addTearDown(container.dispose);
      await _signIn(container, 'imrankhan@gmail.com');
      await container
          .read(rolePermissionsProvider.notifier)
          .setCapability(
            UserRole.engineer,
            RoleCapability.viewCommercials,
            true,
          );

      container.read(materialsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(canViewCommercialsProvider), isTrue);
      expect(container.read(materialUnitCostProvider('mat-001')), 45);
      await expectLater(
        container
            .read(commercialRecordsProvider.notifier)
            .setMaterialUnitCost('mat-001', 99),
        throwsA(isA<CommercialAccessDenied>()),
      );
    });

    test(
      'Procurement visibility follows the Admin role configuration',
      () async {
        final (container, preferences) = await _testContainer();
        addTearDown(container.dispose);
        await _signIn(container, 'alasad@gmail.com');

        container.read(materialsProvider);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(canViewCommercialsProvider), isTrue);
        expect(container.read(materialUnitCostProvider('mat-001')), 45);

        await container
            .read(rolePermissionsProvider.notifier)
            .setCapability(
              UserRole.procurement,
              RoleCapability.viewCommercials,
              false,
            );
        await Future<void>.delayed(Duration.zero);

        expect(container.read(canViewCommercialsProvider), isFalse);
        expect(container.read(commercialRecordsProvider), isEmpty);
        expect(
          preferences.containsKey(commercialLocalDevelopmentCacheKey),
          isFalse,
        );
      },
    );

    test('legacy cost capability upgrades to viewCommercials', () {
      final permissions = RolePermissions.fromJson({
        'engineer': <String>[],
        'procurement': ['cost', 'goods'],
      });

      expect(
        permissions.has(UserRole.procurement, RoleCapability.viewCommercials),
        isTrue,
      );
      final encoded = permissions.toJson().toString();
      expect(encoded, contains('viewCommercials'));
      expect(encoded, isNot(contains('cost')));
    });
  });

  group('commercial persistence and export boundary', () {
    test(
      'project contract value is protected and denied writes fail closed',
      () async {
        final (denied, _) = await _testContainer();
        addTearDown(denied.dispose);
        final project = Project(
          id: 'project-commercial',
          name: 'Commercial Project',
          contractValueAED: 250000,
        );

        await expectLater(
          denied.read(projectsProvider.notifier).addProject(project),
          throwsA(isA<CommercialAccessDenied>()),
        );
        expect(
          denied.read(projectsProvider).any((item) => item.id == project.id),
          isFalse,
        );

        final backend = _RecordingBackend();
        final (admin, preferences) = await _testContainer(backend: backend);
        addTearDown(admin.dispose);
        await _signIn(admin, 'owner@gmail.com');
        expect(
          await admin.read(projectsProvider.notifier).addProject(project),
          isTrue,
        );

        expect(
          admin
              .read(projectsProvider)
              .firstWhere((item) => item.id == project.id)
              .contractValueAED,
          isNull,
        );
        expect(
          admin
              .read(projectsWithCommercialsProvider)
              .firstWhere((item) => item.id == project.id)
              .contractValueAED,
          250000,
        );
        final stored =
            jsonDecode(preferences.getString('projects_list_v1')!) as List;
        expect(
          stored.cast<Map>().every(
            (row) => !row.containsKey('contractValueAED'),
          ),
          isTrue,
        );
        final projectOp = backend.operations.firstWhere(
          (operation) => operation.collection == 'projects',
        );
        expect(projectOp.payload.containsKey('contractValueAED'), isFalse);
      },
    );

    test(
      'goods receipt cost is absent from shared state, cache, and outbox',
      () async {
        final backend = _RecordingBackend();
        final (container, preferences) = await _testContainer(backend: backend);
        addTearDown(container.dispose);
        await _signIn(container, 'owner@gmail.com');
        container.read(materialsProvider);
        await Future<void>.delayed(Duration.zero);

        final receipt = await container
            .read(goodsReceiptsProvider.notifier)
            .recordReceipt(
              materialId: 'mat-001',
              materialName: 'Gate Valve 2" (Brass)',
              quantity: 2,
              unitSymbol: 'pcs',
              unitCostAED: 50,
              supplier: 'Supplier A',
              receivedBy: 'Owner',
            );

        expect(receipt.unitCostAED, 0);
        final commercial = container
            .read(commercialRecordsProvider.notifier)
            .record(CommercialSubjectType.goodsReceipt, receipt.id);
        expect(commercial?.unitCostAED, 50);
        expect(commercial?.totalCostAED, 100);

        final stored =
            jsonDecode(preferences.getString('goods_receipts_v2')!) as List;
        expect(
          stored.cast<Map>().every((row) => !row.containsKey('unitCostAED')),
          isTrue,
        );
        final receiptOp = backend.operations.firstWhere(
          (operation) => operation.collection == 'goodsReceipts',
        );
        expect(receiptOp.payload.containsKey('unitCostAED'), isFalse);
      },
    );

    test('cloud sanitizer removes commercial keys at every nesting level', () {
      final sanitized = SupabaseBootstrap.sanitizeForCloud('materialRequests', {
        'id': 'mr-1',
        'unitPrice': 20,
        'lineItems': [
          {
            'materialId': 'mat-001',
            'unitCostAED': 45,
            'supplier': {'name': 'Supplier A', 'total_cost_aed': 100},
          },
        ],
      });

      expect(sanitized.containsKey('unitPrice'), isFalse);
      final line = (sanitized['lineItems'] as List).single as Map;
      expect(line.containsKey('unitCostAED'), isFalse);
      expect((line['supplier'] as Map).containsKey('total_cost_aed'), isFalse);
      expect(line['materialId'], 'mat-001');
    });

    test('CSV export is denied without capability and safely quotes names', () {
      const rows = [
        ProjectCostRow(
          projectName: 'Project, "A"',
          cost: ProjectCost(dispatchedAED: 100, returnedAED: 25),
        ),
      ];

      expect(
        () => CommercialCsvExport.projectCosts(rows, canViewCommercials: false),
        throwsA(isA<CommercialExportDenied>()),
      );
      final csv = CommercialCsvExport.projectCosts(
        rows,
        canViewCommercials: true,
      );
      expect(csv, contains('"Project, ""A"""'));
      expect(csv, contains('100.00,25.00,75.00'));
    });
  });

  testWidgets('Engineer material editor never builds a Unit Price field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          canViewCommercialsProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: Scaffold(body: AddMaterialSheet())),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.unitPrice.primary), findsNothing);
    expect(find.text(AppStrings.quantity.primary), findsOneWidget);
  });
}
