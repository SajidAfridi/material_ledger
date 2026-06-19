import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/attendance_record.dart';
import '../models/employee_record.dart';
import '../models/leave_record.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';

const _kEmployeesKey = 'employees_v1';
const _kAttendanceKey = 'attendance_v1';
const _kLeaveKey = 'leave_records_v1';
const _uuid = Uuid();

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─── Employees ───────────────────────────────────────────────────

final employeesProvider =
    StateNotifierProvider<EmployeesNotifier, List<Employee>>((ref) {
      return EmployeesNotifier(
        ref,
        ref.watch(storageProvider).collection<Employee>(
          _kEmployeesKey,
          toJson: (e) => e.toJson(),
          fromJson: Employee.fromJson,
        ),
      );
    });

class EmployeesNotifier extends StateNotifier<List<Employee>> {
  EmployeesNotifier(this._ref, this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seed();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<Employee> _store;

  Employee? byId(String id) {
    for (final e in state) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<Employee> addEmployee({
    required String fullName,
    required String jobRole,
    required String department,
    required String nationality,
    String? contact,
    double? salaryAED,
  }) async {
    final e = Employee(
      id: 'emp-${_uuid.v4().substring(0, 8)}',
      fullName: fullName,
      jobRole: jobRole,
      department: department,
      nationality: nationality,
      contact: contact,
      salaryAED: salaryAED,
      joinDate: DateTime.now(),
    );
    state = [e, ...state];
    await _store.writeAll(state);
    await _syncEmployee(e, kind: 'employee.create');
    return e;
  }

  Future<void> updateEmployee(Employee updated) async {
    state = [
      for (final e in state)
        if (e.id == updated.id) updated else e,
    ];
    await _store.writeAll(state);
    await _syncEmployee(updated, kind: 'employee.update');
  }

  Future<void> _syncEmployee(Employee e, {required String kind}) {
    return _ref.enqueueSync(
      collection: 'employees',
      docId: e.id,
      kind: kind,
      label: 'Employee',
      payload: e.toJson(),
    );
  }

  static List<Employee> _seed() {
    final now = DateTime.now();
    return [
      Employee(
        id: 'emp-001',
        fullName: 'Ahmed Khan',
        jobRole: 'Site Engineer',
        department: 'Projects',
        nationality: 'Pakistan',
        contact: '+971 50 111 2222',
        emiratesId: '784-1990-1234567-1',
        passportNo: 'AB1234567',
        visaExpiry: DateTime(now.year + 1, 4, 15),
        joinDate: DateTime(now.year - 3, 2, 1),
        salaryAED: 6500,
        status: EmployeeStatus.active,
      ),
      Employee(
        id: 'emp-002',
        fullName: 'Bilal Hassan',
        jobRole: 'Procurement Officer',
        department: 'Procurement',
        nationality: 'Pakistan',
        contact: '+971 55 333 4444',
        emiratesId: '784-1988-7654321-2',
        joinDate: DateTime(now.year - 2, 7, 10),
        salaryAED: 7200,
        status: EmployeeStatus.active,
      ),
      Employee(
        id: 'emp-003',
        fullName: 'Rajesh Kumar',
        jobRole: 'HVAC Technician',
        department: 'Operations',
        nationality: 'India',
        contact: '+971 52 555 6666',
        joinDate: DateTime(now.year - 1, 11, 5),
        salaryAED: 4200,
        status: EmployeeStatus.onLeave,
      ),
      Employee(
        id: 'emp-004',
        fullName: 'Maria Santos',
        jobRole: 'Accountant',
        department: 'Finance',
        nationality: 'Philippines',
        contact: '+971 56 777 8888',
        joinDate: DateTime(now.year - 4, 1, 20),
        salaryAED: 8000,
        status: EmployeeStatus.active,
      ),
      Employee(
        id: 'emp-005',
        fullName: 'Omar Farouk',
        jobRole: 'Duct Fabricator',
        department: 'Operations',
        nationality: 'Egypt',
        contact: '+971 50 999 0000',
        joinDate: DateTime(now.year - 1, 3, 12),
        salaryAED: 3800,
        status: EmployeeStatus.active,
      ),
    ];
  }
}

// ─── Attendance ──────────────────────────────────────────────────

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, List<AttendanceRecord>>((ref) {
      return AttendanceNotifier(
        ref,
        ref.watch(storageProvider).collection<AttendanceRecord>(
          _kAttendanceKey,
          toJson: (a) => a.toJson(),
          fromJson: AttendanceRecord.fromJson,
        ),
      );
    });

class AttendanceNotifier extends StateNotifier<List<AttendanceRecord>> {
  AttendanceNotifier(this._ref, this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seed();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<AttendanceRecord> _store;

  /// Set today's attendance for an employee (one record per day — upsert).
  Future<void> markToday({
    required String employeeId,
    required AttendanceStatus status,
    String? note,
    required String recordedBy,
  }) async {
    final today = _dayKey(DateTime.now());
    final idx = state.indexWhere(
      (a) => a.employeeId == employeeId && a.dayKey == today,
    );
    final record = AttendanceRecord(
      id: idx >= 0 ? state[idx].id : 'att-${_uuid.v4().substring(0, 8)}',
      employeeId: employeeId,
      date: DateTime.now(),
      status: status,
      note: note,
      recordedBy: recordedBy,
    );
    state = idx >= 0
        ? [for (var i = 0; i < state.length; i++) if (i == idx) record else state[i]]
        : [record, ...state];
    await _store.writeAll(state);
    await _ref.enqueueSync(
      collection: 'attendance',
      docId: record.id,
      kind: 'attendance.mark',
      label: 'Attendance',
      payload: record.toJson(),
    );
  }

  AttendanceRecord? todayFor(String employeeId) {
    final today = _dayKey(DateTime.now());
    for (final a in state) {
      if (a.employeeId == employeeId && a.dayKey == today) return a;
    }
    return null;
  }

  static List<AttendanceRecord> _seed() {
    final now = DateTime.now();
    AttendanceRecord rec(String emp, AttendanceStatus s) => AttendanceRecord(
      id: 'att-seed-$emp',
      employeeId: emp,
      date: now,
      status: s,
      recordedBy: 'Owner (Admin)',
    );
    return [
      rec('emp-001', AttendanceStatus.present),
      rec('emp-002', AttendanceStatus.present),
      rec('emp-003', AttendanceStatus.onLeave),
      rec('emp-004', AttendanceStatus.present),
      rec('emp-005', AttendanceStatus.absent),
    ];
  }
}

// ─── Leave records ───────────────────────────────────────────────

final leaveRecordsProvider =
    StateNotifierProvider<LeaveNotifier, List<LeaveRecord>>((ref) {
      return LeaveNotifier(
        ref,
        ref.watch(storageProvider).collection<LeaveRecord>(
          _kLeaveKey,
          toJson: (l) => l.toJson(),
          fromJson: LeaveRecord.fromJson,
        ),
      );
    });

class LeaveNotifier extends StateNotifier<List<LeaveRecord>> {
  LeaveNotifier(this._ref, this._store) : super([]) {
    state = _store.isSeeded ? _store.readAll() : _seed();
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<LeaveRecord> _store;

  List<LeaveRecord> forEmployee(String employeeId) =>
      state.where((l) => l.employeeId == employeeId).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  Future<LeaveRecord> addLeave({
    required String employeeId,
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    LeaveRecordStatus status = LeaveRecordStatus.approved,
    String? approvedBy,
    String? note,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    final record = LeaveRecord(
      id: 'leave-${_uuid.v4().substring(0, 8)}',
      employeeId: employeeId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      days: days < 1 ? 1 : days,
      status: status,
      approvedBy: approvedBy,
      note: note,
    );
    state = [record, ...state];
    await _store.writeAll(state);
    await _syncLeave(record, kind: 'leave.create');
    return record;
  }

  Future<void> setStatus(
    String id,
    LeaveRecordStatus status, {
    String? approvedBy,
  }) async {
    state = [
      for (final l in state)
        if (l.id == id) l.copyWith(status: status, approvedBy: approvedBy) else l,
    ];
    await _store.writeAll(state);
    for (final l in state) {
      if (l.id == id) {
        await _syncLeave(l, kind: 'leave.status');
        break;
      }
    }
  }

  Future<void> _syncLeave(LeaveRecord l, {required String kind}) {
    return _ref.enqueueSync(
      collection: 'leaveRecords',
      docId: l.id,
      kind: kind,
      label: 'Leave',
      payload: l.toJson(),
    );
  }

  static List<LeaveRecord> _seed() {
    final now = DateTime.now();
    return [
      LeaveRecord(
        id: 'leave-seed-01',
        employeeId: 'emp-001',
        type: LeaveType.annual,
        startDate: DateTime(now.year, 2, 10),
        endDate: DateTime(now.year, 2, 17),
        days: 8,
        status: LeaveRecordStatus.approved,
        approvedBy: 'Owner (Admin)',
      ),
      LeaveRecord(
        id: 'leave-seed-02',
        employeeId: 'emp-003',
        type: LeaveType.annual,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 5)),
        days: 7,
        status: LeaveRecordStatus.approved,
        approvedBy: 'Owner (Admin)',
      ),
      LeaveRecord(
        id: 'leave-seed-03',
        employeeId: 'emp-002',
        type: LeaveType.sick,
        startDate: DateTime(now.year, 1, 8),
        endDate: DateTime(now.year, 1, 9),
        days: 2,
        status: LeaveRecordStatus.approved,
        approvedBy: 'Owner (Admin)',
      ),
    ];
  }
}

// ─── Derived: leave balance ──────────────────────────────────────

class LeaveBalance {
  const LeaveBalance({required this.entitlement, required this.usedAnnual});
  final int entitlement;
  final int usedAnnual;
  int get remaining => (entitlement - usedAnnual).clamp(0, entitlement);
}

/// Annual-leave balance for an employee: 30 − approved annual days taken in the
/// current calendar year (FR-127).
final leaveBalanceProvider = Provider.family<LeaveBalance, String>((
  ref,
  employeeId,
) {
  final records = ref.watch(leaveRecordsProvider);
  final year = DateTime.now().year;
  var used = 0;
  for (final l in records) {
    if (l.employeeId != employeeId) continue;
    if (l.type != LeaveType.annual) continue;
    if (l.status != LeaveRecordStatus.approved) continue;
    if (l.startDate.year != year) continue;
    used += l.days;
  }
  return LeaveBalance(entitlement: kAnnualLeaveEntitlement, usedAnnual: used);
});

// ─── Derived: HR dashboard summary ───────────────────────────────

class HrSummary {
  const HrSummary({
    required this.total,
    required this.presentToday,
    required this.onLeaveToday,
    required this.absentToday,
  });
  final int total;
  final int presentToday;
  final int onLeaveToday;
  final int absentToday;
}

final hrSummaryProvider = Provider<HrSummary>((ref) {
  final employees = ref.watch(employeesProvider);
  final attendance = ref.watch(attendanceProvider);
  final today = _dayKey(DateTime.now());

  var present = 0, onLeave = 0, absent = 0;
  for (final e in employees) {
    AttendanceRecord? rec;
    for (final a in attendance) {
      if (a.employeeId == e.id && a.dayKey == today) {
        rec = a;
        break;
      }
    }
    switch (rec?.status) {
      case AttendanceStatus.present:
      case AttendanceStatus.halfDay:
        present++;
      case AttendanceStatus.onLeave:
        onLeave++;
      case AttendanceStatus.absent:
        absent++;
      case null:
        break;
    }
  }

  return HrSummary(
    total: employees.length,
    presentToday: present,
    onLeaveToday: onLeave,
    absentToday: absent,
  );
});
