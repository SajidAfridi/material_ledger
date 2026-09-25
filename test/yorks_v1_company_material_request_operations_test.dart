import 'package:flutter/material.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_company_material_request_approval_screens.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_company_material_request_operations.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';

void main() {
  for (final width in [360.0, 390.0, 600.0, 768.0, 1024.0, 1366.0, 1920.0]) {
    testWidgets(
      'Procurement plan validates Save and cancels safely at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        CompanySupplyPlanChoice? result;
        var dismissed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    result = await showDialog<CompanySupplyPlanChoice>(
                      context: context,
                      builder: (_) => const CompanySupplyPlanDialog(
                        line: YorksV1CompanyMaterialRequestLine(
                          id: 'l',
                          displayOrder: 1,
                          description: 'Workshop helmet with adjustable strap',
                          quantity: '3',
                          unit: 'pcs',
                        ),
                        outstandingQuantity: '3',
                        language: AppLanguage.english,
                        inventory: [
                          YorksV1InventoryItem(
                            id: 'stock',
                            description: 'Workshop helmet',
                            unit: 'pcs',
                            onHandQuantity: '8',
                            reservedQuantity: '0',
                            availableQuantity: '8',
                            recordVersion: 1,
                          ),
                        ],
                      ),
                    );
                    dismissed = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('company-plan-save')));
        await tester.pumpAndSettle();
        expect(
          dismissed,
          isFalse,
          reason: 'Save must require an explicit stock selection',
        );
        expect(result, isNull);
        await tester.tap(find.byKey(const ValueKey('company-plan-cancel')));
        await tester.pumpAndSettle();
        expect(dismissed, isTrue);
        expect(
          result,
          isNull,
          reason: 'Cancel never adds an arrangement choice',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'unavailable arrangement preserves deliberate follow-up on Save',
    (tester) async {
      CompanySupplyPlanChoice? result;
      final date = DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String()
          .split('T')
          .first;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showDialog<CompanySupplyPlanChoice>(
                    context: context,
                    builder: (_) => CompanySupplyPlanDialog(
                      line: const YorksV1CompanyMaterialRequestLine(
                        id: 'l',
                        displayOrder: 1,
                        description: 'Helmet',
                        quantity: '3',
                        unit: 'pcs',
                      ),
                      outstandingQuantity: '3',
                      inventory: const [],
                      language: AppLanguage.english,
                      initial: CompanySupplyPlanChoice(
                        decision: 'unavailable',
                        quantity: '0',
                        reason: 'Supply delayed',
                        followUpDate: date,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('company-plan-save')));
      await tester.pumpAndSettle();
      expect(result!.followUpDate, date);
      expect(result!.reason, 'Supply delayed');
      expect(result!.inventoryItemId, isNull);
      expect(result!.quantity, '0');
    },
  );

  test(
    'private draft summaries preserve identity without submission evidence',
    () {
      final item = YorksV1CompanyMaterialRequestApprovalInboxItem.fromRpcJson({
        'id': 'draft',
        'request_number': null,
        'record_version': 1,
        'state': 'draft',
        'category_name': 'PPE',
        'responsible_unit_name': 'Workshop',
        'purpose': 'Helmets',
        'requester_display_name': 'Requester',
        'beneficiary_display_name': 'Beneficiary',
        'submitted_at': null,
        'updated_at': '2026-09-25T10:00:00Z',
        'line_count': 2,
      });
      expect(item.id, 'draft');
      expect(item.requestNumber, isEmpty);
      expect(item.state, 'draft');
      expect(item.submittedAt, DateTime.utc(2026, 9, 25, 10));
    },
  );

  testWidgets(
    'quantity review prevents blanket returns, over-cap and empty reasons',
    (tester) async {
      CompanyQuantitySelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showDialog<CompanyQuantitySelection>(
                    context: context,
                    builder: (_) => const CompanyQuantityReview(
                      title: 'Return items',
                      language: AppLanguage.english,
                      requireReason: true,
                      items: [
                        CompanyQuantityItem(
                          id: 'line',
                          description: 'Helmet',
                          unit: 'pcs',
                          maximum: '3',
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final quantity = find.byKey(const ValueKey('company-quantity-line'));
      expect(tester.widget<TextFormField>(quantity).controller!.text, '0');
      await tester.enterText(quantity, '4');
      await tester.tap(find.byKey(const ValueKey('company-operation-confirm')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text('Enter a quantity within the available amount.'),
        findsOneWidget,
      );
      await tester.enterText(quantity, '1.5');
      await tester.enterText(
        find.byKey(const ValueKey('company-operation-reason')),
        'Unused quantity',
      );
      await tester.tap(find.byKey(const ValueKey('company-operation-confirm')));
      await tester.pumpAndSettle();
      expect(result!.quantities, {'line': '1.5'});
      expect(result!.reason, 'Unused quantity');
    },
  );

  testWidgets(
    'line review requires every item and preserves edits before commit',
    (tester) async {
      List<String>? result;
      String? previous;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showDialog<List<String>>(
                    context: context,
                    builder: (_) => CompanyLineReview<String>(
                      title: 'Receive',
                      descriptions: const ['Helmet', 'Gloves'],
                      language: AppLanguage.english,
                      edit: (index, old) async {
                        previous = old;
                        return 'Reviewed $index';
                      },
                      summary: (value) => value,
                      confirmLabel: 'Confirm receipt',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('company-review-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('company-review-line-0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('company-review-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('company-review-line-0')));
      await tester.pumpAndSettle();
      expect(previous, 'Reviewed 0');
      await tester.tap(find.byKey(const ValueKey('company-review-line-1')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.byKey(const ValueKey('company-review-confirm')));
      await tester.pumpAndSettle();
      expect(result, ['Reviewed 0', 'Reviewed 1']);
    },
  );
}
