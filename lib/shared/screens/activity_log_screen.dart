import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/constants.dart';
import '../models/app_language.dart';
import '../models/app_strings.dart';
import '../models/yorks_v1_audit_strings.dart';
import '../models/yorks_v1_audit_workspace.dart';
import '../providers/language_provider.dart';
import '../providers/yorks_v1_audit_provider.dart';

/// Admin-only, read-only projection of the trusted server audit ledger.
///
/// This widget never reads or writes Supabase. Filters and refreshes flow
/// through [YorksV1AuditController], which calls the Admin-authorized RPC via
/// the repository boundary.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      ref.read(yorksV1AuditControllerProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final state = ref.watch(yorksV1AuditControllerProvider);
    final controller = ref.read(yorksV1AuditControllerProvider.notifier);

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final showRightRail = constraints.maxWidth >= 1000;
            final horizontal = compact
                ? AppSpacing.mobileScreenHorizontal
                : AppSpacing.xxl;
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: controller.load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          compact ? 16 : 22,
                          horizontal,
                          32,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _AuditHeader(
                              language: language,
                              compact: compact,
                              controller: _searchController,
                              onSearch: _search,
                              filter: state.filter,
                              onDateRange: (from, to) =>
                                  controller.setDateRange(from, to),
                              onRefresh: controller.load,
                            ),
                            const Gap(20),
                            if (state.isLoading && state.workspace == null)
                              const _AuditLoading()
                            else if (state.workspace == null)
                              _AuditFailure(
                                language: language,
                                onRetry: controller.load,
                              )
                            else ...[
                              _SummaryGrid(
                                language: language,
                                summary: state.workspace!.summary,
                              ),
                              const Gap(16),
                              if (state.error != null)
                                _InlineFailure(
                                  language: language,
                                  onRetry: controller.load,
                                ),
                              if (state.error != null) const Gap(12),
                              if (showRightRail)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _MainAuditColumn(
                                        language: language,
                                        workspace: state.workspace!,
                                        filter: state.filter,
                                        onModule: controller.setModule,
                                        onPage: controller.goToPage,
                                      ),
                                    ),
                                    const Gap(16),
                                    SizedBox(
                                      width: 308,
                                      child: _AuditRightRail(
                                        language: language,
                                        workspace: state.workspace!,
                                        selected: state.filter.quickFilter,
                                        onFilter: controller.setQuickFilter,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                _CompactAuditLayout(
                                  language: language,
                                  workspace: state.workspace!,
                                  filter: state.filter,
                                  onModule: controller.setModule,
                                  onPage: controller.goToPage,
                                  onFilter: controller.setQuickFilter,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isRefreshing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuditHeader extends StatelessWidget {
  const _AuditHeader({
    required this.language,
    required this.compact,
    required this.controller,
    required this.onSearch,
    required this.filter,
    required this.onDateRange,
    required this.onRefresh,
  });

  final AppLanguage language;
  final bool compact;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final YorksV1AuditFilter filter;
  final void Function(DateTime? from, DateTime? to) onDateRange;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          YorksV1AuditStrings.workspace.active(language).toUpperCase(),
          style: AppTypography.eyebrow,
        ),
        const Gap(5),
        Text(
          YorksV1AuditStrings.title.active(language),
          style: compact
              ? AppTypography.headlineSmall
              : AppTypography.headlineMedium,
        ),
        const Gap(4),
        Text(
          YorksV1AuditStrings.subtitle.active(language),
          style: AppTypography.bodyMedium,
        ),
      ],
    );

    final controlChildren = <Widget>[
      SizedBox(
        width: compact ? null : 330,
        height: 44,
        child: TextField(
          key: const ValueKey('audit-search-field'),
          controller: controller,
          onChanged: onSearch,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: YorksV1AuditStrings.searchHint.active(language),
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    onPressed: () {
                      controller.clear();
                      onSearch('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
      ),
      _HeaderAction(
        icon: Icons.calendar_today_outlined,
        label: _dateRangeLabel(context, language),
        onTap: () => _pickDates(context),
      ),
      _HeaderAction(
        icon: Icons.refresh_rounded,
        label: YorksV1AuditStrings.refresh.active(language),
        iconOnly: !compact,
        onTap: onRefresh,
      ),
    ];
    final controls = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controlChildren.first,
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controlChildren.skip(1).toList(growable: false),
              ),
            ],
          )
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: controlChildren,
          );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const Gap(14), controls],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        const Gap(20),
        Flexible(flex: 2, child: controls),
      ],
    );
  }

  String _dateRangeLabel(BuildContext context, AppLanguage language) {
    final localizations = MaterialLocalizations.of(context);
    if (filter.from == null || filter.to == null) {
      return YorksV1AuditStrings.allTime.active(language);
    }
    return '${localizations.formatShortDate(filter.from!)} – '
        '${localizations.formatShortDate(filter.to!)}';
  }

  Future<void> _pickDates(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: filter.from == null || filter.to == null
          ? null
          : DateTimeRange(start: filter.from!, end: filter.to!),
    );
    if (range == null) return;
    onDateRange(
      DateTime(range.start.year, range.start.month, range.start.day),
      DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: iconOnly
              ? const EdgeInsets.symmetric(horizontal: 12)
              : const EdgeInsets.symmetric(horizontal: 14),
          side: const BorderSide(color: AppColors.line),
          backgroundColor: AppColors.surfaceContainerLowest,
          foregroundColor: AppColors.inkSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: iconOnly ? const SizedBox.shrink() : Text(label),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.language, required this.summary});

  final AppLanguage language;
  final YorksV1AuditSummary summary;

  @override
  Widget build(BuildContext context) {
    final previous = summary.previousPeriodActivities;
    final delta = previous == 0
        ? null
        : 100 *
              (summary.currentPeriodActivities - previous) /
              math.max(previous, 1);
    final cards = [
      _SummaryValue(
        label: YorksV1AuditStrings.totalActivities.active(language),
        value: _formatInteger(summary.totalActivities),
        hint: YorksV1AuditStrings.allTime.active(language),
        icon: Icons.receipt_long_outlined,
        color: AppColors.primary,
        delta: delta,
      ),
      _SummaryValue(
        label: YorksV1AuditStrings.criticalActivities.active(language),
        value: _formatInteger(summary.criticalActivities),
        hint: YorksV1AuditStrings.allTime.active(language),
        icon: Icons.gpp_maybe_outlined,
        color: AppColors.error,
      ),
      _SummaryValue(
        label: YorksV1AuditStrings.activeUsers.active(language),
        value: _formatInteger(summary.activeUsers),
        hint: YorksV1AuditStrings.lastThirtyDays.active(language),
        icon: Icons.people_alt_outlined,
        color: AppColors.warning,
      ),
      _SummaryValue(
        label: YorksV1AuditStrings.entitiesMonitored.active(language),
        value: _formatInteger(summary.entitiesMonitored),
        hint: YorksV1AuditStrings.allTime.active(language),
        icon: Icons.account_tree_outlined,
        color: AppColors.tertiary,
      ),
      _SummaryValue(
        label: YorksV1AuditStrings.auditAlerts.active(language),
        value: _formatInteger(summary.auditAlerts),
        hint: YorksV1AuditStrings.lastSevenDays.active(language),
        icon: Icons.notifications_active_outlined,
        color: const Color(0xFF00A7B5),
      ),
      _SummaryValue(
        label: YorksV1AuditStrings.dataIntegrity.active(language),
        value: '${_formatDecimal(summary.dataIntegrityPercent)}%',
        hint: YorksV1AuditStrings.trustedCoverage.active(language),
        icon: Icons.verified_user_outlined,
        color: AppColors.success,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 6
            : constraints.maxWidth >= 650
            ? 3
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                height: columns == 2
                    ? 126
                    : columns == 6
                    ? 124
                    : 118,
                child: _SummaryCard(card),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryValue {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    this.delta,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final double? delta;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.value);
  final _SummaryValue value;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: value.color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(value.icon, color: value.color, size: 21),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
                const Gap(2),
                Text(
                  value.value,
                  style: AppTypography.headlineSmall.copyWith(fontSize: 20),
                ),
                const Gap(2),
                if (value.delta case final delta?)
                  Text(
                    '${delta >= 0 ? '↑' : '↓'} '
                    '${_formatDecimal(delta.abs())}% · ${value.hint}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: delta >= 0 ? AppColors.success : AppColors.error,
                    ),
                  )
                else
                  Text(
                    value.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainAuditColumn extends StatelessWidget {
  const _MainAuditColumn({
    required this.language,
    required this.workspace,
    required this.filter,
    required this.onModule,
    required this.onPage,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final YorksV1AuditFilter filter;
  final ValueChanged<YorksV1AuditModule?> onModule;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RecentActivityPanel(
          language: language,
          workspace: workspace,
          filter: filter,
          onModule: onModule,
          onPage: onPage,
        ),
        const Gap(16),
        _AuditCharts(language: language, workspace: workspace),
      ],
    );
  }
}

class _AuditRightRail extends StatelessWidget {
  const _AuditRightRail({
    required this.language,
    required this.workspace,
    required this.selected,
    required this.onFilter,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final YorksV1AuditQuickFilter? selected;
  final ValueChanged<YorksV1AuditQuickFilter?> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopEntitiesPanel(language: language, workspace: workspace),
        const Gap(16),
        _QuickFiltersPanel(
          language: language,
          workspace: workspace,
          selected: selected,
          onFilter: onFilter,
        ),
        const Gap(16),
        _AlertsPanel(language: language, workspace: workspace),
      ],
    );
  }
}

class _CompactAuditLayout extends StatelessWidget {
  const _CompactAuditLayout({
    required this.language,
    required this.workspace,
    required this.filter,
    required this.onModule,
    required this.onPage,
    required this.onFilter,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final YorksV1AuditFilter filter;
  final ValueChanged<YorksV1AuditModule?> onModule;
  final ValueChanged<int> onPage;
  final ValueChanged<YorksV1AuditQuickFilter?> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickFiltersPanel(
          language: language,
          workspace: workspace,
          selected: filter.quickFilter,
          onFilter: onFilter,
        ),
        const Gap(12),
        _RecentActivityPanel(
          language: language,
          workspace: workspace,
          filter: filter,
          onModule: onModule,
          onPage: onPage,
          mobileCards: true,
        ),
        const Gap(12),
        _TopEntitiesPanel(language: language, workspace: workspace),
        const Gap(12),
        _AlertsPanel(language: language, workspace: workspace),
        const Gap(12),
        _AuditCharts(language: language, workspace: workspace, stacked: true),
      ],
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({
    required this.language,
    required this.workspace,
    required this.filter,
    required this.onModule,
    required this.onPage,
    this.mobileCards = false,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final YorksV1AuditFilter filter;
  final ValueChanged<YorksV1AuditModule?> onModule;
  final ValueChanged<int> onPage;
  final bool mobileCards;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 19,
                  color: AppColors.navy,
                ),
                const Gap(9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        YorksV1AuditStrings.recentActivity.active(language),
                        style: AppTypography.titleMedium,
                      ),
                      const Gap(2),
                      Text(
                        YorksV1AuditStrings.recentActivityHint.active(language),
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                _ModulePicker(
                  language: language,
                  selected: filter.module,
                  onChanged: onModule,
                ),
                const Gap(6),
                IconButton(
                  tooltip: AppStrings.exportAudit.active(language),
                  onPressed: workspace.events.isEmpty
                      ? null
                      : () => _exportCurrentPage(context),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (workspace.events.isEmpty)
            _EmptyActivity(language: language)
          else if (mobileCards)
            for (final event in workspace.events)
              _MobileAuditEvent(event: event, language: language)
          else
            _AuditEventTable(events: workspace.events, language: language),
          const Divider(height: 1),
          _PaginationBar(
            language: language,
            workspace: workspace,
            currentPage: filter.page,
            onPage: onPage,
          ),
        ],
      ),
    );
  }

  Future<void> _exportCurrentPage(BuildContext context) async {
    final buffer = StringBuffer(
      'Timestamp,Actor,Role,Action,Module,Entity,Reference,Reason\n',
    );
    String safe(String value) => '"${value.replaceAll('"', '""')}"';
    for (final event in workspace.events) {
      buffer.writeln(
        [
          safe(event.occurredAt.toUtc().toIso8601String()),
          safe(event.actorDisplayName),
          safe(event.actorExactRole),
          safe(event.eventType),
          safe(event.module.wireValue),
          safe(event.entityType),
          safe(event.reference),
          safe(event.reason ?? ''),
        ].join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.auditCopied.active(language))),
    );
  }
}

class _ModulePicker extends StatelessWidget {
  const _ModulePicker({
    required this.language,
    required this.selected,
    required this.onChanged,
  });

  final AppLanguage language;
  final YorksV1AuditModule? selected;
  final ValueChanged<YorksV1AuditModule?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<YorksV1AuditModule?>(
      tooltip: YorksV1AuditStrings.allModules.active(language),
      initialValue: selected,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<YorksV1AuditModule?>(
          value: null,
          child: Text(YorksV1AuditStrings.allModules.active(language)),
        ),
        for (final module in YorksV1AuditModule.values)
          PopupMenuItem<YorksV1AuditModule?>(
            value: module,
            child: Text(YorksV1AuditStrings.module(module).active(language)),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 38, maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_rounded, size: 17),
            const Gap(6),
            Flexible(
              child: Text(
                selected == null
                    ? YorksV1AuditStrings.allModules.active(language)
                    : YorksV1AuditStrings.module(selected!).active(language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditEventTable extends StatelessWidget {
  const _AuditEventTable({required this.events, required this.language});

  final List<YorksV1AuditEvent> events;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showEntity = constraints.maxWidth >= 760;
        return Column(
          children: [
            Container(
              height: 36,
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _TableHeader(
                    YorksV1AuditStrings.timeColumn.active(language),
                    width: 92,
                  ),
                  _TableHeader(
                    YorksV1AuditStrings.userColumn.active(language),
                    flex: 14,
                  ),
                  _TableHeader(
                    YorksV1AuditStrings.actionColumn.active(language),
                    flex: 18,
                  ),
                  _TableHeader(
                    YorksV1AuditStrings.moduleColumn.active(language),
                    flex: 13,
                  ),
                  if (showEntity)
                    _TableHeader(
                      YorksV1AuditStrings.entityColumn.active(language),
                      flex: 12,
                    ),
                  _TableHeader(
                    YorksV1AuditStrings.referenceColumn.active(language),
                    flex: 12,
                  ),
                  _TableHeader(
                    YorksV1AuditStrings.detailsColumn.active(language),
                    flex: 18,
                  ),
                ],
              ),
            ),
            for (final event in events)
              _DesktopAuditEvent(
                event: event,
                language: language,
                showEntity: showEntity,
              ),
          ],
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text, {this.width, this.flex});
  final String text;
  final double? width;
  final int? flex;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      maxLines: 1,
      style: AppTypography.labelSmall.copyWith(
        fontSize: 9,
        letterSpacing: .7,
        fontWeight: FontWeight.w800,
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex!, child: child);
  }
}

class _DesktopAuditEvent extends StatelessWidget {
  const _DesktopAuditEvent({
    required this.event,
    required this.language,
    required this.showEntity,
  });

  final YorksV1AuditEvent event;
  final AppLanguage language;
  final bool showEntity;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        event.entityType == 'material_request' ||
        event.entityType == 'material_return';
    return InkWell(
      onTap: canOpen
          ? () => context.go(
              event.entityType == 'material_return'
                  ? RoutePaths.yorksV1MaterialReturnPath(event.entityId)
                  : RoutePaths.yorksV1MaterialRequestPath(event.entityId),
            )
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                _dateTime(context, event.occurredAt),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 14,
              child: _ActorCell(event: event, language: language),
            ),
            Expanded(
              flex: 18,
              child: _ActionChip(event: event, language: language),
            ),
            Expanded(
              flex: 13,
              child: Text(
                YorksV1AuditStrings.module(event.module).active(language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
            if (showEntity)
              Expanded(
                flex: 12,
                child: Text(
                  YorksV1AuditStrings.entityLabel(event.entityType, language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ),
            Expanded(
              flex: 12,
              child: Text(
                event.reference,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.navy,
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      event.reason ?? event.projectName ?? '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  if (canOpen)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: AppColors.muted,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileAuditEvent extends StatelessWidget {
  const _MobileAuditEvent({required this.event, required this.language});
  final YorksV1AuditEvent event;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        event.entityType == 'material_request' ||
        event.entityType == 'material_return';
    return InkWell(
      onTap: canOpen
          ? () => context.go(
              event.entityType == 'material_return'
                  ? RoutePaths.yorksV1MaterialReturnPath(event.entityId)
                  : RoutePaths.yorksV1MaterialRequestPath(event.entityId),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActorAvatar(name: event.actorDisplayName, size: 38),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActionChip(event: event, language: language),
                  const Gap(7),
                  Text(
                    '${event.actorDisplayName} · '
                    '${YorksV1AuditStrings.roleLabel(event.actorExactRole, language)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge,
                  ),
                  const Gap(5),
                  Text(
                    '${YorksV1AuditStrings.module(event.module).active(language)}'
                    ' · ${event.reference}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  if (event.reason != null || event.projectName != null) ...[
                    const Gap(4),
                    Text(
                      event.reason ?? event.projectName!,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                  const Gap(6),
                  Text(
                    _dateTime(context, event.occurredAt),
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
            ),
            if (canOpen)
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ActorCell extends StatelessWidget {
  const _ActorCell({required this.event, required this.language});
  final YorksV1AuditEvent event;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActorAvatar(name: event.actorDisplayName, size: 30),
        const Gap(7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.actorDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge,
              ),
              Text(
                YorksV1AuditStrings.roleLabel(event.actorExactRole, language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.blueContainerStrong),
      ),
      child: Text(
        initials.isEmpty ? '•' : initials,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.event, required this.language});
  final YorksV1AuditEvent event;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (event.severity) {
      YorksV1AuditSeverity.critical => (
        AppColors.error,
        AppColors.errorContainer,
      ),
      YorksV1AuditSeverity.warning => (
        AppColors.warning,
        AppColors.warningContainer,
      ),
      YorksV1AuditSeverity.normal => (
        AppColors.primary,
        AppColors.primaryContainer,
      ),
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          YorksV1AuditStrings.eventLabel(event.eventType, language),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.language,
    required this.workspace,
    required this.currentPage,
    required this.onPage,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final int currentPage;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final first = workspace.filteredCount == 0 ? 0 : workspace.offset + 1;
    final last = math.min(
      workspace.offset + workspace.events.length,
      workspace.filteredCount,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$first–$last / ${_formatInteger(workspace.filteredCount)}',
              style: AppTypography.labelSmall,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            onPressed: currentPage > 0 ? () => onPage(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(7),
              color: AppColors.primaryContainer,
            ),
            child: Text('${currentPage + 1}', style: AppTypography.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/ ${workspace.pageCount}',
              style: AppTypography.labelSmall,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            onPressed: currentPage + 1 < workspace.pageCount
                ? () => onPage(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _TopEntitiesPanel extends StatelessWidget {
  const _TopEntitiesPanel({required this.language, required this.workspace});
  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.account_tree_outlined,
            title: YorksV1AuditStrings.topEntities.active(language),
          ),
          const Gap(14),
          if (workspace.topEntities.isEmpty)
            const SizedBox(height: 64)
          else
            for (final entity in workspace.topEntities) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      YorksV1AuditStrings.entityLabel(entity.key, language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge,
                    ),
                  ),
                  Text(
                    _formatInteger(entity.activityCount),
                    style: AppTypography.labelSmall,
                  ),
                  const Gap(7),
                  Text(
                    '${_formatDecimal(entity.percent)}%',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
              const Gap(5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entity.percent.clamp(0, 100) / 100,
                  minHeight: 4,
                  backgroundColor: AppColors.surfaceContainerHighest,
                ),
              ),
              const Gap(12),
            ],
        ],
      ),
    );
  }
}

class _QuickFiltersPanel extends StatelessWidget {
  const _QuickFiltersPanel({
    required this.language,
    required this.workspace,
    required this.selected,
    required this.onFilter,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final YorksV1AuditQuickFilter? selected;
  final ValueChanged<YorksV1AuditQuickFilter?> onFilter;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.filter_alt_outlined,
            title: YorksV1AuditStrings.quickFilters.active(language),
          ),
          const Gap(12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final filter in YorksV1AuditQuickFilter.values)
                _QuickFilterButton(
                  label: YorksV1AuditStrings.quickFilter(
                    filter,
                  ).active(language),
                  count: workspace.quickFilterCounts[filter] ?? 0,
                  selected: selected == filter,
                  onTap: () => onFilter(selected == filter ? null : filter),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickFilterButton extends StatelessWidget {
  const _QuickFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const Gap(6),
            Text(label, style: AppTypography.labelMedium),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                _formatInteger(count),
                style: AppTypography.labelSmall.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.language, required this.workspace});
  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.notifications_active_outlined,
            title: YorksV1AuditStrings.alerts.active(language),
          ),
          const Gap(12),
          if (workspace.alerts.isEmpty)
            _EmptyActivity(language: language, compact: true)
          else
            for (final alert in workspace.alerts.take(4)) ...[
              _AlertTile(alert: alert, language: language),
              const Gap(8),
            ],
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.language});
  final YorksV1AuditAlert alert;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final critical = alert.severity == YorksV1AuditSeverity.critical;
    final color = critical ? AppColors.error : AppColors.warning;
    final background = critical
        ? AppColors.errorContainer
        : AppColors.warningContainer;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            critical
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  YorksV1AuditStrings.eventLabel(alert.eventType, language),
                  style: AppTypography.labelLarge.copyWith(color: color),
                ),
                const Gap(2),
                Text(
                  alert.reason ?? alert.reference,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const Gap(6),
          Text(
            _dateTime(context, alert.occurredAt),
            style: AppTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _AuditCharts extends StatelessWidget {
  const _AuditCharts({
    required this.language,
    required this.workspace,
    this.stacked = false,
  });

  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final charts = [
      _ModuleOverviewChart(language: language, workspace: workspace),
      _TrendChart(language: language, workspace: workspace),
      _HealthChart(language: language, workspace: workspace),
    ];
    if (stacked) {
      return Column(
        children: [
          for (var index = 0; index < charts.length; index++) ...[
            charts[index],
            if (index != charts.length - 1) const Gap(12),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < charts.length; index++) ...[
          Expanded(child: charts[index]),
          if (index != charts.length - 1) const Gap(12),
        ],
      ],
    );
  }
}

class _ModuleOverviewChart extends StatelessWidget {
  const _ModuleOverviewChart({required this.language, required this.workspace});
  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final colors = _chartColors;
    return _AuditPanel(
      child: SizedBox(
        height: 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelTitle(
              icon: Icons.donut_large_outlined,
              title: YorksV1AuditStrings.activityOverview.active(language),
            ),
            const Gap(12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label:
                          '${YorksV1AuditStrings.totalActivities.active(language)} '
                          '${workspace.summary.totalActivities}',
                      child: CustomPaint(
                        painter: _DonutPainter(
                          values: [
                            for (final item in workspace.moduleActivity)
                              item.activityCount.toDouble(),
                          ],
                          colors: colors,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatInteger(
                                  workspace.summary.totalActivities,
                                ),
                                style: AppTypography.titleMedium,
                              ),
                              Text(
                                YorksV1AuditStrings.total.active(language),
                                style: AppTypography.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < math.min(5, workspace.moduleActivity.length);
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: colors[index % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Gap(5),
                                Expanded(
                                  child: Text(
                                    YorksV1AuditStrings.module(
                                      YorksV1AuditModule.fromWire(
                                        workspace.moduleActivity[index].key,
                                      ),
                                    ).active(language),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelSmall,
                                  ),
                                ),
                                Text(
                                  '${_formatDecimal(workspace.moduleActivity[index].percent)}%',
                                  style: AppTypography.labelSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.language, required this.workspace});
  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      child: SizedBox(
        height: 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelTitle(
              icon: Icons.show_chart_rounded,
              title: YorksV1AuditStrings.activityTrend.active(language),
            ),
            const Gap(4),
            Text(
              YorksV1AuditStrings.lastSevenDays.active(language),
              style: AppTypography.labelSmall,
            ),
            const Gap(10),
            Expanded(
              child: CustomPaint(
                painter: _LineChartPainter(workspace.trend),
                child: const SizedBox.expand(),
              ),
            ),
            const Gap(6),
            Row(
              children: [
                for (final entry in workspace.trend.indexed)
                  if (entry.$1 == 0 ||
                      entry.$1 == workspace.trend.length ~/ 2 ||
                      entry.$1 == workspace.trend.length - 1)
                    Expanded(
                      child: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(entry.$2.date),
                        textAlign: entry.$1 == 0
                            ? TextAlign.start
                            : entry.$1 == workspace.trend.length - 1
                            ? TextAlign.end
                            : TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(fontSize: 8),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthChart extends StatelessWidget {
  const _HealthChart({required this.language, required this.workspace});
  final AppLanguage language;
  final YorksV1AuditWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final score = workspace.summary.dataIntegrityPercent.clamp(0, 100);
    return _AuditPanel(
      child: SizedBox(
        height: 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelTitle(
              icon: Icons.health_and_safety_outlined,
              title: YorksV1AuditStrings.auditHealth.active(language),
            ),
            const Gap(10),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _HealthPainter(score / 100),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatDecimal(score)}%',
                            style: AppTypography.headlineMedium,
                          ),
                          Text(
                            score >= 99
                                ? YorksV1AuditStrings.trusted.active(language)
                                : YorksV1AuditStrings.historicalGap.active(
                                    language,
                                  ),
                            textAlign: TextAlign.center,
                            style: AppTypography.labelSmall.copyWith(
                              color: score >= 99
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              '${YorksV1AuditStrings.refresh.active(language)}: '
              '${_dateTime(context, workspace.generatedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .38;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = math.max(10.0, radius * .23);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.surfaceContainerHighest,
    );
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - .025),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[index % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.points);
  final List<YorksV1AuditTrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.isEmpty) return;
    final maximum = math.max(
      1,
      points.map((point) => point.activityCount).reduce(math.max),
    );
    final path = Path();
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final y =
          size.height -
          (size.height - 8) * points[index].activityCount / maximum;
      final point = Offset(x, y);
      offsets.add(point);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in offsets) {
      canvas.drawCircle(point, 3.5, Paint()..color = AppColors.primary);
      canvas.drawCircle(
        point,
        2,
        Paint()..color = AppColors.surfaceContainerLowest,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _HealthPainter extends CustomPainter {
  const _HealthPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .38;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = math.max(11.0, radius * .15);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceContainerHighest;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = value >= .99 ? AppColors.success : AppColors.warning;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.navy),
        const Gap(8),
        Expanded(child: Text(title, style: AppTypography.titleSmall)),
      ],
    );
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.language, this.compact = false});
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 18 : 42,
        horizontal: 16,
      ),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: compact ? 28 : 38,
            color: AppColors.mutedLight,
          ),
          const Gap(8),
          Text(
            YorksV1AuditStrings.noEvents.active(language),
            textAlign: TextAlign.center,
            style: AppTypography.titleSmall,
          ),
          if (!compact) ...[
            const Gap(4),
            Text(
              YorksV1AuditStrings.noEventsHint.active(language),
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditLoading extends StatelessWidget {
  const _AuditLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          Row(
            children: [
              for (var column = 0; column < 3; column++) ...[
                Expanded(
                  child: Container(
                    height: 112,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                ),
                if (column != 2) const Gap(10),
              ],
            ],
          ),
          const Gap(10),
        ],
        const Gap(6),
        const _AuditPanel(
          child: SizedBox(
            height: 360,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _AuditFailure extends StatelessWidget {
  const _AuditFailure({required this.language, required this.onRetry});
  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AuditPanel(
      child: SizedBox(
        height: 320,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppColors.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const Gap(14),
                Text(
                  YorksV1AuditStrings.unavailable.active(language),
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall,
                ),
                const Gap(6),
                Text(
                  YorksV1AuditStrings.unavailableHint.active(language),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                const Gap(18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(YorksV1AuditStrings.retry.active(language)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.language, required this.onRetry});
  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const Gap(9),
          Expanded(
            child: Text(
              YorksV1AuditStrings.unavailableHint.active(language),
              style: AppTypography.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(YorksV1AuditStrings.retry.active(language)),
          ),
        ],
      ),
    );
  }
}

const _chartColors = <Color>[
  AppColors.primary,
  AppColors.success,
  AppColors.warning,
  AppColors.tertiary,
  Color(0xFF00A7B5),
  AppColors.error,
  AppColors.navy,
  AppColors.neutralText,
];

String _formatInteger(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
}

String _formatDecimal(num value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

String _dateTime(BuildContext context, DateTime value) {
  final material = MaterialLocalizations.of(context);
  final date = material.formatShortDate(value);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date\n$time';
}
