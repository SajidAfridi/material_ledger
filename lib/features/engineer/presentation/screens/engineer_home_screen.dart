import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_request_provider.dart';
import '../widgets/request_card.dart';

/// Engineer home screen — Material Requests list.
///
/// Responsive: single-column on mobile, 2-column grid on tablet/desktop.
/// Matches the Architectural Ledger design spec.
class EngineerHomeScreen extends ConsumerWidget {
  const EngineerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final filter = ref.watch(requestFilterProvider);
    final requests = ref.watch(filteredRequestsProvider);
    final pendingCount = ref.watch(pendingRequestCountProvider);
    final draftCount = ref.watch(draftRequestCountProvider);
    final allRequests = ref.watch(materialRequestsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useGrid = screenWidth >= 840;
    final crossAxisCount = screenWidth >= 1200 ? 3 : 2;

    // True only when no requests exist at all (fresh install / all deleted).
    final hasNoRequestsAtAll = allRequests.isEmpty;
    // True when a filter is active but yields no results.
    final filterIsEmpty = requests.isEmpty && !hasNoRequestsAtAll;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Header Bar ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _EngineerAppBar(pendingCount: pendingCount),
            ),
          ),

          // ─── Title ───────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: BilingualText(
                english: AppStrings.materialRequests.primary,
                secondary: AppStrings.materialRequests.secondary(lang),
                englishStyle: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.28,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),

          // ─── Quick Stats ────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  _QuickStatBadge(
                    label: 'Total',
                    count: allRequests.length,
                    color: AppColors.primary,
                  ),
                  const Gap(AppSpacing.sm),
                  _QuickStatBadge(
                    label: 'Pending',
                    count: pendingCount,
                    color: AppColors.warning,
                  ),
                  if (draftCount > 0) ...[
                    const Gap(AppSpacing.sm),
                    _QuickStatBadge(
                      label: 'Drafts',
                      count: draftCount,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ─── Filter Tabs ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: _FilterTabs(
                selected: filter,
                onChanged: (f) =>
                    ref.read(requestFilterProvider.notifier).state = f,
                lang: lang,
              ),
            ),
          ),

          // ─── Content: Cards or Empty State ───────────
          if (hasNoRequestsAtAll)
            // Absolutely no requests exist — show full create CTA.
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyContent.noRequests(
                lang: lang,
                onCreateTap: () => context.go(RoutePaths.engineerNewRequest),
              ),
            )
          else if (filterIsEmpty)
            // Filter active but no matching results.
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyContent.noFilterResults(
                filter: filter,
                lang: lang,
                onClearFilter: () =>
                    ref.read(requestFilterProvider.notifier).state =
                        RequestFilter.all,
              ),
            )
          else if (useGrid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: AppSpacing.listItemGap,
                  crossAxisSpacing: AppSpacing.listItemGap,
                  mainAxisExtent: 220,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => RequestCard(
                    request: requests[index],
                    onActionTap: () =>
                        context.go('/request/${requests[index].id}'),
                  ),
                  childCount: requests.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverList.separated(
                itemCount: requests.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                itemBuilder: (context, index) => SizedBox(
                  height: 220,
                  child: RequestCard(
                    request: requests[index],
                    onActionTap: () =>
                        context.go('/request/${requests[index].id}'),
                  ),
                ),
              ),
            ),

          // ─── Bottom Spacing ──────────────────────────
          const SliverGap(AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Empty Content ────────────────────────────────────────────────

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  factory _EmptyContent.noRequests({
    required AppLanguage lang,
    required VoidCallback onCreateTap,
  }) {
    return _EmptyContent(
      icon: Icons.assignment_outlined,
      title: AppStrings.noRequestsYet.primary,
      subtitle: AppStrings.tapToCreateRequest.primary,
      action: _EmptyAction(
        label: 'New Request',
        icon: Icons.add_rounded,
        onTap: onCreateTap,
      ),
    );
  }

  factory _EmptyContent.noFilterResults({
    required RequestFilter filter,
    required AppLanguage lang,
    required VoidCallback onClearFilter,
  }) {
    final (icon, title, subtitle) = switch (filter) {
      RequestFilter.recent => (
        Icons.access_time_outlined,
        'No Recent Requests',
        'There are no requests from the last 7 days.',
      ),
      RequestFilter.drafts => (
        Icons.edit_note_outlined,
        'No Drafts',
        'You have no saved drafts. Start a new request to save as draft.',
      ),
      RequestFilter.all => (
        Icons.assignment_outlined,
        AppStrings.noRequestsYet.primary,
        AppStrings.tapToCreateRequest.primary,
      ),
    };

    return _EmptyContent(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: _EmptyAction(
        label: 'Show All Requests',
        icon: Icons.list_rounded,
        onTap: onClearFilter,
        isSecondary: true,
      ),
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final _EmptyAction action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: LedgerCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(
                      alpha: 0.6,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 36,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const Gap(AppSpacing.xl),
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Gap(AppSpacing.xxl),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSecondary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    if (isSecondary) {
      return SecondaryButton(
        label: label,
        icon: icon,
        isExpanded: false,
        onPressed: onTap,
      );
    }
    return PrimaryButton(
      label: label,
      icon: icon,
      isExpanded: false,
      onPressed: onTap,
    );
  }
}

// ─── Custom App Bar ──────────────────────────────────────────────
class _EngineerAppBar extends StatelessWidget {
  const _EngineerAppBar({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ─── Avatar ──────────────────────────────────────
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
        ),
        const Gap(AppSpacing.md),

        // ─── Brand Name ─────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Architectural Ledger',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Gap(AppSpacing.xxs),
              Text(
                'تعمیراتی لیجر',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),

        // ─── Notification Bell ──────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push(RoutePaths.notifications),
              icon: const Icon(Icons.notifications_outlined),
              style: IconButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            if (pendingCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Filter Tabs ─────────────────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.onChanged,
    required this.lang,
  });

  final RequestFilter selected;
  final ValueChanged<RequestFilter> onChanged;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label:
                '${AppStrings.allRequests.primary} / ${AppStrings.allRequests.secondary(lang)}',
            isSelected: selected == RequestFilter.all,
            onTap: () => onChanged(RequestFilter.all),
          ),
          const Gap(AppSpacing.md),
          _FilterChip(
            label:
                '${AppStrings.recentRequests.primary} / ${AppStrings.recentRequests.secondary(lang)}',
            isSelected: selected == RequestFilter.recent,
            onTap: () => onChanged(RequestFilter.recent),
          ),
          const Gap(AppSpacing.md),
          _FilterChip(
            label:
                '${AppStrings.draftRequests.primary} / ${AppStrings.draftRequests.secondary(lang)}',
            isSelected: selected == RequestFilter.drafts,
            onTap: () => onChanged(RequestFilter.drafts),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Stat Badge ────────────────────────────────────────────
class _QuickStatBadge extends StatelessWidget {
  const _QuickStatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
