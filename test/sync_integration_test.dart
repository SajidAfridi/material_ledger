import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/leave_record.dart';
import 'package:material_ledger/shared/models/attendance_record.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/providers/hr_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_request_provider.dart';
import 'package:material_ledger/shared/providers/rentals_provider.dart';
import 'package:material_ledger/shared/repositories/storage.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:material_ledger/shared/sync/mutation_op.dart';
import 'package:material_ledger/shared/sync/outbox.dart';
import 'package:material_ledger/shared/sync/sync_backend.dart';
import 'package:material_ledger/shared/sync/sync_engine.dart';

/// In-memory "server" double — records every applied op by docId.
class _FakeBackend implements SyncBackend {
  final Map<String, Map<String, dynamic>> server = {};
  int applyCount = 0;
  @override
  Future<void> apply(MutationOp op) async {
    applyCount++;
    server[op.docId] = op.payload; // idempotent set on a client-generated id
  }
}

/// End-to-end proof that the durable outbox is wired into the real notifiers
/// across roles: writes made offline queue (nothing reaches the server), then
/// flush exactly once each on reconnect — zero loss, zero duplicates.
void main() {
  test('critical writes across roles queue offline and flush once on reconnect',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final conn = DefaultConnectivity(online: false); // start offline
    final backend = _FakeBackend();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityProvider.overrideWithValue(conn),
        syncBackendProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);

    // ── Engineer: raise a material request, then it gets partially dispatched
    //    (procurement). Both target the same doc → must coalesce to one op. ──
    final requests = container.read(materialRequestsProvider.notifier);
    await requests.addRequest(
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
    await requests.dispatch(reqId, [2]); // partial dispatch

    // ── Procurement / Admin: record a rent payment (transactional balance). ──
    await container.read(rentPaymentsProvider.notifier).recordPayment(
          unitId: 'unit-shop-01',
          periodMonth: currentRentMonthKey(),
          amountDueAED: 3800,
          amountPaidAED: 3800,
          recordedBy: 'Tester',
        );

    // ── HR (Admin/Procurement): mark attendance + add a leave record. ──
    await container.read(attendanceProvider.notifier).markToday(
          employeeId: 'emp-001',
          status: AttendanceStatus.present,
          recordedBy: 'Tester',
        );
    await container.read(leaveRecordsProvider.notifier).addLeave(
          employeeId: 'emp-001',
          type: LeaveType.annual,
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 7, 3),
        );

    // Offline: nothing reached the server; everything is durably queued.
    final outbox = container.read(outboxProvider);
    expect(backend.applyCount, 0);
    expect(backend.server, isEmpty);
    // request (create+dispatch coalesced) + rent + attendance + leave = 4 ops.
    expect(outbox.length, 4);
    // The coalesced request op carries the dispatched (latest) state.
    final reqOp = outbox.firstWhere((o) => o.collection == 'materialRequests');
    expect(reqOp.docId, reqId);

    // Survives a restart: a fresh outbox over the same storage still has them.
    final reopened = OutboxNotifier(
      LocalStorage(prefs).collection<MutationOp>(
        'sync_outbox_v1',
        toJson: (o) => o.toJson(),
        fromJson: MutationOp.fromJson,
      ),
    );
    expect(reopened.ops.length, 4);

    // ── Reconnect → engine flushes the queue in order. ──
    conn.setOnline(true);
    await container.read(syncEngineProvider).flush();

    expect(backend.applyCount, 4); // each op applied exactly once
    expect(backend.server.length, 4); // zero duplicate documents
    expect(container.read(outboxProvider), isEmpty); // zero loss, all confirmed

    // A redundant flush must not re-send anything.
    await container.read(syncEngineProvider).flush();
    expect(backend.applyCount, 4);
  });
}
