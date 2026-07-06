import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/app/document_expiry_monitor.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/employee_record.dart';

Employee _emp({
  required String id,
  DateTime? visaExpiry,
  DateTime? emiratesIdExpiry,
  DateTime? passportExpiry,
  EmployeeStatus status = EmployeeStatus.active,
}) =>
    Employee(
      id: id,
      fullName: 'Test $id',
      jobRole: 'Engineer',
      department: 'Projects',
      nationality: 'Test',
      visaExpiry: visaExpiry,
      emiratesIdExpiry: emiratesIdExpiry,
      passportExpiry: passportExpiry,
      status: status,
    );

void main() {
  final now = DateTime(2026, 6, 19);

  group('expiringDocuments', () {
    test('flags a visa expiring within the 30-day window', () {
      final out = expiringDocuments(
        [_emp(id: 'e1', visaExpiry: now.add(const Duration(days: 10)))],
        const [],
        now,
      );
      expect(out.map((d) => d.employee.id), ['e1']);
      expect(out.first.label, 'Visa');
      expect(out.first.isExpired, false);
    });

    test('flags an already-expired document', () {
      final out = expiringDocuments(
        [_emp(id: 'e2', passportExpiry: now.subtract(const Duration(days: 5)))],
        const [],
        now,
      );
      expect(out.first.isExpired, true);
      expect(out.first.label, 'Passport');
    });

    test('ignores a document expiring well beyond the window', () {
      final out = expiringDocuments(
        [_emp(id: 'e3', emiratesIdExpiry: now.add(const Duration(days: 90)))],
        const [],
        now,
      );
      expect(out, isEmpty);
    });

    test('flags all three document types independently for one employee', () {
      final out = expiringDocuments(
        [
          _emp(
            id: 'e4',
            visaExpiry: now.add(const Duration(days: 5)),
            emiratesIdExpiry: now.add(const Duration(days: 5)),
            passportExpiry: now.add(const Duration(days: 5)),
          ),
        ],
        const [],
        now,
      );
      expect(out.map((d) => d.label).toSet(), {'Visa', 'Emirates ID', 'Passport'});
    });

    test('does not re-flag a document already alerted (dedup by exact date)', () {
      final expiry = now.add(const Duration(days: 5));
      final emp = _emp(id: 'e5', visaExpiry: expiry);
      final key = 'e5:visa:${expiry.toIso8601String().split('T').first}';
      final out = expiringDocuments(
        [emp],
        [
          AppNotification(
            id: 'n1',
            type: NotificationType.info,
            title: 'x',
            titleSecondary: '',
            timestamp: now,
            refId: key,
            audience: 'admin',
          ),
        ],
        now,
      );
      expect(out, isEmpty);
    });

    test('skips inactive employees', () {
      final out = expiringDocuments(
        [
          _emp(
            id: 'e6',
            visaExpiry: now.add(const Duration(days: 1)),
            status: EmployeeStatus.inactive,
          ),
        ],
        const [],
        now,
      );
      expect(out, isEmpty);
    });
  });
}
