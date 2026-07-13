import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/material_return.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/inventory_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_request_provider.dart';
import 'package:material_ledger/shared/providers/material_return_provider.dart';
import 'package:material_ledger/shared/providers/project_cost_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  double qtyOf(String id) =>
      container.read(materialsProvider).firstWhere((m) => m.id == id).quantity;
  double reservedOf(String id) =>
      container.read(materialsProvider).firstWhere((m) => m.id == id).reservedQty;
  double availableOf(String id) =>
      container.read(materialsProvider).firstWhere((m) => m.id == id).availableQty;

  group('Reservation lifecycle (FR-094)', () {
    test('raising a request reserves stock; availableQty drops', () async {
      final startQty = qtyOf('mat-001'); // 120
      await container
          .read(materialRequestsProvider.notifier)
          .addRequest(
            projectName: 'Test Project',
            projectNameSecondary: '',
            itemCount: 1,
            lineItems: const [
              RequestLineItem(
                materialId: 'mat-001',
                materialName: 'Gate Valve 2" (Brass)',
                materialNameSecondary: '',
                quantity: 20,
                unitSymbol: 'pcs',
              ),
            ],
          );

      expect(reservedOf('mat-001'), 20);
      expect(qtyOf('mat-001'), startQty); // on-hand unchanged by reservation
      expect(availableOf('mat-001'), startQty - 20);
    });

    test('dispatch decrements stock + frees reservation; receipt only records',
        () async {
      final startQty = qtyOf('mat-001');
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Test Project',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-001',
            materialName: 'Gate Valve 2" (Brass)',
            materialNameSecondary: '',
            quantity: 20,
            unitSymbol: 'pcs',
          ),
        ],
      );
      expect(reservedOf('mat-001'), 20);
      final reqId = container.read(materialRequestsProvider).first.id;

      // Procurement dispatches → stock leaves the store, reservation freed.
      await notifier.dispatch(reqId, [20]);
      expect(qtyOf('mat-001'), startQty - 20);
      expect(reservedOf('mat-001'), 0);

      // Engineer confirms receipt → records only, no further stock change.
      await notifier.confirmReceipt(reqId, [20]);
      expect(qtyOf('mat-001'), startQty - 20);
    });

    test('partial dispatch leaves the remainder open (status = partial)',
        () async {
      final startQty = qtyOf('mat-001');
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Partial Project',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-001',
            materialName: 'Gate Valve 2" (Brass)',
            materialNameSecondary: '',
            quantity: 20,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final reqId = container.read(materialRequestsProvider).first.id;

      await notifier.dispatch(reqId, [12]); // 12 of 20
      final req = container.read(materialRequestsProvider).firstWhere(
        (r) => r.id == reqId,
      );
      expect(req.status, RequestStatus.partial);
      expect(req.lineItems.first.qtyDispatched, 12);
      expect(req.lineItems.first.qtyOutstanding, 8);
      expect(qtyOf('mat-001'), startQty - 12);
      expect(reservedOf('mat-001'), 8); // remainder still reserved
    });

    test('receipt cannot exceed dispatched and keeps a back-order live',
        () async {
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Back-order',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-003',
            materialName: 'Butterfly Valve 4" (Wafer)',
            materialNameSecondary: '',
            quantity: 20,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final reqId = container.read(materialRequestsProvider).first.id;
      await notifier.dispatch(reqId, [12]); // only 12 of 20 shipped
      // Engineer claims 20 received though only 12 shipped.
      await notifier.confirmReceipt(reqId, [20]);
      final req =
          container.read(materialRequestsProvider).firstWhere((r) => r.id == reqId);
      expect(req.lineItems.first.qtyReceived, 12); // clamped to dispatched
      expect(req.status, RequestStatus.partial); // 8 still outstanding → stays live
    });

    test("dispatch can't consume another request's reservation", () async {
      final notifier = container.read(materialRequestsProvider.notifier);
      // mat-004 on-hand 55; two requests reserve 30 each (60 > 55).
      await notifier.addRequest(
        projectName: 'Req A',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-004',
            materialName: 'Check Valve 1.5" (Swing Type)',
            materialNameSecondary: '',
            quantity: 30,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final reqA = container.read(materialRequestsProvider).first.id;
      await notifier.addRequest(
        projectName: 'Req B',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-004',
            materialName: 'Check Valve 1.5" (Swing Type)',
            materialNameSecondary: '',
            quantity: 30,
            unitSymbol: 'pcs',
          ),
        ],
      );
      // A wants 30 but only 25 are free (30 reserved for B) → must not ship.
      await notifier.dispatch(reqA, [30]);
      final a =
          container.read(materialRequestsProvider).firstWhere((r) => r.id == reqA);
      expect(a.lineItems.first.qtyDispatched ?? 0, 0);
      expect(a.status, RequestStatus.pending); // untouched, still queued
    });

    test('cancelling a held request releases the reservation', () async {
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Test Project',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-002',
            materialName: 'Ball Valve 1" (SS 304)',
            materialNameSecondary: '',
            quantity: 10,
            unitSymbol: 'pcs',
          ),
        ],
      );
      expect(reservedOf('mat-002'), 10);
      final reqId = container.read(materialRequestsProvider).first.id;

      await notifier.updateStatus(reqId, RequestStatus.cancelled);
      expect(reservedOf('mat-002'), 0);
    });
  });

  group('Stock restore on return (FR-083)', () {
    test('surplus return restocks inventory (up to what was issued)', () async {
      // Only stock actually issued to the project can be returned — dispatch it.
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Test Project',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-001',
            materialName: 'Gate Valve 2" (Brass)',
            materialNameSecondary: '',
            quantity: 5,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final reqId = container.read(materialRequestsProvider).first.id;
      await notifier.dispatch(reqId, [5]);
      final afterDispatch = qtyOf('mat-001'); // 5 left the store

      await container.read(returnsProvider.notifier).addReturn(
        projectName: 'Test Project',
        projectNameSecondary: '',
        items: const [
          ReturnItem(
            description: 'Gate Valve 2" (Brass)',
            quantity: 5,
            unitSymbol: 'pcs',
            materialId: 'mat-001',
            reason: ReturnReason.surplus,
          ),
        ],
      );
      expect(qtyOf('mat-001'), afterDispatch + 5); // the 5 issued come back
    });

    test('cannot return more than was issued to the project', () async {
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Over Return',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-002',
            materialName: 'Ball Valve 1" (SS 304)',
            materialNameSecondary: '',
            quantity: 4,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final reqId = container.read(materialRequestsProvider).first.id;
      await notifier.dispatch(reqId, [4]);
      final afterDispatch = qtyOf('mat-002');

      // Ask to return 10 though only 4 were issued → clamps to 4.
      await container.read(returnsProvider.notifier).addReturn(
        projectName: 'Over Return',
        projectNameSecondary: '',
        items: const [
          ReturnItem(
            description: 'Ball Valve 1" (SS 304)',
            quantity: 10,
            unitSymbol: 'pcs',
            materialId: 'mat-002',
            reason: ReturnReason.surplus,
          ),
        ],
      );
      expect(qtyOf('mat-002'), afterDispatch + 4); // clamped to issued, not +10
    });

    test('damaged return is NOT restocked', () async {
      final startQty = qtyOf('mat-001');
      await container
          .read(returnsProvider.notifier)
          .addReturn(
            projectName: 'Test Project',
            projectNameSecondary: '',
            items: const [
              ReturnItem(
                description: 'Gate Valve 2" (Brass)',
                quantity: 5,
                unitSymbol: 'pcs',
                materialId: 'mat-001',
                reason: ReturnReason.damaged,
              ),
            ],
          );
      expect(qtyOf('mat-001'), startQty); // unchanged
    });
  });

  group('Project cost roll-up (FR-091)', () {
    test('net cost = dispatched value − returned value', () async {
      // mat-001 unit cost = 45.00 (seed).
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: 'Cost Project',
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-001',
            materialName: 'Gate Valve 2" (Brass)',
            materialNameSecondary: '',
            quantity: 20,
            unitSymbol: 'pcs',
          ),
        ],
      );
      final reqId = container.read(materialRequestsProvider).first.id;
      await notifier.dispatch(reqId, [20]); // issue to site
      await notifier.confirmReceipt(reqId, [20]); // received → dispatched value

      // Return 5 units against the same project.
      await container.read(returnsProvider.notifier).addReturn(
        projectName: 'Cost Project',
        projectNameSecondary: '',
        items: const [
          ReturnItem(
            description: 'Gate Valve 2" (Brass)',
            quantity: 5,
            unitSymbol: 'pcs',
            materialId: 'mat-001',
            reason: ReturnReason.surplus,
          ),
        ],
      );

      final cost = container.read(projectCostProvider('Cost Project'));
      expect(cost.dispatchedAED, 20 * 45.0);
      expect(cost.returnedAED, 5 * 45.0);
      expect(cost.netAED, (20 - 5) * 45.0);
    });
  });

  group('Goods receipt + weighted-average cost (FR-090)', () {
    test('receiveStock increments on-hand and rolls unit cost', () async {
      final inv = container.read(materialsProvider.notifier);
      // mat-001: 120 @ 45. Receive 40 @ 50 → avg = (120*45 + 40*50)/160.
      await inv.receiveStock('mat-001', 40, unitCostAED: 50);
      final item =
          container.read(materialsProvider).firstWhere((m) => m.id == 'mat-001');
      expect(item.quantity, 160);
      expect(item.unitCostAED, closeTo((120 * 45 + 40 * 50) / 160, 0.001));
    });
  });

  group('Closeout enforcement (FR-095)', () {
    test('cannot complete a project with open requests; can once cleared',
        () async {
      // No projects are pre-seeded (a clean slate for real use) — create a
      // fresh active project fixture directly rather than relying on seed data.
      final active = Project(
        id: 'proj-test-closeout',
        name: 'Closeout Test Project',
        nameSecondary: '',
        phase: const ProjectPhase(
          number: 2,
          name: 'Active',
          nameSecondary: 'فعال',
          state: ProjectState.active,
        ),
      );
      await container.read(projectsProvider.notifier).addProject(active);
      final notifier = container.read(materialRequestsProvider.notifier);
      await notifier.addRequest(
        projectName: active.name,
        projectNameSecondary: '',
        itemCount: 1,
        lineItems: const [
          RequestLineItem(
            materialId: 'mat-005',
            materialName: 'Globe Valve 3" (CI)',
            materialNameSecondary: '',
            quantity: 2,
            unitSymbol: 'pcs',
          ),
        ],
      );

      final projNotifier = container.read(projectsProvider.notifier);
      expect(projNotifier.canComplete(active.id), false);
      expect(await projNotifier.completeProject(active.id), false);

      // Clear the open request (cancel it), then closeout succeeds.
      final reqId = container.read(materialRequestsProvider).first.id;
      await notifier.updateStatus(reqId, RequestStatus.cancelled);
      expect(projNotifier.canComplete(active.id), true);
      expect(await projNotifier.completeProject(active.id), true);
      expect(
        projNotifier.byId(active.id)!.phase!.state,
        ProjectState.completed,
      );
    });
  });
}
