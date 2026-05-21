import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_language.dart';
import '../models/app_notification.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';

/// Shared Notifications screen — accessible by all roles.
///
/// Responsive: single-column on mobile, constrained max-width on desktop.
/// Follows "The Architectural Ledger" design: tonal layering, bilingual,
/// no borders, extreme white space.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final notifications = ref.watch(filteredNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final urgentCount = ref.watch(urgentNotificationCountProvider);
    final filter = ref.watch(notificationFilterProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: [
                // ─── App Bar ───────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _NotificationsAppBar(
                      unreadCount: unreadCount,
                      onMarkAllRead: () => ref
                          .read(notificationsProvider.notifier)
                          .markAllRead(),
                      lang: lang,
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.xxl),

                // ─── Stats Row ─────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _StatsRow(
                      unreadCount: unreadCount,
                      urgentCount: urgentCount,
                      isWide: isWide,
                      lang: lang,
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.xxl),

                // ─── Search Bar ────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _SearchBar(
                      controller: _searchController,
                      lang: lang,
                      onChanged: (q) =>
                          ref.read(notificationSearchProvider.notifier).state =
                              q,
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.lg),

                // ─── Filter Chips ──────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _FilterChips(
                      selected: filter,
                      onChanged: (f) =>
                          ref.read(notificationFilterProvider.notifier).state =
                              f,
                    ),
                  ),
                ),

                const SliverGap(AppSpacing.xl),

                // ─── Section Header ────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _SectionDivider(lang: lang),
                  ),
                ),

                const SliverGap(AppSpacing.lg),

                // ─── Notification List or Empty State ──────────
                if (notifications.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(lang: lang, filter: filter),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    sliver: SliverList.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, i) =>
                          const Gap(AppSpacing.listItemGap),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return notif.isBanner
                            ? _BannerCard(notification: notif)
                            : _NotificationCard(
                                notification: notif,
                                onTap: () => ref
                                    .read(notificationsProvider.notifier)
                                    .markRead(notif.id),
                                onDismiss: () => ref
                                    .read(notificationsProvider.notifier)
                                    .dismiss(notif.id),
                              );
                      },
                    ),
                  ),

                const SliverGap(AppSpacing.colossal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────
class _NotificationsAppBar extends StatelessWidget {
  const _NotificationsAppBar({
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.lang,
  });

  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(foregroundColor: AppColors.onSurface),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: BilingualText(
            english: AppStrings.notifications.primary,
            secondary: AppStrings.notifications.secondary(lang),
            englishStyle: AppTypography.titleLarge,
          ),
        ),
        if (unreadCount > 0)
          TextButton(
            onPressed: onMarkAllRead,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(
              AppStrings.markAllRead.primary,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Stats Row ───────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.unreadCount,
    required this.urgentCount,
    required this.isWide,
    required this.lang,
  });

  final int unreadCount;
  final int urgentCount;
  final bool isWide;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _StatCard.pending(count: unreadCount, lang: lang),
          ),
          const Gap(AppSpacing.lg),
          Expanded(
            child: _StatCard.urgent(count: urgentCount, lang: lang),
          ),
          const Gap(AppSpacing.lg),
          Expanded(child: _HealthBannerCard(lang: lang)),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: _StatCard.pending(count: unreadCount, lang: lang),
          ),
          const Gap(AppSpacing.md),
          SizedBox(
            width: 160,
            child: _StatCard.urgent(count: urgentCount, lang: lang),
          ),
          const Gap(AppSpacing.md),
          SizedBox(width: 240, child: _HealthBannerCard(lang: lang)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.labelSecondary,
    required this.count,
    required this.countColor,
    required this.icon,
    required this.iconColor,
  });

  factory _StatCard.pending({required int count, required AppLanguage lang}) {
    return _StatCard(
      label: AppStrings.totalPending.primary,
      labelSecondary: AppStrings.totalPending.secondary(lang),
      count: count,
      countColor: AppColors.onSurface,
      icon: Icons.pending_actions_rounded,
      iconColor: AppColors.primary,
    );
  }

  factory _StatCard.urgent({required int count, required AppLanguage lang}) {
    return _StatCard(
      label: AppStrings.urgentAlerts.primary,
      labelSecondary: AppStrings.urgentAlerts.secondary(lang),
      count: count,
      countColor: AppColors.error,
      icon: Icons.priority_high_rounded,
      iconColor: AppColors.error,
    );
  }

  final String label;
  final String labelSecondary;
  final int count;
  final Color countColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(AppSpacing.xs),
              Icon(icon, size: 18, color: iconColor.withValues(alpha: 0.6)),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            count.toString().padLeft(2, '0'),
            style: GoogleFonts.inter(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: countColor,
              height: 1.0,
              letterSpacing: -1.0,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            labelSecondary,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HealthBannerCard extends StatelessWidget {
  const _HealthBannerCard({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  AppStrings.notificationHealth.primary.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Gap(AppSpacing.xs),
              Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            AppStrings.responseRateUp.primary,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            AppStrings.responseRateUp.secondary(lang),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.lang,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AppLanguage lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.lg),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: AppStrings.searchAlerts.primary,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Text(
              AppStrings.searchAlerts.secondary(lang),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                height: 1.5,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chips ─────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: AppStrings.filterAllUpper.primary,
            isSelected: selected == NotificationFilter.all,
            onTap: () => onChanged(NotificationFilter.all),
          ),
          const Gap(AppSpacing.sm),
          _Chip(
            label: AppStrings.filterUnread.primary,
            isSelected: selected == NotificationFilter.unread,
            onTap: () => onChanged(NotificationFilter.unread),
          ),
          const Gap(AppSpacing.sm),
          _Chip(
            label: AppStrings.filterUrgent.primary,
            isSelected: selected == NotificationFilter.urgent,
            isUrgent: true,
            onTap: () => onChanged(NotificationFilter.urgent),
          ),
          const Gap(AppSpacing.sm),
          _Chip(
            label: AppStrings.filterLast24h.primary,
            isSelected: selected == NotificationFilter.last24h,
            onTap: () => onChanged(NotificationFilter.last24h),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isUrgent = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final activeColor = isUrgent ? AppColors.error : AppColors.primary;

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
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section Divider ─────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          AppStrings.latestActivity.primary.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Gap(AppSpacing.sm),
        Text(
          '•',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        const Gap(AppSpacing.sm),
        Flexible(
          child: Text(
            AppStrings.latestActivity.secondary(lang),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (accentColor, iconData, iconColor, iconBg) = _typeStyle();

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          hoverColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              color: notification.isRead
                  ? AppColors.surfaceContainerLowest
                  : AppColors.primaryFixed.withValues(alpha: 0.18),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Left Accent Bar ──────────────────────
                    Container(
                      width: 4,
                      color: notification.isRead
                          ? accentColor.withValues(alpha: 0.3)
                          : accentColor,
                    ),

                    // ─── Main Content ─────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Icon ──────────────────────
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  iconData,
                                  size: 22,
                                  color: iconColor,
                                ),
                              ),
                            ),
                            const Gap(AppSpacing.lg),

                            // ─── Text Content ──────────────
                            Expanded(
                              child: _CardContent(notification: notification),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Action Buttons Column ────────────────
                    _ActionButtons(
                      notification: notification,
                      onPrimary: onTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData, Color, Color) _typeStyle() {
    return switch (notification.type) {
      NotificationType.approved => (
        AppColors.primary,
        Icons.check_circle_rounded,
        AppColors.primary,
        AppColors.primaryFixed,
      ),
      NotificationType.lowStock => (
        AppColors.error,
        Icons.warning_amber_rounded,
        AppColors.warning,
        AppColors.warningContainer,
      ),
      NotificationType.dispatched => (
        AppColors.primary,
        Icons.local_shipping_outlined,
        AppColors.primary,
        AppColors.surfaceContainerHigh,
      ),
      NotificationType.message => (
        AppColors.secondary,
        Icons.chat_bubble_outline_rounded,
        AppColors.secondary,
        AppColors.secondaryContainer,
      ),
      NotificationType.rejected => (
        AppColors.error,
        Icons.cancel_outlined,
        AppColors.error,
        AppColors.errorContainer,
      ),
      NotificationType.weeklySummary => (
        AppColors.primary,
        Icons.bar_chart_rounded,
        AppColors.primary,
        AppColors.primaryFixed,
      ),
      NotificationType.info => (
        AppColors.outline,
        Icons.info_outline_rounded,
        AppColors.onSurfaceVariant,
        AppColors.surfaceContainerHigh,
      ),
    };
  }
}

// ─── Card Content ─────────────────────────────────────────────────
class _CardContent extends StatelessWidget {
  const _CardContent({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Chip + Time + Project ──────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chip
            if (notification.chipLabel != null)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: _chipColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    notification.chipLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: _chipColor(),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (notification.chipLabel != null) const Gap(AppSpacing.sm),

            // Time
            Text(
              notification.relativeTime,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),

        // ─── Title + Project Tag Row ─────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w600
                          : FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.35,
                    ),
                  ),
                  if (notification.titleSecondary.isNotEmpty) ...[
                    const Gap(AppSpacing.xxs),
                    Text(
                      notification.titleSecondary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ],
              ),
            ),

            // Project Tag
            if (notification.project != null) ...[
              const Gap(AppSpacing.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      notification.project!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    if (notification.projectSecondary != null)
                      Text(
                        notification.projectSecondary!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.end,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),

        // ─── Initiator Row ───────────────────────────────────
        if (notification.initiatorAction != null) ...[
          const Gap(AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: notification.initiatorName != null
                        ? AppColors.primaryFixed
                        : AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      notification.initiatorName != null
                          ? Icons.person_rounded
                          : Icons.settings_outlined,
                      size: 13,
                      color: notification.initiatorName != null
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notification.initiatorName != null)
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurface,
                            ),
                            children: [
                              TextSpan(
                                text: '${notification.initiatorName} ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: notification.initiatorRole != null
                                    ? '(${notification.initiatorRole}) '
                                    : '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              TextSpan(
                                text: notification.initiatorAction ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          notification.initiatorAction!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      if (notification.initiatorActionSecondary != null) ...[
                        const Gap(AppSpacing.xxs),
                        Text(
                          notification.initiatorActionSecondary!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ─── Action Label (message type) ─────────────────────
        if (notification.actionLabel != null) ...[
          const Gap(AppSpacing.sm),
          GestureDetector(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Gap(AppSpacing.xs),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _chipColor() {
    return switch (notification.type) {
      NotificationType.approved => AppColors.primary,
      NotificationType.lowStock => AppColors.error,
      NotificationType.rejected => AppColors.error,
      NotificationType.dispatched => AppColors.primary,
      NotificationType.message => AppColors.secondary,
      NotificationType.weeklySummary => AppColors.primary,
      NotificationType.info => AppColors.onSurfaceVariant,
    };
  }
}

// ─── Action Buttons ───────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.notification, required this.onPrimary});

  final AppNotification notification;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final buttons = _buildButtons();
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppSpacing.radiusLg),
          bottomRight: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:
            buttons
                .expand((b) => [b, const SizedBox(height: AppSpacing.xs)])
                .toList()
              ..removeLast(),
      ),
    );
  }

  List<Widget> _buildButtons() {
    return switch (notification.type) {
      NotificationType.approved => [
        _ActionBtn(
          icon: Icons.check_rounded,
          color: AppColors.primary,
          bg: AppColors.primaryFixed,
          onTap: onPrimary,
        ),
        _ActionBtn(
          icon: Icons.visibility_outlined,
          color: AppColors.onSurfaceVariant,
          bg: AppColors.surfaceContainerHighest,
          onTap: onPrimary,
        ),
      ],
      NotificationType.lowStock => [
        _ActionBtn(
          icon: Icons.shopping_cart_outlined,
          color: AppColors.warning,
          bg: AppColors.warningContainer,
          onTap: onPrimary,
        ),
      ],
      NotificationType.rejected => [
        _ActionBtn(
          icon: Icons.edit_outlined,
          color: AppColors.onSurfaceVariant,
          bg: AppColors.surfaceContainerHighest,
          onTap: onPrimary,
        ),
      ],
      NotificationType.dispatched => [
        _ActionBtn(
          icon: Icons.receipt_outlined,
          color: AppColors.onSurfaceVariant,
          bg: AppColors.surfaceContainerHighest,
          onTap: onPrimary,
        ),
      ],
      NotificationType.message => [
        _ActionBtn(
          icon: Icons.reply_rounded,
          color: AppColors.secondary,
          bg: AppColors.secondaryContainer,
          onTap: onPrimary,
        ),
      ],
      _ => [],
    };
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Center(child: Icon(icon, size: 18, color: color)),
      ),
    );
  }
}

// ─── Banner Card (Weekly Summary / Health) ────────────────────────
class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (notification.bannerLabel ?? 'SUMMARY').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const Gap(AppSpacing.md),
                Text(
                  notification.bannerHeadline ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Text(
                  notification.relativeTime,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.lg),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Center(
              child: Icon(
                Icons.bar_chart_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang, required this.filter});

  final AppLanguage lang;
  final NotificationFilter filter;

  @override
  Widget build(BuildContext context) {
    final isEmpty = filter == NotificationFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEmpty
                  ? Icons.notifications_none_rounded
                  : Icons.filter_list_off_rounded,
              size: 64,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const Gap(AppSpacing.xl),
            Text(
              isEmpty
                  ? "You're all caught up!"
                  : AppStrings.noNotificationsForFilter.primary,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(AppSpacing.sm),
            Text(
              isEmpty
                  ? 'No new notifications at the moment.'
                  : AppStrings.noNotificationsForFilter.secondary(lang),
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
