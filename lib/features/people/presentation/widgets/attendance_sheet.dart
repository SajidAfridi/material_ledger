import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/attendance_record.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Mark today's attendance for the workforce — one tap per employee sets
/// present / absent / on-leave / half-day (upserts via `markToday`).
class AttendanceSheet extends ConsumerWidget {
  const AttendanceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AttendanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesProvider);
    final attendance = ref.watch(attendanceProvider);
    final now = DateTime.now();

    AttendanceStatus? statusFor(String empId) {
      for (final a in attendance) {
        if (a.employeeId == empId &&
            a.date.year == now.year &&
            a.date.month == now.month &&
            a.date.day == now.day) {
          return a.status;
        }
      }
      return null;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Today's attendance",
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
              for (final e in employees) ...[
                Text(e.fullName, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in AttendanceStatus.values)
                      _StatusChip(
                        label: s.label,
                        selected: statusFor(e.id) == s,
                        onTap: () => ref.read(attendanceProvider.notifier).markToday(
                              employeeId: e.id,
                              status: s,
                              recordedBy: ref.read(actorNameProvider),
                            ),
                      ),
                  ],
                ),
                const Gap(AppSpacing.lg),
              ],
              const Gap(AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
