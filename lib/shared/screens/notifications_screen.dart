import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_language.dart';
import '../models/app_notification.dart';
import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';

/// Notification centre (SRS §4.6) — a simple, single list of lifecycle alerts
/// with read/unread status. Accessible by all roles. Tap to mark read; swipe to
/// dismiss; "Mark all read" clears the unread state.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    // Role-scoped: each role only sees alerts meant for them (admin sees all).
    final notifications = ref.watch(visibleNotificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final mobile = YorksMobileUi.isActive(context);

    if (mobile) {
      final visible = switch (_filter) {
        _NotificationFilter.all => notifications,
        _NotificationFilter.unread =>
          notifications.where((notification) => !notification.isRead).toList(),
        _NotificationFilter.urgent =>
          notifications
              .where(
                (notification) => notification.type == NotificationType.stock,
              )
              .toList(),
      };
      return Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: Column(
          children: [
            YorksMobileAppBar(
              title: AppStrings.notifications.primary,
              leading: YorksMobileIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.pop(),
              ),
              trailing: unread > 0
                  ? TextButton(
                      onPressed: () =>
                          ref.read(notificationActionsProvider).markAllRead(),
                      child: Text(
                        AppStrings.markAllRead.primary,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.blue,
                        ),
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  for (final filter in _NotificationFilter.values) ...[
                    Expanded(
                      child: YorksMobilePill(
                        label: filter.label.active(lang),
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                    ),
                    if (filter != _NotificationFilter.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(lang: lang)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _NotificationDismissible(
                        notification: visible[index],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: BilingualText(
          english: AppStrings.notifications.primary,
          secondary: AppStrings.notifications.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationActionsProvider).markAllRead(),
              child: Text(AppStrings.markAllRead.primary),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: notifications.isEmpty
              ? _EmptyState(lang: lang)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    return _NotificationDismissible(notification: n);
                  },
                ),
        ),
      ),
    );
  }
}

enum _NotificationFilter {
  all(AppStrings.filterAllUpper),
  unread(AppStrings.filterUnread),
  urgent(AppStrings.filterUrgent);

  const _NotificationFilter(this.label);
  final TranslatableString label;
}

class _NotificationDismissible extends ConsumerWidget {
  const _NotificationDismissible({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
    key: Key(notification.id),
    direction: notification.isServerAuthoritative
        ? DismissDirection.none
        : DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
    ),
    onDismissed: (_) =>
        ref.read(notificationActionsProvider).dismiss(notification),
    child: _NotificationCard(
      notification: notification,
      onTap: () {
        ref.read(notificationActionsProvider).markRead(notification);
        if (notification.route.isNotEmpty) context.push(notification.route);
      },
    ),
  );
}

// ─── Notification card ───────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(notification.type);
    final unread = !notification.isRead;
    return LedgerCard(
      onTap: onTap,
      color: unread
          ? AppColors.primaryContainer.withValues(alpha: 0.10)
          : AppColors.surfaceContainerLowest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      notification.relativeTime,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const Gap(AppSpacing.sm),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notification.titleSecondary.isNotEmpty) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    notification.titleSecondary,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
                if (notification.body.isNotEmpty) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    notification.body,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _style(NotificationType type) => switch (type) {
    NotificationType.plan => (Icons.fact_check_outlined, AppColors.primary),
    NotificationType.request => (
      Icons.local_shipping_outlined,
      AppColors.tertiary,
    ),
    NotificationType.stock => (Icons.warning_amber_rounded, AppColors.warning),
    NotificationType.project => (Icons.domain_add_outlined, AppColors.success),
    NotificationType.info => (
      Icons.info_outline_rounded,
      AppColors.onSurfaceVariant,
    ),
  };
}

// ─── Empty state ─────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const Gap(AppSpacing.lg),
            Text(
              AppStrings.allCaughtUp.primary,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(AppSpacing.xs),
            Text(
              AppStrings.allCaughtUp.secondary(lang),
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
              textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}
