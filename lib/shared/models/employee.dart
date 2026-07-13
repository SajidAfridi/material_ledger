// The signed-in user's HR self-profile — a VIEW MODEL derived entirely from
// live data (their login, their linked employee record, the attendance ledger
// and their leave balance). Nothing here is seeded or fabricated: an unlinked
// login (owner/admin, who by design has no employee record) carries
// [linked] = false and shows honest placeholders instead of invented figures.

/// Today's attendance state for the signed-in user, mapped from the real
/// attendance ledger. [notMarked] means no record exists for today yet.
enum SelfAttendance { present, absent, onLeave, halfDay, notMarked }

/// The signed-in employee's HR self-profile.
class EmployeeProfile {
  const EmployeeProfile({
    required this.name,
    required this.title,
    required this.employeeId,
    required this.email,
    required this.phone,
    required this.department,
    required this.nationality,
    required this.linked,
    required this.today,
    required this.annualUsed,
    required this.annualEntitlement,
    required this.pendingRequests,
    this.joinDate,
  });

  final String name;
  final String title;

  /// Employee record id, or '—' when the login isn't linked to one.
  final String employeeId;
  final String email;

  /// Contact number, or '—' when unknown.
  final String phone;
  final String department;
  final String nationality;

  /// Whether this login is linked to an HR employee record. When false, the
  /// HR-specific figures below are placeholders and the UI hides those sections.
  final bool linked;

  final SelfAttendance today;
  final int annualUsed;
  final int annualEntitlement;

  /// The user's own leave requests still awaiting a decision.
  final int pendingRequests;

  final DateTime? joinDate;

  int get annualRemaining =>
      (annualEntitlement - annualUsed).clamp(0, annualEntitlement);

  /// Two-letter initials for the avatar.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Length of service as of [now] (e.g. "3y 2m"), or null when the join date
  /// is unknown.
  String? tenureLabel(DateTime now) {
    final j = joinDate;
    if (j == null) return null;
    var months = (now.year - j.year) * 12 + (now.month - j.month);
    if (now.day < j.day) months -= 1;
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final rem = months % 12;
    if (years == 0) return '${rem}m';
    if (rem == 0) return '${years}y';
    return '${years}y ${rem}m';
  }
}
