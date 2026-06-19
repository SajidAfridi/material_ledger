// Employee / attendance domain (HR module shown on the engineer home).
// Pure Dart model — the UI maps kinds to colours/icons.

enum LeaveKind { annual, casual, sick, overtime }

/// A leave balance line (e.g. Annual: 3 of 12 days used).
class LeaveBalance {
  const LeaveBalance({
    required this.kind,
    required this.labelEn,
    required this.labelAr,
    required this.used,
    this.total = 0,
  });

  final LeaveKind kind;
  final String labelEn;
  final String labelAr;
  final int used;

  /// 0 means there is no fixed allowance — show the count only.
  final int total;

  double get fraction =>
      total > 0 ? (used / total).clamp(0.0, 1.0).toDouble() : 0.0;
}

/// Today's attendance snapshot.
class Attendance {
  const Attendance({
    required this.checkIn,
    required this.checkOut,
    required this.remainingHours,
  });

  final String checkIn; // e.g. "8:00 AM"
  final String checkOut; // e.g. "4:30 PM"
  final int remainingHours; // hours left in the shift
}

/// The signed-in employee's HR profile.
class EmployeeProfile {
  const EmployeeProfile({
    required this.name,
    required this.nameAr,
    required this.title,
    required this.titleAr,
    required this.employeeId,
    required this.email,
    required this.phone,
    required this.department,
    required this.departmentAr,
    required this.attendance,
    required this.leaves,
  });

  final String name;
  final String nameAr;
  final String title;
  final String titleAr;
  final String employeeId;
  final String email;
  final String phone;
  final String department;
  final String departmentAr;
  final Attendance attendance;
  final List<LeaveBalance> leaves;

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
}
