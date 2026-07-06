import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/leave_record.dart';
import 'package:material_ledger/shared/providers/hr_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';

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

  test('year-spanning annual leave charges only that year\'s days', () async {
    final year = DateTime.now().year;
    final leave = container.read(leaveRecordsProvider.notifier);
    // emp-002 has no seeded ANNUAL leave (only a sick record), and >1yr tenure.
    final rec = await leave.submitRequest(
      employeeId: 'emp-002',
      requestedByUserId: 'usr-eng',
      requestedByName: 'Tester',
      type: LeaveType.annual,
      startDate: DateTime(year, 12, 28),
      endDate: DateTime(year + 1, 1, 6), // 10 days spanning the new year
    );
    await leave.decide(
      rec.id,
      approve: true,
      decidedBy: 'Owner',
      decidedByUserId: 'usr-admin',
    );

    final bal = container.read(leaveBalanceProvider('emp-002'));
    // Only 28–31 Dec (4 days) belong to this year; 1–6 Jan roll into next year.
    expect(bal.usedAnnual, 4);
    expect(bal.entitlement, 30); // >1 year of service
    expect(bal.remaining, 26);
  });

  test('a fully in-year annual leave charges all its days', () async {
    final year = DateTime.now().year;
    final leave = container.read(leaveRecordsProvider.notifier);
    final rec = await leave.submitRequest(
      employeeId: 'emp-002',
      requestedByUserId: 'usr-eng',
      requestedByName: 'Tester',
      type: LeaveType.annual,
      startDate: DateTime(year, 6, 1),
      endDate: DateTime(year, 6, 5), // 5 days, same year
    );
    await leave.decide(
      rec.id,
      approve: true,
      decidedBy: 'Owner',
      decidedByUserId: 'usr-admin',
    );
    expect(container.read(leaveBalanceProvider('emp-002')).usedAnnual, 5);
  });

  test('an overlapping leave request is rejected', () async {
    final year = DateTime.now().year;
    final leave = container.read(leaveRecordsProvider.notifier);
    await leave.submitRequest(
      employeeId: 'emp-002',
      requestedByUserId: 'u',
      requestedByName: 'T',
      type: LeaveType.annual,
      startDate: DateTime(year, 6, 1),
      endDate: DateTime(year, 6, 10),
    );
    // A second request overlapping the first must be refused.
    expect(
      () => leave.submitRequest(
        employeeId: 'emp-002',
        requestedByUserId: 'u',
        requestedByName: 'T',
        type: LeaveType.sick,
        startDate: DateTime(year, 6, 5),
        endDate: DateTime(year, 6, 8),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
