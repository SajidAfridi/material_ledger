import 'dart:convert';

/// Annual leave entitlement per calendar year (FR-127).
const int kAnnualLeaveEntitlement = 30;

enum LeaveType {
  annual('Annual', 'سنوية', 'سالانہ', 'वार्षिक'),
  sick('Sick', 'مرضية', 'بیماری', 'बीमारी'),
  unpaid('Unpaid', 'غير مدفوعة', 'بلا معاوضہ', 'अवैतनिक');

  const LeaveType(this.label, this.ar, this.ur, this.hi);
  final String label;
  final String ar;
  final String ur;
  final String hi;

  static LeaveType fromName(String n) =>
      LeaveType.values.firstWhere((t) => t.name == n, orElse: () => annual);
}

enum LeaveRecordStatus {
  pending('Pending', 'معلق', 'زیر التواء', 'लंबित'),
  approved('Approved', 'موافق عليه', 'منظور', 'स्वीकृत'),
  rejected('Rejected', 'مرفوض', 'مسترد', 'अस्वीकृत');

  const LeaveRecordStatus(this.label, this.ar, this.ur, this.hi);
  final String label;
  final String ar;
  final String ur;
  final String hi;

  static LeaveRecordStatus fromName(String n) =>
      LeaveRecordStatus.values.firstWhere(
        (s) => s.name == n,
        orElse: () => pending,
      );
}

/// A leave request/record for an employee (FR-126).
class LeaveRecord {
  const LeaveRecord({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    this.status = LeaveRecordStatus.pending,
    this.approvedBy,
    this.note,
  });

  final String id;
  final String employeeId;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final LeaveRecordStatus status;
  final String? approvedBy;
  final String? note;

  LeaveRecord copyWith({
    LeaveRecordStatus? status,
    String? approvedBy,
  }) => LeaveRecord(
    id: id,
    employeeId: employeeId,
    type: type,
    startDate: startDate,
    endDate: endDate,
    days: days,
    status: status ?? this.status,
    approvedBy: approvedBy ?? this.approvedBy,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'type': type.name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'days': days,
    'status': status.name,
    'approvedBy': approvedBy,
    'note': note,
  };

  factory LeaveRecord.fromJson(Map<String, dynamic> json) => LeaveRecord(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    type: LeaveType.fromName(json['type'] as String? ?? 'annual'),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    days: json['days'] as int,
    status: LeaveRecordStatus.fromName(json['status'] as String? ?? 'pending'),
    approvedBy: json['approvedBy'] as String?,
    note: json['note'] as String?,
  );

  static String encodeList(List<LeaveRecord> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<LeaveRecord> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => LeaveRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
