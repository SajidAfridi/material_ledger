import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/app_notification.dart';
import '../shared/models/employee_record.dart';
import '../shared/models/user_role.dart';
import '../shared/providers/hr_provider.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/notification_provider.dart';
import 'router.dart';

/// Flag a document expiring within this window (or already expired) — enough
/// runway to renew a visa/Emirates ID/passport before it lapses.
const documentExpiryWindow = Duration(days: 30);

/// One employee document nearing (or past) its expiry.
class ExpiringDocument {
  const ExpiringDocument({
    required this.employee,
    required this.label,
    required this.expiry,
    required this.dedupeKey,
    required this.isExpired,
  });

  final Employee employee;
  final String label; // "Visa" / "Emirates ID" / "Passport"
  final DateTime expiry;

  /// Unique per (employee, document) so a launch re-scan never re-notifies —
  /// stored as the notification's refId.
  final String dedupeKey;

  /// Computed against the scan's injected `now` (never the wall clock) so this
  /// stays consistent with whatever moment [expiringDocuments] was evaluated
  /// at, and stays testable/deterministic.
  final bool isExpired;
}

/// Every active employee's visa/Emirates ID/passport expiring within
/// [documentExpiryWindow] (or already expired), excluding ones already flagged
/// to admin. Pure (no I/O), injectable [now] for testability.
List<ExpiringDocument> expiringDocuments(
  List<Employee> employees,
  List<AppNotification> existing,
  DateTime now,
) {
  final alreadyFlagged = existing
      .where((n) => n.audience == UserRole.admin.name && n.refId.isNotEmpty)
      .map((n) => n.refId)
      .toSet();
  final cutoff = now.add(documentExpiryWindow);
  final out = <ExpiringDocument>[];

  for (final e in employees) {
    if (e.status == EmployeeStatus.inactive) continue;
    void check(DateTime? expiry, String label, String docCode) {
      if (expiry == null || expiry.isAfter(cutoff)) return;
      final key = '${e.id}:$docCode:${expiry.toIso8601String().split('T').first}';
      if (alreadyFlagged.contains(key)) return;
      out.add(ExpiringDocument(
        employee: e,
        label: label,
        expiry: expiry,
        dedupeKey: key,
        isExpired: now.isAfter(expiry),
      ));
    }

    check(e.visaExpiry, 'Visa', 'visa');
    check(e.emiratesIdExpiry, 'Emirates ID', 'eid');
    check(e.passportExpiry, 'Passport', 'passport');
  }
  return out;
}

/// On app start, flag any employee document expiring within 30 days (or
/// already expired) to admin, deep-linked to their profile. Dedup by a stable
/// per-document key so re-running on every launch never duplicates. Watched
/// once at the app root; the scan is deferred to a microtask so it never
/// mutates another provider mid-build.
final documentExpiryMonitorProvider = Provider<void>((ref) {
  Future.microtask(() async {
    final expiring = expiringDocuments(
      ref.read(employeesProvider),
      ref.read(notificationsProvider),
      DateTime.now(),
    );
    if (expiring.isEmpty) return;
    final lang = ref.read(languageProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    for (final d in expiring) {
      final verb = d.isExpired ? 'expired' : 'expiring soon';
      await notifier.add(
        type: NotificationType.info,
        title: '${d.label} $verb · ${d.employee.fullName}',
        titleSecondary: lang.isRtl ? '${d.label} $verb' : '${d.label} $verb',
        body:
            '${d.employee.fullName} · ${d.label} ${d.isExpired ? 'expired' : 'expires'} '
            '${d.expiry.toIso8601String().split('T').first}',
        refId: d.dedupeKey,
        route: RoutePaths.employeeProfilePath(d.employee.id),
        audience: UserRole.admin.name,
      );
    }
  });
});
