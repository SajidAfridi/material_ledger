import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_accounts_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../application/accounts_controller.dart';
import '../../application/accounts_office_controller.dart';
import '../../application/accounts_office_providers.dart';
import '../../domain/accounts_decimal.dart';
import '../../domain/accounts_office_models.dart';
import '../../domain/accounts_records_models.dart';
import '../widgets/yorks_accounts_records_views.dart';

class YorksAccountsOfficeScreen extends ConsumerStatefulWidget {
  const YorksAccountsOfficeScreen({super.key, required this.section});

  final YorksAccountsOfficeSection section;

  @override
  ConsumerState<YorksAccountsOfficeScreen> createState() =>
      _YorksAccountsOfficeScreenState();
}

class _YorksAccountsOfficeScreenState
    extends ConsumerState<YorksAccountsOfficeScreen> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant YorksAccountsOfficeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _searchTimer?.cancel();
      _searchController.clear();
      _status = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  YorksAccountsOfficeFilters get _filters => YorksAccountsOfficeFilters(
    search: _searchController.text,
    status: _status,
  );

  void _load() => ref
      .read(yorksAccountsOfficeControllerProvider(widget.section).notifier)
      .load(_filters);

  void _searchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 320), _load);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final state = ref.watch(
      yorksAccountsOfficeControllerProvider(widget.section),
    );
    final config = _OfficeSectionConfig.forSection(widget.section);
    final projection = state.projection;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppSpacing.compactBreakpoint;
    final wide = width >= 1320;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(
              yorksAccountsOfficeControllerProvider(widget.section).notifier,
            )
            .load(_filters),
        child: CustomScrollView(
          key: PageStorageKey('accounts-office-${widget.section.wireValue}'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact ? AppSpacing.mobileScreenHorizontal : AppSpacing.xxl,
                compact ? AppSpacing.mobileScreenVertical : AppSpacing.xxl,
                compact ? AppSpacing.mobileScreenHorizontal : AppSpacing.xxl,
                AppSpacing.colossal,
              ),
              sliver: SliverList.list(
                children: [
                  _OfficeHeader(
                    config: config,
                    language: language,
                    compact: compact,
                    onOpenProjects: () =>
                        context.go(RoutePaths.yorksV1AccountsProjects),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (projection != null)
                    _OfficeSummaryCards(
                      section: widget.section,
                      projection: projection,
                      language: language,
                    )
                  else if (state.status == YorksAccountsViewStatus.loading)
                    const _OfficeLoadingCards(),
                  const SizedBox(height: AppSpacing.lg),
                  _OfficeFilterBar(
                    language: language,
                    controller: _searchController,
                    status: _status,
                    statuses: config.statuses,
                    onSearchChanged: _searchChanged,
                    onStatusChanged: (value) {
                      setState(() => _status = value);
                      _load();
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _status = null);
                      _load();
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (wide && projection != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _OfficeRegister(
                            section: widget.section,
                            state: state,
                            language: language,
                            onRetry: _load,
                            onLoadMore: () => ref
                                .read(
                                  yorksAccountsOfficeControllerProvider(
                                    widget.section,
                                  ).notifier,
                                )
                                .loadMore(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(
                          width: 310,
                          child: _OfficeInsights(
                            section: widget.section,
                            projection: projection,
                            language: language,
                          ),
                        ),
                      ],
                    )
                  else
                    _OfficeRegister(
                      section: widget.section,
                      state: state,
                      language: language,
                      onRetry: _load,
                      onLoadMore: () => ref
                          .read(
                            yorksAccountsOfficeControllerProvider(
                              widget.section,
                            ).notifier,
                          )
                          .loadMore(),
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

class YorksAccountsReportsScreen extends ConsumerWidget {
  const YorksAccountsReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          compact ? AppSpacing.mobileScreenHorizontal : AppSpacing.xxl,
          compact ? AppSpacing.mobileScreenVertical : AppSpacing.xxl,
          compact ? AppSpacing.mobileScreenHorizontal : AppSpacing.xxl,
          AppSpacing.colossal,
        ),
        children: [
          _OfficeHeader(
            config: const _OfficeSectionConfig(
              titleKey: 'office_reports_title',
              bodyKey: 'office_reports_body',
              icon: Icons.analytics_outlined,
              color: AppColors.purple,
            ),
            language: language,
            compact: compact,
            onOpenProjects: () =>
                context.go(RoutePaths.yorksV1AccountsProjects),
          ),
          const SizedBox(height: AppSpacing.lg),
          _OfficePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OfficePanelTitle(
                  icon: Icons.account_balance_wallet_outlined,
                  title: _t(language, 'office_portfolio_report'),
                  subtitle: _t(language, 'office_data_current'),
                ),
                const SizedBox(height: AppSpacing.lg),
                YorksAccountsReportActions(
                  kind: YorksAccountsReportKind.portfolio,
                  language: language,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _OfficePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OfficePanelTitle(
                  icon: Icons.folder_copy_outlined,
                  title: _t(language, 'office_project_reports'),
                  subtitle: _t(language, 'office_project_reports_body'),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () =>
                      context.go(RoutePaths.yorksV1AccountsProjects),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(_t(language, 'office_open_project')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeHeader extends StatelessWidget {
  const _OfficeHeader({
    required this.config,
    required this.language,
    required this.compact,
    required this.onOpenProjects,
  });

  final _OfficeSectionConfig config;
  final AppLanguage language;
  final bool compact;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(config.icon, color: config.color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _t(language, config.titleKey),
                style: compact
                    ? AppTypography.headlineSmall
                    : AppTypography.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _t(language, config.bodyKey),
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        ),
      ],
    );
    final action = OutlinedButton.icon(
      onPressed: onOpenProjects,
      icon: const Icon(Icons.folder_open_outlined),
      label: Text(_t(language, 'office_open_project')),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: AppSpacing.md),
          action,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: copy),
        const SizedBox(width: AppSpacing.lg),
        action,
      ],
    );
  }
}

class _OfficeSummaryCards extends StatelessWidget {
  const _OfficeSummaryCards({
    required this.section,
    required this.projection,
    required this.language,
  });

  final YorksAccountsOfficeSection section;
  final YorksAccountsOfficeProjection projection;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final summary = projection.summary;
    final currency = projection.items.firstOrNull?.currencyCode ?? 'AED';
    final items = <_OfficeMetric>[
      _OfficeMetric(
        'office_records',
        '${projection.total}',
        Icons.inventory_2_outlined,
        AppColors.blue,
      ),
      if (section != YorksAccountsOfficeSection.documents &&
          section != YorksAccountsOfficeSection.activity)
        _OfficeMetric(
          'office_total_value',
          _money(currency, summary.amount),
          Icons.payments_outlined,
          AppColors.success,
        ),
      if (section == YorksAccountsOfficeSection.claims ||
          section == YorksAccountsOfficeSection.supplierBills ||
          section == YorksAccountsOfficeSection.dueSchedule)
        _OfficeMetric(
          'office_secondary_value',
          _money(currency, summary.secondaryAmount),
          Icons.verified_outlined,
          AppColors.purple,
        ),
      if (section == YorksAccountsOfficeSection.claims ||
          section == YorksAccountsOfficeSection.supplierBills ||
          section == YorksAccountsOfficeSection.dueSchedule)
        _OfficeMetric(
          'office_outstanding',
          _money(currency, summary.balanceAmount),
          Icons.schedule_outlined,
          AppColors.warning,
        ),
      if (summary.actionCount > 0)
        _OfficeMetric(
          'office_needs_action',
          '${summary.actionCount}',
          Icons.notification_important_outlined,
          AppColors.error,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 680
            ? 3
            : 2;
        final spacing = constraints.maxWidth < 680
            ? AppSpacing.sm
            : AppSpacing.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _OfficeMetricCard(item: item, language: language),
              ),
          ],
        );
      },
    );
  }
}

class _OfficeMetric {
  const _OfficeMetric(this.labelKey, this.value, this.icon, this.color);
  final String labelKey;
  final String value;
  final IconData icon;
  final Color color;
}

class _OfficeMetricCard extends StatelessWidget {
  const _OfficeMetricCard({required this.item, required this.language});
  final _OfficeMetric item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _OfficePanel(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(item.icon, color: item.color, size: 21),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(language, item.labelKey),
                style: AppTypography.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OfficeLoadingCards extends StatelessWidget {
  const _OfficeLoadingCards();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 92,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _OfficeFilterBar extends StatelessWidget {
  const _OfficeFilterBar({
    required this.language,
    required this.controller,
    required this.status,
    required this.statuses,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  final AppLanguage language;
  final TextEditingController controller;
  final String? status;
  final List<String> statuses;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => _OfficePanel(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: _t(language, 'office_search'),
          ),
        );
        final statusFilter = DropdownButtonFormField<String>(
          initialValue: status,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(_t(language, 'office_all_statuses')),
            ),
            for (final value in statuses)
              DropdownMenuItem(
                value: value,
                child: Text(_status(language, value)),
              ),
          ],
          onChanged: onStatusChanged,
        );
        final clear = IconButton.outlined(
          tooltip: _t(language, 'clear'),
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
        );
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              search,
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: statusFilter),
                  const SizedBox(width: AppSpacing.sm),
                  clear,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: statusFilter),
            const SizedBox(width: AppSpacing.sm),
            clear,
          ],
        );
      },
    ),
  );
}

class _OfficeRegister extends StatelessWidget {
  const _OfficeRegister({
    required this.section,
    required this.state,
    required this.language,
    required this.onRetry,
    required this.onLoadMore,
  });

  final YorksAccountsOfficeSection section;
  final YorksAccountsOfficeState state;
  final AppLanguage language;
  final VoidCallback onRetry;
  final Future<bool> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final projection = state.projection;
    if (projection == null) {
      if (state.status == YorksAccountsViewStatus.loading ||
          state.status == YorksAccountsViewStatus.idle) {
        return const _OfficePanel(
          child: SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      return _OfficeStatePanel(
        status: state.status,
        language: language,
        onRetry: onRetry,
      );
    }
    if (projection.items.isEmpty) {
      return _OfficePanel(
        child: SizedBox(
          height: 260,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  color: AppColors.muted,
                  size: 38,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _t(language, 'office_no_records'),
                  style: AppTypography.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _OfficePanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == YorksAccountsViewStatus.loading)
            const LinearProgressIndicator(minHeight: 3),
          if (state.error != null &&
              state.status != YorksAccountsViewStatus.loading) ...[
            _OfficeRefreshError(language: language, onRetry: onRetry),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _t(language, 'office_records'),
                    style: AppTypography.titleMedium,
                  ),
                ),
                Text(
                  '${projection.items.length} / ${projection.total}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 820
                ? Column(
                    children: [
                      for (final item in projection.items)
                        _OfficeRecordCard(
                          item: item,
                          language: language,
                          onTap: () => _openItem(context, section, item),
                        ),
                    ],
                  )
                : _OfficeRecordsTable(
                    items: projection.items,
                    language: language,
                    section: section,
                  ),
          ),
          if (projection.hasMore) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: state.isLoadingMore ? null : onLoadMore,
                  icon: state.isLoadingMore
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_t(language, 'office_load_more')),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfficeRefreshError extends StatelessWidget {
  const _OfficeRefreshError({required this.language, required this.onRetry});

  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ColoredBox(
      color: AppColors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _t(language, 'load_failed'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_t(language, 'retry')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OfficeRecordsTable extends StatelessWidget {
  const _OfficeRecordsTable({
    required this.items,
    required this.language,
    required this.section,
  });

  final List<YorksAccountsOfficeItem> items;
  final AppLanguage language;
  final YorksAccountsOfficeSection section;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 1160),
      child: DataTable(
        dataRowMinHeight: 62,
        dataRowMaxHeight: 70,
        headingRowColor: const WidgetStatePropertyAll(
          AppColors.surfaceContainerLow,
        ),
        columns: [
          DataColumn(label: Text(_t(language, 'project'))),
          DataColumn(label: Text(_t(language, 'office_reference'))),
          DataColumn(label: Text(_t(language, 'office_party'))),
          DataColumn(numeric: true, label: Text(_t(language, 'office_amount'))),
          DataColumn(label: Text(_t(language, 'office_date'))),
          DataColumn(label: Text(_t(language, 'office_due_date'))),
          DataColumn(label: Text(_t(language, 'office_status'))),
          const DataColumn(label: SizedBox.shrink()),
        ],
        rows: [
          for (final item in items)
            DataRow(
              onSelectChanged: (_) => _openItem(context, section, item),
              cells: [
                DataCell(
                  SizedBox(
                    width: 205,
                    child: _OfficeTwoLine(
                      title: item.projectReference,
                      subtitle: item.projectName,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 175,
                    child: _OfficeTwoLine(
                      title: item.reference,
                      subtitle: item.secondaryReference ?? '—',
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      item.party ?? '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    item.amount == null
                        ? '—'
                        : _money(item.currencyCode, item.amount!),
                    style: AppTypography.labelLarge,
                  ),
                ),
                DataCell(Text(_dateText(item.eventDate, language))),
                DataCell(Text(_dateText(item.dueDate, language))),
                DataCell(_OfficeStatusBadge(item: item, language: language)),
                DataCell(
                  IconButton(
                    tooltip: _t(language, 'office_open_project'),
                    onPressed: () => _openItem(context, section, item),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _OfficeRecordCard extends StatelessWidget {
  const _OfficeRecordCard({
    required this.item,
    required this.language,
    required this.onTap,
  });

  final YorksAccountsOfficeItem item;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OfficeTwoLine(
                  title: item.reference,
                  subtitle: '${item.projectReference} · ${item.projectName}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _OfficeStatusBadge(item: item, language: language),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _OfficeMiniField(
                  label: _t(language, 'office_party'),
                  value: item.party ?? '—',
                ),
              ),
              Expanded(
                child: _OfficeMiniField(
                  label: _t(language, 'office_amount'),
                  value: item.amount == null
                      ? '—'
                      : _money(item.currencyCode, item.amount!),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _OfficeMiniField(
                  label: _t(language, 'office_date'),
                  value: _dateText(item.eventDate, language),
                ),
              ),
              Expanded(
                child: _OfficeMiniField(
                  label: _t(language, 'office_due_date'),
                  value: _dateText(item.dueDate, language),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OfficeInsights extends StatelessWidget {
  const _OfficeInsights({
    required this.section,
    required this.projection,
    required this.language,
  });

  final YorksAccountsOfficeSection section;
  final YorksAccountsOfficeProjection projection;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _OfficePanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                _t(language, 'office_recent'),
                style: AppTypography.titleMedium,
              ),
            ),
            const Divider(height: 1),
            for (final item in projection.items.take(5))
              ListTile(
                dense: true,
                minTileHeight: 58,
                leading: Icon(
                  item.actionRequired
                      ? Icons.notification_important_outlined
                      : Icons.check_circle_outline_rounded,
                  color: item.actionRequired
                      ? AppColors.warning
                      : AppColors.success,
                ),
                title: Text(
                  item.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  item.projectReference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _openItem(context, section, item),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _OfficePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(language, 'office_quick_actions'),
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.go(RoutePaths.yorksV1AccountsProjects),
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(_t(language, 'office_open_project')),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OfficeStatePanel extends StatelessWidget {
  const _OfficeStatePanel({
    required this.status,
    required this.language,
    required this.onRetry,
  });

  final YorksAccountsViewStatus status;
  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final key = switch (status) {
      YorksAccountsViewStatus.offline => 'offline',
      YorksAccountsViewStatus.forbidden => 'forbidden',
      YorksAccountsViewStatus.unavailable => 'load_failed',
      YorksAccountsViewStatus.sessionExpired => 'forbidden',
      _ => 'load_failed',
    };
    return _OfficePanel(
      child: SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.muted,
                size: 38,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _t(language, key),
                style: AppTypography.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t(language, 'retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeStatusBadge extends StatelessWidget {
  const _OfficeStatusBadge({required this.item, required this.language});
  final YorksAccountsOfficeItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final danger = item.status == 'overdue' || item.status == 'returned';
    final warning =
        item.actionRequired ||
        item.status == 'due_soon' ||
        item.status == 'partially_paid' ||
        item.status == 'review';
    final color = danger
        ? AppColors.error
        : warning
        ? AppColors.warning
        : AppColors.success;
    final background = danger
        ? AppColors.errorContainer
        : warning
        ? AppColors.warningContainer
        : AppColors.successContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        _status(language, item.status),
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _OfficePanel extends StatelessWidget {
  const _OfficePanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class _OfficePanelTitle extends StatelessWidget {
  const _OfficePanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(width: 0),
      Icon(icon, color: AppColors.blue),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppTypography.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class _OfficeTwoLine extends StatelessWidget {
  const _OfficeTwoLine({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge.copyWith(color: AppColors.blue),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall,
      ),
    ],
  );
}

class _OfficeMiniField extends StatelessWidget {
  const _OfficeMiniField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodyMedium,
      ),
    ],
  );
}

class _OfficeSectionConfig {
  const _OfficeSectionConfig({
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
    required this.color,
    this.statuses = const [],
  });

  final String titleKey;
  final String bodyKey;
  final IconData icon;
  final Color color;
  final List<String> statuses;

  static _OfficeSectionConfig forSection(YorksAccountsOfficeSection section) =>
      switch (section) {
        YorksAccountsOfficeSection.claims => const _OfficeSectionConfig(
          titleKey: 'office_claims_title',
          bodyKey: 'office_claims_body',
          icon: Icons.request_page_outlined,
          color: AppColors.blue,
          statuses: [
            'draft',
            'ready_for_accounts',
            'submitted',
            'under_certification',
            'partially_certified',
            'certified',
            'partially_paid',
            'paid',
            'returned',
          ],
        ),
        YorksAccountsOfficeSection.clientPayments => const _OfficeSectionConfig(
          titleKey: 'office_payments_title',
          bodyKey: 'office_payments_body',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
          statuses: [
            'received',
            'reversed',
            'expected',
            'deposited',
            'cleared',
            'bounced',
            'replaced',
            'cancelled',
          ],
        ),
        YorksAccountsOfficeSection.supplierBills => const _OfficeSectionConfig(
          titleKey: 'supplier_bills',
          bodyKey: 'office_supplier_body',
          icon: Icons.receipt_long_outlined,
          color: AppColors.warning,
          statuses: [
            'draft',
            'review',
            'approved',
            'partially_paid',
            'paid',
            'cancelled',
          ],
        ),
        YorksAccountsOfficeSection.dueSchedule => const _OfficeSectionConfig(
          titleKey: 'office_due_title',
          bodyKey: 'office_due_body',
          icon: Icons.calendar_month_outlined,
          color: AppColors.error,
          statuses: ['current', 'due_soon', 'due_today', 'overdue'],
        ),
        YorksAccountsOfficeSection.documents => const _OfficeSectionConfig(
          titleKey: 'documents',
          bodyKey: 'office_documents_body',
          icon: Icons.folder_copy_outlined,
          color: AppColors.blue,
          statuses: ['active', 'archived'],
        ),
        YorksAccountsOfficeSection.activity => const _OfficeSectionConfig(
          titleKey: 'office_activity_title',
          bodyKey: 'office_activity_body',
          icon: Icons.policy_outlined,
          color: AppColors.purple,
          statuses: ['recorded'],
        ),
      };
}

void _openItem(
  BuildContext context,
  YorksAccountsOfficeSection section,
  YorksAccountsOfficeItem item,
) {
  context.go(yorksAccountsOfficeItemRoute(section, item));
}

@visibleForTesting
String yorksAccountsOfficeItemRoute(
  YorksAccountsOfficeSection section,
  YorksAccountsOfficeItem item,
) => switch (section) {
  YorksAccountsOfficeSection.claims =>
    RoutePaths.yorksV1ProjectAccountsInvoicesPath(item.projectId),
  YorksAccountsOfficeSection.clientPayments =>
    RoutePaths.yorksV1ProjectAccountsReceiptsPdcPath(item.projectId),
  YorksAccountsOfficeSection.supplierBills =>
    RoutePaths.yorksV1ProjectAccountsSupplierBillsPath(item.projectId),
  YorksAccountsOfficeSection.dueSchedule
      when item.recordKind == 'supplier_bill_due' =>
    RoutePaths.yorksV1ProjectAccountsSupplierBillsPath(item.projectId),
  YorksAccountsOfficeSection.dueSchedule
      when item.recordKind == 'client_invoice_due' =>
    RoutePaths.yorksV1ProjectAccountsInvoicesPath(item.projectId),
  YorksAccountsOfficeSection.dueSchedule when item.recordKind == 'pdc_due' =>
    RoutePaths.yorksV1ProjectAccountsReceiptsPdcPath(item.projectId),
  YorksAccountsOfficeSection.dueSchedule =>
    RoutePaths.yorksV1ProjectAccountsOverviewPath(item.projectId),
  YorksAccountsOfficeSection.documents =>
    RoutePaths.yorksV1ProjectAccountsDocumentsPath(item.projectId),
  YorksAccountsOfficeSection.activity =>
    RoutePaths.yorksV1ProjectAccountsActivityPath(item.projectId),
};

String _t(AppLanguage language, String key) =>
    YorksV1AccountsStrings.text(language, key);

String _status(AppLanguage language, String status) {
  final translated = _t(language, 'status_$status');
  if (translated != 'status_$status') return translated;
  final words = status.split('_');
  return words
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _money(String currency, YorksAccountsDecimal amount) {
  final canonical = amount.canonicalText;
  final negative = canonical.startsWith('-');
  final unsigned = negative ? canonical.substring(1) : canonical;
  final parts = unsigned.split('.');
  final whole = parts.first;
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final fraction = parts.length == 1
      ? '00'
      : parts[1].padRight(2, '0').substring(0, 2);
  return '$currency ${negative ? '-' : ''}$grouped.$fraction';
}

String _dateText(DateTime? date, AppLanguage language) {
  if (date == null) return '—';
  // DateFormat's default catalogue is bundled with the application. Passing a
  // dynamic locale here would require an asynchronous locale-data bootstrap
  // before this protected register can render.
  return DateFormat.yMMMd().format(date.toLocal());
}
