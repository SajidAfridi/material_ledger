import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/employee.dart';
import '../../../../shared/providers/employee_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Engineer self-profile — identity, today's attendance, leave balances,
/// employment details and quick links to their day-to-day work. Opened from the
/// "My data" attendance card on the home screen.
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
            _ProfileHeader(emp: emp, lang: lang),
            const Gap(AppSpacing.lg),
            _AttendanceSection(emp: emp, lang: lang),
            const Gap(AppSpacing.lg),
            _LeavesSection(emp: emp, lang: lang),
            const Gap(AppSpacing.lg),
            _EmploymentSection(emp: emp, lang: lang),
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
  const _ProfileHeader({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final dynamic lang;

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
                    Text(
                      emp.nameAr,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      '${emp.title} · ${emp.employeeId}',
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
          const Gap(AppSpacing.sm),
          _ContactRow(icon: Icons.phone_outlined, value: emp.phone),
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

// ─── Attendance ─────────────────────────────────────────────────────
class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    final a = emp.attendance;
    return _Section(
      title: AppStrings.attendanceSection.primary,
      titleSecondary: AppStrings.attendanceSection.secondary(lang),
      child: Row(
        children: [
          Expanded(
            child: _AttStat(
              icon: Icons.login_rounded,
              label: AppStrings.checkInLabel.primary,
              value: a.checkIn,
              accent: AppColors.success,
            ),
          ),
          Expanded(
            child: _AttStat(
              icon: Icons.logout_rounded,
              label: AppStrings.checkOutLabel.primary,
              value: a.checkOut,
              accent: AppColors.primary,
            ),
          ),
          Expanded(
            child: _AttStat(
              icon: Icons.timelapse_rounded,
              label: AppStrings.remainingLabel.primary,
              value: '${a.remainingHours} ${AppStrings.hoursUnit.primary}',
              accent: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttStat extends StatelessWidget {
  const _AttStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const Gap(AppSpacing.sm),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Leaves ─────────────────────────────────────────────────────────
class _LeavesSection extends StatelessWidget {
  const _LeavesSection({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final dynamic lang;

  Color _color(LeaveKind k) => switch (k) {
    LeaveKind.annual => AppColors.primary,
    LeaveKind.casual => AppColors.error,
    LeaveKind.sick => AppColors.success,
    LeaveKind.overtime => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: AppStrings.leavesSection.primary,
      titleSecondary: AppStrings.leavesSection.secondary(lang),
      child: Column(
        children: [
          for (var i = 0; i < emp.leaves.length; i++) ...[
            _LeaveRow(leave: emp.leaves[i], color: _color(emp.leaves[i].kind)),
            if (i != emp.leaves.length - 1) const Gap(AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.leave, required this.color});

  final LeaveBalance leave;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final unit = AppStrings.daysUnit.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                leave.labelEn,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              leave.total > 0
                  ? '${leave.used} / ${leave.total} $unit'
                  : '${leave.used} $unit',
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
            value: leave.total > 0 ? leave.fraction : 0.12,
            minHeight: 6,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─── Employment details ─────────────────────────────────────────────
class _EmploymentSection extends StatelessWidget {
  const _EmploymentSection({required this.emp, required this.lang});

  final EmployeeProfile emp;
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
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

  final dynamic lang;

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
