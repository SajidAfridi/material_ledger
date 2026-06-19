import 'dart:convert';

/// Employment status of a roster employee.
enum EmployeeStatus {
  active('Active', 'نشط', 'فعال', 'सक्रिय'),
  onLeave('On Leave', 'في إجازة', 'چھٹی پر', 'अवकाश पर'),
  inactive('Inactive', 'غير نشط', 'غیر فعال', 'निष्क्रिय');

  const EmployeeStatus(this.label, this.ar, this.ur, this.hi);
  final String label;
  final String ar;
  final String ur;
  final String hi;

  static EmployeeStatus fromName(String n) => EmployeeStatus.values.firstWhere(
    (s) => s.name == n,
    orElse: () => active,
  );
}

/// A roster employee in the People / HR module (FR-124). Salary and document
/// fields are restricted to Admin in the UI and Security Rules (FR-128);
/// procurement manages the roster but not compensation.
class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    required this.jobRole,
    required this.department,
    required this.nationality,
    this.contact,
    this.emiratesId,
    this.passportNo,
    this.visaExpiry,
    this.joinDate,
    this.salaryAED,
    this.documents = const [],
    this.status = EmployeeStatus.active,
  });

  final String id;
  final String fullName;
  final String jobRole;
  final String department;
  final String nationality;
  final String? contact;

  // ── Restricted (Admin only) ──
  final String? emiratesId;
  final String? passportNo;
  final DateTime? visaExpiry;
  final DateTime? joinDate;
  final double? salaryAED;
  final List<String> documents;

  final EmployeeStatus status;

  String get initials {
    final parts = fullName
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

  Employee copyWith({
    String? fullName,
    String? jobRole,
    String? department,
    String? nationality,
    String? contact,
    String? emiratesId,
    String? passportNo,
    DateTime? visaExpiry,
    DateTime? joinDate,
    double? salaryAED,
    List<String>? documents,
    EmployeeStatus? status,
  }) => Employee(
    id: id,
    fullName: fullName ?? this.fullName,
    jobRole: jobRole ?? this.jobRole,
    department: department ?? this.department,
    nationality: nationality ?? this.nationality,
    contact: contact ?? this.contact,
    emiratesId: emiratesId ?? this.emiratesId,
    passportNo: passportNo ?? this.passportNo,
    visaExpiry: visaExpiry ?? this.visaExpiry,
    joinDate: joinDate ?? this.joinDate,
    salaryAED: salaryAED ?? this.salaryAED,
    documents: documents ?? this.documents,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'jobRole': jobRole,
    'department': department,
    'nationality': nationality,
    'contact': contact,
    'emiratesId': emiratesId,
    'passportNo': passportNo,
    'visaExpiry': visaExpiry?.toIso8601String(),
    'joinDate': joinDate?.toIso8601String(),
    'salaryAED': salaryAED,
    'documents': documents,
    'status': status.name,
  };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    jobRole: json['jobRole'] as String? ?? '',
    department: json['department'] as String? ?? '',
    nationality: json['nationality'] as String? ?? '',
    contact: json['contact'] as String?,
    emiratesId: json['emiratesId'] as String?,
    passportNo: json['passportNo'] as String?,
    visaExpiry: json['visaExpiry'] == null
        ? null
        : DateTime.parse(json['visaExpiry'] as String),
    joinDate: json['joinDate'] == null
        ? null
        : DateTime.parse(json['joinDate'] as String),
    salaryAED: (json['salaryAED'] as num?)?.toDouble(),
    documents:
        (json['documents'] as List<dynamic>?)?.cast<String>() ?? const [],
    status: EmployeeStatus.fromName(json['status'] as String? ?? 'active'),
  );

  static String encodeList(List<Employee> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Employee> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }
}
