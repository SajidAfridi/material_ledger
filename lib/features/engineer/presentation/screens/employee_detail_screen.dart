import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/employee.dart';
import '../../../../shared/providers/employee_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Engineer self-profile — identity, today's attendance, leave balance,
/// employment details and quick links to their day-to-day work. Every figure is
/// live (see [employeeProvider]); an unlinked login shows a "not linked" note in
/// place of the HR sections. Opened from the "My data" card on the home screen.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final emp = ref.watch(employeeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.myProfile.primary,
          secondary: AppStrings.myProfile.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            _ProfileHeader(emp: emp),
            const Gap(AppSpacing.lg),
            if (emp.linked) ...[
              _AttendanceSection(emp: emp, lang: lang),
              const Gap(AppSpacing.lg),
              _LeaveSection(emp: emp, lang: lang),
              const Gap(AppSpacing.lg),
              _EmploymentSection(emp: emp, lang: lang),
            ] else
              _UnlinkedNote(lang: lang),
            // Engineer-only shortcuts (New request / My projects / My requests).
            // The New Request target lives only in the engineer shell, so office
            // roles (who can reach this screen via the shared profile card) don't
            // see these links.
            if (!ref.watch(currentRoleProvider).usesAdminPanel) ...[
              const Gap(AppSpacing.lg),
              _QuickLinksSection(lang: lang),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.emp});

  final EmployeeProfile emp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  emp.initials,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Gap(AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      emp.linked ? '${emp.title} · ${emp.employeeId}' : emp.title,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.lg),
          Container(
            height: 1,
            color: AppColors.onPrimary.withValues(alpha: 0.2),
          ),
          const Gap(AppSpacing.md),
          _ContactRow(icon: Icons.mail_outline_rounded, value: emp.email),
          if (emp.phone != '—') ...[
            const Gap(AppSpacing.sm),
            _ContactRow(icon: Icons.phone_outlined, value: emp.phone),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.onPrimary.withValues(alpha: 0.9)),
        const Gap(AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Section scaffold ───────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.titleSecondary,
    required this.child,
  });

  final String title;
  final String titleSecondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            english: title,
            secondary: titleSecondary,
            englishStyle: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
            secondaryStyle: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

// ─── Unlinked note ──────────────────────────────────────────────────
class _UnlinkedNote extends StatelessWidget {
  const _UnlinkedNote({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_off_rounded,
              size: 22, color: AppColors.onSurfaceVariant),
          const Gap(AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.notLinkedToEmployee.primary,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attendance ─────────────────────────────────────────────────────
class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final v = _attendanceView(emp.today);
    return _Section(
      title: AppStrings.attendanceSection.primary,
      titleSecondary: AppStrings.attendanceSection.secondary(lang),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(v.icon, size: 22, color: v.color),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.todayLabel.primary,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Gap(2),
                Text(
                  v.label,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: v.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leave balance ──────────────────────────────────────────────────
class _LeaveSection extends StatelessWidget {
  const _LeaveSection({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final unit = AppStrings.daysUnit.primary;
    final fraction = emp.annualEntitlement > 0
        ? (emp.annualUsed / emp.annualEntitlement).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return _Section(
      title: AppStrings.leavesSection.primary,
      titleSecondary: AppStrings.leavesSection.secondary(lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.annualLeftLabel.primary,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${emp.annualRemaining} / ${emp.annualEntitlement} $unit',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (emp.pendingRequests > 0) ...[
            const Gap(AppSpacing.md),
            Row(
              children: [
                Icon(Icons.pending_actions_rounded,
                    size: 16, color: AppColors.warning),
                const Gap(AppSpacing.sm),
                Text(
                  '${emp.pendingRequests} ${AppStrings.pendingLabel.primary.toLowerCase()}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Employment details ─────────────────────────────────────────────
class _EmploymentSection extends StatelessWidget {
  const _EmploymentSection({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final tenure = emp.tenureLabel(DateTime.now());
    return _Section(
      title: AppStrings.employmentSection.primary,
      titleSecondary: AppStrings.employmentSection.secondary(lang),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.badge_outlined,
            label: AppStrings.employeeIdLabel.primary,
            value: emp.employeeId,
          ),
          const Gap(AppSpacing.md),
          _DetailRow(
            icon: Icons.apartment_outlined,
            label: AppStrings.departmentLabel.primary,
            value: emp.department,
          ),
          const Gap(AppSpacing.md),
          _DetailRow(
            icon: Icons.engineering_outlined,
            label: AppStrings.roleLabel.primary,
            value: emp.title,
          ),
          const Gap(AppSpacing.md),
          _DetailRow(
            icon: Icons.public_outlined,
            label: AppStrings.nationalityLabel.primary,
            value: emp.nationality,
          ),
          if (emp.joinDate != null) ...[
            const Gap(AppSpacing.md),
            _DetailRow(
              icon: Icons.event_outlined,
              label: AppStrings.joinedLabel.primary,
              value: DateFormat('d MMM yyyy').format(emp.joinDate!),
            ),
          ],
          if (tenure != null) ...[
            const Gap(AppSpacing.md),
            _DetailRow(
              icon: Icons.hourglass_bottom_outlined,
              label: AppStrings.tenureLabelText.primary,
              value: tenure,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        const Gap(AppSpacing.md),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Quick links ────────────────────────────────────────────────────
class _QuickLinksSection extends StatelessWidget {
  const _QuickLinksSection({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: AppStrings.quickLinksSection.primary,
      titleSecondary: AppStrings.quickLinksSection.secondary(lang),
      child: Column(
        children: [
          _QuickLink(
            icon: Icons.add_box_outlined,
            label: AppStrings.newRequest.primary,
            // Activate the New Request shell branch (engineer shell only).
            onTap: () => context.go(RoutePaths.engineerNewRequest),
          ),
          const Gap(AppSpacing.xs),
          _QuickLink(
            icon: Icons.folder_open_outlined,
            label: AppStrings.myProjects.primary,
            // Push the standalone (framed) projects view so back returns here.
            onTap: () => context.push(RoutePaths.engineerProjectsView),
          ),
          const Gap(AppSpacing.xs),
          _QuickLink(
            icon: Icons.receipt_long_outlined,
            label: AppStrings.myRequests.primary,
            onTap: () => context.push(RoutePaths.requests),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const Gap(AppSpacing.md),
            Expanded(
              child: Text(label, style: AppTypography.bodyLarge),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon / bilingual-ready label / colour for a [SelfAttendance] state.
({IconData icon, String label, Color color}) _attendanceView(SelfAttendance s) {
  return switch (s) {
    SelfAttendance.present => (
      icon: Icons.check_circle_rounded,
      label: 'Present',
      color: AppColors.success,
    ),
    SelfAttendance.halfDay => (
      icon: Icons.timelapse_rounded,
      label: 'Half day',
      color: AppColors.warning,
    ),
    SelfAttendance.onLeave => (
      icon: Icons.beach_access_rounded,
      label: 'On leave',
      color: AppColors.primary,
    ),
    SelfAttendance.absent => (
      icon: Icons.cancel_rounded,
      label: 'Absent',
      color: AppColors.error,
    ),
    SelfAttendance.notMarked => (
      icon: Icons.remove_circle_outline_rounded,
      label: AppStrings.notMarkedYet.primary,
      color: AppColors.onSurfaceVariant,
    ),
  };
}
