import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/constants.dart';
import '../../core/widgets/widgets.dart';
import '../models/app_language.dart';
import '../models/app_notification.dart';
import '../models/app_strings.dart';
import '../models/notification_experience_strings.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/yorks_v1_notification_provider.dart';
import '../widgets/notification_delivery_card.dart';

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
  final _search = TextEditingController();
  Timer? _searchDebounce;
  _NotificationFilter _filter = _NotificationFilter.all;

  bool get _usesServer => ref.read(supabaseClientProvider) != null;
  YorksV1NotificationsNotifier get _inbox => _usesServer
      ? ref.read(notificationInboxProvider.notifier)
      : ref.read(yorksV1NotificationsProvider.notifier);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Widget _searchField(AppLanguage language) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: TextField(
      controller: _search,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: NotificationExperienceStrings.search.active(language),
        prefixIcon: const Icon(Icons.search),
        counterText: '',
      ),
      onChanged: (value) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            _inbox.search(value.trim());
          }
        });
      },
    ),
  );

  Future<void> _markAll() async {
    try {
      await ref.read(notificationActionsProvider).markAllRead();
      await _inbox.refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              NotificationExperienceStrings.readFailed.active(
                ref.read(languageProvider),
              ),
            ),
          ),
        );
      }
    }
  }

  void _selectFilter(_NotificationFilter value) {
    setState(() => _filter = value);
    _inbox.setUnreadOnly(
      value == _NotificationFilter.unread,
      urgentOnly: value == _NotificationFilter.urgent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    // Role-scoped: each role only sees alerts meant for them (admin sees all).
    final global = ref.watch(visibleNotificationsProvider);
    final inboxState = _usesServer
        ? ref.watch(notificationInboxProvider)
        : ref.watch(yorksV1NotificationsProvider);
    final notifications =
        !_usesServer
              ? [...global]
              : <AppNotification>[
                  ...?inboxState.valueOrNull
                      ?.where((n) => !n.isChatTransport)
                      .map((n) => n.toAppNotification(lang)),
                  ...global.where((n) => !n.isServerAuthoritative),
                ]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final unread = ref.watch(unreadNotificationCountProvider);
    final serverState = inboxState;
    final mobile = YorksMobileUi.isActive(context);
    final visible = switch (_filter) {
      _NotificationFilter.all => notifications,
      _NotificationFilter.unread =>
        notifications.where((notification) => !notification.isRead).toList(),
      _NotificationFilter.urgent =>
        notifications.where((notification) => notification.isUrgent).toList(),
    };

    if (mobile) {
      return Scaffold(
        backgroundColor: AppColors.mobileSurface,
        body: Column(
          children: [
            YorksMobileAppBar(
              title: AppStrings.notifications.active(lang),
              leading: YorksMobileIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              trailing: unread > 0
                  ? TextButton(
                      onPressed: _markAll,
                      child: Text(
                        AppStrings.markAllRead.active(lang),
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
                        onTap: () => _selectFilter(filter),
                      ),
                    ),
                    if (filter != _NotificationFilter.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: NotificationDeliveryCard(compact: true),
            ),
            _searchField(lang),
            Expanded(
              child: _NotificationListState(
                notifications: visible,
                filter: _filter,
                serverState: serverState,
                language: lang,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
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
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          AppStrings.notifications.active(lang),
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAll,
              child: Text(AppStrings.markAllRead.active(lang)),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth.clamp(0.0, 920.0),
              height: constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: NotificationDeliveryCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          for (final filter in _NotificationFilter.values) ...[
                            ChoiceChip(
                              label: Text(filter.label.active(lang)),
                              selected: _filter == filter,
                              onSelected: (_) => _selectFilter(filter),
                            ),
                            if (filter != _NotificationFilter.values.last)
                              const Gap(AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                    _searchField(lang),
                    Expanded(
                      child: _NotificationListState(
                        notifications: visible,
                        filter: _filter,
                        serverState: serverState,
                        language: lang,
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      ),
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
}

class _NotificationListState extends ConsumerWidget {
  const _NotificationListState({
    required this.notifications,
    required this.filter,
    required this.serverState,
    required this.language,
    required this.padding,
  });

  final List<AppNotification> notifications;
  final _NotificationFilter filter;
  final AsyncValue<Object?> serverState;
  final AppLanguage language;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesServer = ref.watch(supabaseClientProvider) != null;
    final inbox = usesServer
        ? ref.read(notificationInboxProvider.notifier)
        : ref.read(yorksV1NotificationsProvider.notifier);
    if (notifications.isEmpty && serverState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifications.isEmpty && serverState.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 44,
                color: AppColors.warning,
              ),
              const Gap(AppSpacing.md),
              Text(
                AppStrings.couldNotLoadNotifications.active(language),
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const Gap(AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => inbox.refresh(showLoading: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppStrings.retry.active(language)),
              ),
            ],
          ),
        ),
      );
    }
    final history = usesServer
        ? ref.watch(notificationInboxStatusProvider)
        : ref.watch(notificationHistoryStatusProvider);
    return Column(
      children: [
        if (serverState.hasError)
          ListTile(
            title: Text(NotificationExperienceStrings.stale.active(language)),
            trailing: IconButton(
              tooltip: AppStrings.retry.active(language),
              icon: const Icon(Icons.refresh),
              onPressed: () => inbox.refresh(),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => inbox.refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount:
                  (notifications.isEmpty ? 1 : notifications.length) +
                  (history.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
              itemBuilder: (context, index) {
                if (index ==
                    (notifications.isEmpty ? 1 : notifications.length)) {
                  return TextButton(
                    onPressed: history.loadingMore
                        ? null
                        : () => inbox.loadMore(),
                    child: Text(
                      NotificationExperienceStrings.loadMore.active(language),
                    ),
                  );
                }
                if (notifications.isEmpty) {
                  return _EmptyState(lang: language, filter: filter);
                }
                final item = notifications[index];
                final newDay =
                    index == 0 ||
                    !DateUtils.isSameDay(
                      notifications[index - 1].timestamp,
                      item.timestamp,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (newDay)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Semantics(
                          container: true,
                          header: true,
                          child: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatFullDate(item.timestamp),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ),
                    _NotificationDismissible(notification: item),
                  ],
                );
              },
            ),
          ),
        ),
      ],
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
      onTap: () async {
        if (notification.route.isNotEmpty) context.push(notification.route);
        try {
          await ref.read(notificationActionsProvider).markRead(notification);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  NotificationExperienceStrings.readFailed.active(
                    ref.read(languageProvider),
                  ),
                ),
              ),
            );
          }
        }
      },
    ),
  );
}

// ─── Notification card ───────────────────────────────────────────
class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final (icon, color) = _style(notification.type);
    final unread = !notification.isRead;
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label: [
        (unread
                ? NotificationExperienceStrings.unread
                : NotificationExperienceStrings.read)
            .active(language),
        notification.title,
        if (notification.titleSecondary.isNotEmpty) notification.titleSecondary,
        notification.relativeTimeFor(language),
        if (notification.body.isNotEmpty) notification.body,
        if (notification.route.isNotEmpty)
          AppStrings.viewDetails.active(language),
      ].join('\n'),
      child: LedgerCard(
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
                        notification.relativeTimeFor(language),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.inkSecondary,
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
                        color: AppColors.inkSecondary,
                      ),
                      textDirection: notification.isServerAuthoritative
                          ? null
                          : TextDirection.rtl,
                    ),
                  ],
                  if (notification.body.isNotEmpty) ...[
                    const Gap(AppSpacing.xs),
                    Text(
                      notification.body,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                  if (notification.route.isNotEmpty) ...[
                    const Gap(AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: AppColors.blue,
                        ),
                        const Gap(AppSpacing.xs),
                        Text(
                          AppStrings.viewDetails.active(language),
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
  const _EmptyState({
    required this.lang,
    this.filter = _NotificationFilter.all,
  });
  final _NotificationFilter filter;

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
              (switch (filter) {
                _NotificationFilter.all => AppStrings.allCaughtUp,
                _NotificationFilter.unread =>
                  NotificationExperienceStrings.noUnread,
                _NotificationFilter.urgent =>
                  NotificationExperienceStrings.noUrgent,
              }).active(lang),
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
