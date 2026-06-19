import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';

/// The signed-in employee's HR self-profile (identity, attendance, leaves).
final employeeProvider = Provider<EmployeeProfile>((ref) => _seedEmployee);

const _seedEmployee = EmployeeProfile(
  name: 'Imran Khalid',
  nameAr: 'عمران خالد',
  title: 'Site Engineer',
  titleAr: 'مهندس موقع',
  employeeId: 'ENG-10041',
  email: 'imran.khalid@yorksac.ae',
  phone: '+971 50 123 4567',
  department: 'HVAC Projects',
  departmentAr: 'مشاريع التكييف',
  attendance: Attendance(
    checkIn: '8:00 AM',
    checkOut: '4:30 PM',
    remainingHours: 3,
  ),
  leaves: [
    LeaveBalance(
      kind: LeaveKind.annual,
      labelEn: 'Annual',
      labelAr: 'دورية',
      used: 3,
      total: 12,
    ),
    LeaveBalance(
      kind: LeaveKind.casual,
      labelEn: 'Casual',
      labelAr: 'عارضة',
      used: 7,
      total: 12,
    ),
    LeaveBalance(
      kind: LeaveKind.sick,
      labelEn: 'Sick',
      labelAr: 'مرضية',
      used: 1,
      total: 15,
    ),
    LeaveBalance(
      kind: LeaveKind.overtime,
      labelEn: 'Overtime comp',
      labelAr: 'تعويض إضافي',
      used: 1,
    ),
  ],
);
