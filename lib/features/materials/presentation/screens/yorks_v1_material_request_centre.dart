import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/ledger_card.dart';
import '../../../../core/widgets/yorks_v1_active_text.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_material_request.dart';
import '../../../../shared/models/yorks_v1_material_request_strings.dart';

/// The cross-project Material Request register.
///
/// This is a presentation-only projection over the authorized request list.
/// It deliberately derives every count, folder, activity item and filter from
/// the same server-backed records that open the existing request detail. It
/// never recreates workflow status, ownership or permissions on the client.
class YorksV1MaterialRequestCentre extends StatefulWidget {
  const YorksV1MaterialRequestCentre({
    super.key,
    required this.requests,
    required this.language,
    required this.canCreate,
    required this.onCreate,
    required this.onOpen,
    required this.onRefresh,
    this.localDraftNotice,
    this.fixedProjectId,
    this.summaryPageLoader,
    this.refreshRevision = 0,
  });

  final List<YorksV1MaterialRequest> requests;
  final AppLanguage language;
  final bool canCreate;
  final VoidCallback onCreate;
  final ValueChanged<YorksV1MaterialRequest> onOpen;
  final VoidCallback onRefresh;
  final Widget? localDraftNotice;
  final String? fixedProjectId;
  final Future<YorksV1MaterialRequestSummaryPage> Function(
    YorksV1MaterialRequestSummaryQuery query,
  )?
  summaryPageLoader;
  final int refreshRevision;

  @override
  State<YorksV1MaterialRequestCentre> createState() =>
      _YorksV1MaterialRequestCentreState();
}

enum _MaterialRequestCentreDateRange { allTime, sevenDays, thirtyDays }

enum _MaterialRequestMetricFilter {
  all,
  open,
  inProgress,
  dispatched,
  received,
  closed,
}

enum _MaterialRequestCentreView { allRequests, projects }

class _YorksV1MaterialRequestCentreState
    extends State<YorksV1MaterialRequestCentre> {
  static const _allSelection = '__all__';
  final _searchController = TextEditingController();
  _MaterialRequestCentreDateRange _dateRange =
      _MaterialRequestCentreDateRange.allTime;
  _MaterialRequestMetricFilter _metricFilter = _MaterialRequestMetricFilter.all;
  String _status = _allSelection;
  String _project = _allSelection;
  String _scope = _allSelection;
  String _requester = _allSelection;
  bool _attentionOnly = false;
  bool _newestFirst = true;
  _MaterialRequestCentreView _view = _MaterialRequestCentreView.allRequests;
  bool _filtersExpanded = false;
  final Set<String> _expandedProjectIds = <String>{};
  int _page = 0;
  YorksV1MaterialRequestSummaryPage? _serverPage;
  Object? _serverError;
  bool _serverLoading = false;
  Timer? _serverSearchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.summaryPageLoader != null) {
      unawaited(_loadServerPage());
    }
  }

  @override
  void didUpdateWidget(covariant YorksV1MaterialRequestCentre oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summaryPageLoader != widget.summaryPageLoader ||
        oldWidget.fixedProjectId != widget.fixedProjectId ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      unawaited(_loadServerPage());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _serverSearchDebounce?.cancel();
    super.dispose();
  }

  void _update(VoidCallback update, {bool search = false}) {
    setState(() {
      update();
      _page = 0;
    });
    if (widget.summaryPageLoader == null) return;
    _serverSearchDebounce?.cancel();
    if (search) {
      _serverSearchDebounce = Timer(
        const Duration(milliseconds: 320),
        () => unawaited(_loadServerPage()),
      );
    } else {
      unawaited(_loadServerPage());
    }
  }

  YorksV1MaterialRequestSummaryQuery get _serverQuery {
    final cutoff = switch (_dateRange) {
      _MaterialRequestCentreDateRange.allTime => null,
      _MaterialRequestCentreDateRange.sevenDays =>
        DateTime.now().toUtc().subtract(const Duration(days: 7)),
      _MaterialRequestCentreDateRange.thirtyDays =>
        DateTime.now().toUtc().subtract(const Duration(days: 30)),
    };
    return YorksV1MaterialRequestSummaryQuery(
      projectId: widget.fixedProjectId?.trim().isNotEmpty == true
          ? widget.fixedProjectId
          : (_project == _allSelection ? null : _project),
      search: _searchController.text,
      states: _status == _allSelection
          ? const []
          : [YorksV1MaterialRequestState.fromWireValue(_status)!],
      scopeId: _scope == _allSelection ? null : _scope,
      requester: _requester == _allSelection ? null : _requester,
      updatedAfter: cutoff,
      attentionOnly: _attentionOnly,
      metric: switch (_metricFilter) {
        _MaterialRequestMetricFilter.all => 'all',
        _MaterialRequestMetricFilter.open => 'open',
        _MaterialRequestMetricFilter.inProgress => 'in_progress',
        _MaterialRequestMetricFilter.dispatched => 'dispatched',
        _MaterialRequestMetricFilter.received => 'received',
        _MaterialRequestMetricFilter.closed => 'closed',
      },
      newestFirst: _newestFirst,
      limit: _view == _MaterialRequestCentreView.projects ? 100 : 15,
      offset: _view == _MaterialRequestCentreView.projects ? 0 : _page * 15,
    );
  }

  Future<void> _loadServerPage() async {
    final loader = widget.summaryPageLoader;
    if (loader == null || !mounted) return;
    final query = _serverQuery;
    setState(() {
      _serverLoading = true;
      _serverError = null;
    });
    try {
      var page = await loader(query);
      if (_view == _MaterialRequestCentreView.projects) {
        final items = [...page.items];
        var nextOffset = page.offset + page.items.length;
        var pagesLoaded = 1;
        while (page.hasMore && pagesLoaded < 100) {
          page = await loader(query.copyWith(offset: nextOffset));
          items.addAll(page.items);
          nextOffset += page.items.length;
          pagesLoaded++;
          if (page.items.isEmpty) break;
        }
        page = YorksV1MaterialRequestSummaryPage(
          items: items,
          totalCount: page.totalCount,
          limit: items.length,
          offset: 0,
          hasMore: page.hasMore,
          metrics: page.metrics,
        );
      }
      if (!mounted || query != _serverQuery) return;
      setState(() {
        _serverPage = page;
        _serverLoading = false;
      });
    } catch (error) {
      if (!mounted || query != _serverQuery) return;
      setState(() {
        _serverError = error;
        _serverLoading = false;
      });
    }
  }

  void _clearFilters() => _update(() {
    _searchController.clear();
    _status = _allSelection;
    _project = _allSelection;
    _scope = _allSelection;
    _requester = _allSelection;
    _attentionOnly = false;
    _dateRange = _MaterialRequestCentreDateRange.allTime;
    _metricFilter = _MaterialRequestMetricFilter.all;
  });

  @override
  Widget build(BuildContext context) {
    final source = widget.summaryPageLoader == null
        ? widget.requests
        : (_serverPage?.items
                  .map((summary) => summary.toRegisterProjection())
                  .toList(growable: false) ??
              const <YorksV1MaterialRequest>[]);
    final visible = _visibleRequests(source);
    final folders = _foldersFor(visible, newestFirst: _newestFirst);
    final metrics = _serverPage == null
        ? _MaterialRequestCentreMetrics.fromRequests(source)
        : _MaterialRequestCentreMetrics.fromSummary(_serverPage!.metrics);
    final isCompact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;

    return ListView(
      key: const ValueKey('material-request-centre'),
      padding: EdgeInsets.fromLTRB(
        isCompact ? AppSpacing.md : AppSpacing.xl,
        isCompact ? AppSpacing.md : AppSpacing.lg,
        isCompact ? AppSpacing.md : AppSpacing.xxl,
        AppSpacing.xxxl,
      ),
      children: [
        _CentreHeader(
          language: widget.language,
          canCreate: widget.canCreate,
          onCreate: widget.onCreate,
          onRefresh: widget.summaryPageLoader == null
              ? widget.onRefresh
              : () => unawaited(_loadServerPage()),
        ),
        if (widget.localDraftNotice != null) ...[
          const SizedBox(height: AppSpacing.md),
          widget.localDraftNotice!,
        ],
        const SizedBox(height: AppSpacing.xl),
        _MetricsGrid(
          metrics: metrics,
          language: widget.language,
          selected: _metricFilter,
          onSelected: (value) => _update(() {
            _metricFilter = value;
            _view = _MaterialRequestCentreView.allRequests;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_serverError != null && _serverPage == null)
          _MaterialRequestCentreLoadError(
            language: widget.language,
            onRetry: () => unawaited(_loadServerPage()),
          )
        else
          _MainCentrePanel(
            language: widget.language,
            searchController: _searchController,
            onSearchChanged: (_) => _update(() {}, search: true),
            newestFirst: _newestFirst,
            onSortChanged: (value) => _update(() => _newestFirst = value),
            view: _view,
            onViewChanged: (value) => _update(() => _view = value),
            filtersExpanded: _filtersExpanded,
            onFiltersExpandedChanged: (value) =>
                setState(() => _filtersExpanded = value),
            activeFilterCount: _activeFilterCount,
            filter: _FilterForm(
              language: widget.language,
              status: _status,
              project: _project,
              scope: _scope,
              requester: _requester,
              dateRange: _dateRange,
              attentionOnly: _attentionOnly,
              requests: source,
              fixedProjectId: widget.fixedProjectId,
              onStatusChanged: (value) => _update(() => _status = value),
              onProjectChanged: (value) => _update(() => _project = value),
              onScopeChanged: (value) => _update(() => _scope = value),
              onRequesterChanged: (value) => _update(() => _requester = value),
              onDateRangeChanged: (value) => _update(() => _dateRange = value),
              onAttentionOnlyChanged: (value) =>
                  _update(() => _attentionOnly = value),
              onClear: _clearFilters,
              onApply: () => setState(() => _filtersExpanded = false),
            ),
            folders: folders,
            requests: visible,
            serverTotalItems:
                widget.summaryPageLoader != null &&
                    _view == _MaterialRequestCentreView.allRequests
                ? _serverPage?.totalCount
                : null,
            serverPageMode:
                widget.summaryPageLoader != null &&
                _view == _MaterialRequestCentreView.allRequests,
            expandedProjectIds: _expandedProjectIds,
            onProjectExpanded: (projectId) => setState(() {
              if (!_expandedProjectIds.add(projectId)) {
                _expandedProjectIds.remove(projectId);
              }
            }),
            page: _page,
            onPageChanged: (value) {
              setState(() => _page = value);
              if (widget.summaryPageLoader != null) {
                unawaited(_loadServerPage());
              }
            },
            onOpen: widget.onOpen,
          ),
        if (_serverLoading)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_serverError != null && _serverPage != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => unawaited(_loadServerPage()),
                icon: const Icon(Icons.refresh_rounded),
                label: YorksV1ActiveText(
                  copy: YorksV1MaterialRequestStrings.tryAgain,
                  language: widget.language,
                ),
              ),
            ),
          ),
      ],
    );
  }

  int get _activeFilterCount => [
    _status != _allSelection,
    _project != _allSelection,
    _scope != _allSelection,
    _requester != _allSelection,
    _dateRange != _MaterialRequestCentreDateRange.allTime,
    _attentionOnly,
    _metricFilter != _MaterialRequestMetricFilter.all,
  ].where((active) => active).length;

  List<YorksV1MaterialRequest> _visibleRequests(
    List<YorksV1MaterialRequest> requests,
  ) {
    if (widget.summaryPageLoader != null) return requests;
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    final source =
        requests
            .where((request) {
              if (widget.fixedProjectId != null &&
                  widget.fixedProjectId!.isNotEmpty &&
                  request.projectId != widget.fixedProjectId) {
                return false;
              }
              if (_status != _allSelection &&
                  request.state.wireValue != _status) {
                return false;
              }
              if (_project != _allSelection && request.projectId != _project) {
                return false;
              }
              if (_scope != _allSelection && request.scopeId != _scope) {
                return false;
              }
              if (_requester != _allSelection &&
                  request.requesterDisplayName != _requester) {
                return false;
              }
              final cutoff = switch (_dateRange) {
                _MaterialRequestCentreDateRange.allTime => null,
                _MaterialRequestCentreDateRange.sevenDays => now.subtract(
                  const Duration(days: 7),
                ),
                _MaterialRequestCentreDateRange.thirtyDays => now.subtract(
                  const Duration(days: 30),
                ),
              };
              if (cutoff != null && request.updatedAt.isBefore(cutoff)) {
                return false;
              }
              if (_attentionOnly && !_requiresAttention(request)) return false;
              if (!_matchesMetricFilter(request, _metricFilter)) return false;
              if (query.isEmpty) return true;
              final searchable = [
                request.requestNumber,
                request.title,
                request.projectReference,
                request.projectName,
                request.scopeName,
                request.requesterDisplayName,
                for (final line in request.lines) line.description,
              ].whereType<String>().join(' ').toLowerCase();
              return searchable.contains(query);
            })
            .toList(growable: false)
          ..sort(
            (a, b) => _newestFirst
                ? b.updatedAt.compareTo(a.updatedAt)
                : a.updatedAt.compareTo(b.updatedAt),
          );
    return source;
  }
}

class _MaterialRequestCentreLoadError extends StatelessWidget {
  const _MaterialRequestCentreLoadError({
    required this.language,
    required this.onRetry,
  });

  final AppLanguage language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => LedgerCard(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 240),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('material-request-centre-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: YorksV1ActiveText(
                copy: YorksV1MaterialRequestStrings.tryAgain,
                language: language,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _isArchived(YorksV1MaterialRequest request) =>
    request.state == YorksV1MaterialRequestState.closed ||
    request.state == YorksV1MaterialRequestState.cancelled;

bool _isActive(YorksV1MaterialRequest request) =>
    !_isArchived(request) && !request.state.isDraft;

bool _requiresAttention(YorksV1MaterialRequest request) {
  if (_isArchived(request) || request.state.isDraft) return false;
  return request.currentActionCode?.trim().isNotEmpty == true ||
      request.state == YorksV1MaterialRequestState.awaitingRequestApproval ||
      request.state == YorksV1MaterialRequestState.changesRequested ||
      request.state == YorksV1MaterialRequestState.arranging ||
      request.state == YorksV1MaterialRequestState.dispatched ||
      request.state == YorksV1MaterialRequestState.partiallyDispatched ||
      request.state == YorksV1MaterialRequestState.partiallyReceived ||
      request.state == YorksV1MaterialRequestState.received;
}

bool _matchesMetricFilter(
  YorksV1MaterialRequest request,
  _MaterialRequestMetricFilter filter,
) => switch (filter) {
  _MaterialRequestMetricFilter.all => true,
  _MaterialRequestMetricFilter.open =>
    request.state.isDraft ||
        request.state == YorksV1MaterialRequestState.submitted ||
        request.state == YorksV1MaterialRequestState.awaitingRequestApproval ||
        request.state == YorksV1MaterialRequestState.changesRequested,
  _MaterialRequestMetricFilter.inProgress =>
    !_isArchived(request) &&
        !request.state.isDraft &&
        request.state != YorksV1MaterialRequestState.submitted &&
        request.state != YorksV1MaterialRequestState.awaitingRequestApproval &&
        request.state != YorksV1MaterialRequestState.changesRequested &&
        request.state != YorksV1MaterialRequestState.dispatched &&
        request.state != YorksV1MaterialRequestState.partiallyDispatched &&
        request.state != YorksV1MaterialRequestState.received &&
        request.state != YorksV1MaterialRequestState.partiallyReceived,
  _MaterialRequestMetricFilter.dispatched =>
    request.state == YorksV1MaterialRequestState.dispatched ||
        request.state == YorksV1MaterialRequestState.partiallyDispatched,
  _MaterialRequestMetricFilter.received =>
    request.state == YorksV1MaterialRequestState.received ||
        request.state == YorksV1MaterialRequestState.partiallyReceived,
  _MaterialRequestMetricFilter.closed => _isArchived(request),
};

class _MaterialRequestCentreMetrics {
  const _MaterialRequestCentreMetrics({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.dispatched,
    required this.received,
    required this.closed,
  });

  final int total;
  final int open;
  final int inProgress;
  final int dispatched;
  final int received;
  final int closed;

  factory _MaterialRequestCentreMetrics.fromRequests(
    List<YorksV1MaterialRequest> requests,
  ) => _MaterialRequestCentreMetrics(
    total: requests.length,
    open: requests
        .where(
          (request) =>
              _matchesMetricFilter(request, _MaterialRequestMetricFilter.open),
        )
        .length,
    inProgress: requests
        .where(
          (request) => _matchesMetricFilter(
            request,
            _MaterialRequestMetricFilter.inProgress,
          ),
        )
        .length,
    dispatched: requests
        .where(
          (request) =>
              request.state == YorksV1MaterialRequestState.dispatched ||
              request.state == YorksV1MaterialRequestState.partiallyDispatched,
        )
        .length,
    received: requests
        .where(
          (request) =>
              request.state == YorksV1MaterialRequestState.received ||
              request.state == YorksV1MaterialRequestState.partiallyReceived,
        )
        .length,
    closed: requests
        .where((request) => request.state == YorksV1MaterialRequestState.closed)
        .length,
  );

  factory _MaterialRequestCentreMetrics.fromSummary(
    YorksV1MaterialRequestSummaryMetrics metrics,
  ) => _MaterialRequestCentreMetrics(
    total: metrics.total,
    open: metrics.open,
    inProgress: metrics.inProgress,
    dispatched: metrics.dispatched,
    received: metrics.received,
    closed: metrics.closed,
  );
}

class _ProjectRequestFolder {
  const _ProjectRequestFolder({required this.requests});

  final List<YorksV1MaterialRequest> requests;

  YorksV1MaterialRequest get latest => requests.reduce(
    (current, candidate) =>
        candidate.updatedAt.isAfter(current.updatedAt) ? candidate : current,
  );
  String get id => latest.projectId;
  String get reference => latest.projectReference;
  String get name => latest.projectName;
  int get active => requests.where(_isActive).length;
  int get closed => requests
      .where((request) => request.state == YorksV1MaterialRequestState.closed)
      .length;
  int get scopeCount =>
      requests.map((request) => request.scopeId).toSet().length;
}

List<_ProjectRequestFolder> _foldersFor(
  List<YorksV1MaterialRequest> requests, {
  required bool newestFirst,
}) {
  final grouped = <String, List<YorksV1MaterialRequest>>{};
  for (final request in requests) {
    (grouped[request.projectId] ??= []).add(request);
  }
  return grouped.values
      .map((requests) {
        requests.sort(
          (a, b) => newestFirst
              ? b.updatedAt.compareTo(a.updatedAt)
              : a.updatedAt.compareTo(b.updatedAt),
        );
        return _ProjectRequestFolder(requests: List.unmodifiable(requests));
      })
      .toList(growable: false)
    ..sort(
      (a, b) => newestFirst
          ? b.latest.updatedAt.compareTo(a.latest.updatedAt)
          : a.latest.updatedAt.compareTo(b.latest.updatedAt),
    );
}

class _CentreHeader extends StatelessWidget {
  const _CentreHeader({
    required this.language,
    required this.canCreate,
    required this.onCreate,
    required this.onRefresh,
  });

  final AppLanguage language;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: AppColors.blueContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(
            Icons.folder_copy_outlined,
            color: AppColors.blue,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YorksV1ActiveText(
                copy: YorksV1MaterialRequestStrings.materialRequestCentre,
                language: language,
                style:
                    (compact
                            ? AppTypography.headlineMedium
                            : AppTypography.displaySmall)
                        .copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              YorksV1ActiveText(
                copy: YorksV1MaterialRequestStrings
                    .materialRequestCentreDescription,
                language: language,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.end,
      children: [
        Tooltip(
          message: YorksV1MaterialRequestStrings.refresh.active(language),
          child: SizedBox.square(
            dimension: AppSpacing.minTapTarget,
            child: IconButton(
              key: const ValueKey('material-request-centre-refresh'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ),
        if (canCreate)
          SizedBox(
            height: AppSpacing.minTapTarget,
            child: FilledButton.icon(
              key: const ValueKey('material-request-centre-create'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: YorksV1ActiveText(
                copy: YorksV1MaterialRequestStrings.newRequest,
                language: language,
                style: AppTypography.titleSmall.copyWith(color: Colors.white),
              ),
            ),
          ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: AppSpacing.md),
          actions,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppSpacing.lg),
        actions,
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.metrics,
    required this.language,
    required this.selected,
    required this.onSelected,
  });

  final _MaterialRequestCentreMetrics metrics;
  final AppLanguage language;
  final _MaterialRequestMetricFilter selected;
  final ValueChanged<_MaterialRequestMetricFilter> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= AppSpacing.wideBreakpoint
          ? 6
          : width >= AppSpacing.compactBreakpoint
          ? 3
          : 2;
      const gap = AppSpacing.sm;
      final cardWidth = (width - (columns - 1) * gap) / columns;
      final tiles = [
        _MetricData(
          YorksV1MaterialRequestStrings.totalMaterialRequests,
          YorksV1MaterialRequestStrings.allTime,
          metrics.total,
          Icons.description_outlined,
          AppColors.blue,
          AppColors.blueContainer,
          _MaterialRequestMetricFilter.all,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.openMetric,
          YorksV1MaterialRequestStrings.viewOpen,
          metrics.open,
          Icons.folder_open_outlined,
          AppColors.success,
          AppColors.successContainer,
          _MaterialRequestMetricFilter.open,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.inProgressMetric,
          YorksV1MaterialRequestStrings.viewInProgress,
          metrics.inProgress,
          Icons.schedule_rounded,
          AppColors.warning,
          AppColors.warningContainer,
          _MaterialRequestMetricFilter.inProgress,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.dispatchedMetric,
          YorksV1MaterialRequestStrings.onTheWay,
          metrics.dispatched,
          Icons.local_shipping_outlined,
          AppColors.blue,
          AppColors.blueContainer,
          _MaterialRequestMetricFilter.dispatched,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.receivedMetric,
          YorksV1MaterialRequestStrings.atSiteOrWarehouse,
          metrics.received,
          Icons.inventory_2_outlined,
          AppColors.success,
          AppColors.successContainer,
          _MaterialRequestMetricFilter.received,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.closedMetric,
          YorksV1MaterialRequestStrings.completed,
          metrics.closed,
          Icons.archive_outlined,
          AppColors.neutralText,
          AppColors.neutralContainer,
          _MaterialRequestMetricFilter.closed,
        ),
      ];
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        alignment: WrapAlignment.center,
        children: [
          for (final tile in tiles)
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                data: tile,
                language: language,
                selected: selected == tile.filter,
                onTap: () => onSelected(tile.filter),
              ),
            ),
        ],
      );
    },
  );
}

class _MetricData {
  const _MetricData(
    this.label,
    this.hint,
    this.value,
    this.icon,
    this.foreground,
    this.background,
    this.filter,
  );

  final TranslatableString label;
  final TranslatableString hint;
  final int value;
  final IconData icon;
  final Color foreground;
  final Color background;
  final _MaterialRequestMetricFilter filter;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.data,
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final _MetricData data;
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(data.icon, color: data.foreground, size: 21),
    );
    final value = Text(
      '${data.value}',
      style: AppTypography.headlineSmall.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
    final label = YorksV1ActiveText(
      copy: data.label,
      language: language,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.labelMedium.copyWith(color: AppColors.muted),
    );
    final hint = YorksV1ActiveText(
      copy: data.hint,
      language: language,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        elevation: selected ? 2 : 1,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? data.foreground : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: InkWell(
          key: ValueKey('material-request-metric-${data.filter.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 170) {
                  final compactLabel = YorksV1ActiveText(
                    copy: data.label,
                    language: language,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [icon, const Spacer(), value]),
                      const SizedBox(height: AppSpacing.xs),
                      compactLabel,
                      const SizedBox(height: 2),
                      hint,
                    ],
                  );
                }
                return Row(
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label,
                          const SizedBox(height: 2),
                          value,
                          hint,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MainCentrePanel extends StatelessWidget {
  static const _folderPageSize = 10;
  static const _requestPageSize = 15;

  const _MainCentrePanel({
    required this.language,
    required this.searchController,
    required this.onSearchChanged,
    required this.newestFirst,
    required this.onSortChanged,
    required this.view,
    required this.onViewChanged,
    required this.filtersExpanded,
    required this.onFiltersExpandedChanged,
    required this.activeFilterCount,
    required this.filter,
    required this.folders,
    required this.requests,
    this.serverTotalItems,
    this.serverPageMode = false,
    required this.expandedProjectIds,
    required this.onProjectExpanded,
    required this.page,
    required this.onPageChanged,
    required this.onOpen,
  });

  final AppLanguage language;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool newestFirst;
  final ValueChanged<bool> onSortChanged;
  final _MaterialRequestCentreView view;
  final ValueChanged<_MaterialRequestCentreView> onViewChanged;
  final bool filtersExpanded;
  final ValueChanged<bool> onFiltersExpandedChanged;
  final int activeFilterCount;
  final Widget filter;
  final List<_ProjectRequestFolder> folders;
  final List<YorksV1MaterialRequest> requests;
  final int? serverTotalItems;
  final bool serverPageMode;
  final Set<String> expandedProjectIds;
  final ValueChanged<String> onProjectExpanded;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final showProjects = view == _MaterialRequestCentreView.projects;
    final totalItems = showProjects
        ? folders.length
        : (serverTotalItems ?? requests.length);
    final pageSize = showProjects ? _folderPageSize : _requestPageSize;
    final pageCount = totalItems == 0
        ? 1
        : (totalItems + pageSize - 1) ~/ pageSize;
    final currentPage = page.clamp(0, pageCount - 1);
    final start = serverPageMode ? 0 : currentPage * pageSize;
    final availableItems = showProjects ? folders.length : requests.length;
    final end = (start + pageSize).clamp(0, availableItems);
    final pageFolders = showProjects
        ? folders.sublist(start, end)
        : const <_ProjectRequestFolder>[];
    final pageRequests = showProjects
        ? const <YorksV1MaterialRequest>[]
        : requests.sublist(start, end);

    return LedgerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 820;
                final search = TextField(
                  key: const ValueKey('material-request-centre-search'),
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: YorksV1MaterialRequestStrings.searchRequests
                        .active(language),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: YorksV1MaterialRequestStrings.clearAll
                                .active(language),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          ),
                  ),
                );
                final sort = _SortControl(
                  language: language,
                  newestFirst: newestFirst,
                  onChanged: onSortChanged,
                );
                final viewSwitcher = _CentreViewSwitcher(
                  language: language,
                  selected: view,
                  onChanged: onViewChanged,
                );
                final filterButton = _FilterButton(
                  language: language,
                  compact: compact,
                  expanded: filtersExpanded,
                  count: activeFilterCount,
                  onPressed: () => onFiltersExpandedChanged(!filtersExpanded),
                );
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    sort,
                    const SizedBox(width: AppSpacing.xs),
                    viewSwitcher,
                    const SizedBox(width: AppSpacing.xs),
                    filterButton,
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [viewSwitcher, const Spacer(), filterButton],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(alignment: Alignment.centerLeft, child: sort),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: AppSpacing.md),
                    controls,
                  ],
                );
              },
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: filtersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: filter,
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: totalItems == 0
                ? _NoMatchingRequests(language: language)
                : showProjects
                ? _ProjectFolderResults(
                    folders: pageFolders,
                    language: language,
                    expandedProjectIds: expandedProjectIds,
                    onProjectExpanded: onProjectExpanded,
                    onOpen: onOpen,
                  )
                : _RequestResults(
                    requests: pageRequests,
                    language: language,
                    onOpen: onOpen,
                  ),
          ),
          if (totalItems > 0)
            _Pagination(
              language: language,
              currentPage: currentPage,
              pageCount: pageCount,
              totalItems: totalItems,
              pageSize: pageSize,
              onChanged: onPageChanged,
            ),
        ],
      ),
    );
  }
}

class _CentreViewSwitcher extends StatelessWidget {
  const _CentreViewSwitcher({
    required this.language,
    required this.selected,
    required this.onChanged,
  });

  final AppLanguage language;
  final _MaterialRequestCentreView selected;
  final ValueChanged<_MaterialRequestCentreView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSpacing.minTapTarget,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CentreViewOption(
          key: const ValueKey('material-request-centre-view-all'),
          icon: Icons.view_list_rounded,
          label: YorksV1MaterialRequestStrings.allRequests.active(language),
          selected: selected == _MaterialRequestCentreView.allRequests,
          onPressed: () => onChanged(_MaterialRequestCentreView.allRequests),
        ),
        _CentreViewOption(
          key: const ValueKey('material-request-centre-view-projects'),
          icon: Icons.folder_outlined,
          label: YorksV1MaterialRequestStrings.projects.active(language),
          selected: selected == _MaterialRequestCentreView.projects,
          onPressed: () => onChanged(_MaterialRequestCentreView.projects),
        ),
      ],
    ),
  );
}

class _CentreViewOption extends StatelessWidget {
  const _CentreViewOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.surfaceContainerLowest : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget - 8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.blue : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: selected ? AppColors.blue : AppColors.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SortControl extends StatelessWidget {
  const _SortControl({
    required this.language,
    required this.newestFirst,
    required this.onChanged,
  });

  final AppLanguage language;
  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSpacing.minTapTarget,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<bool>(
        value: newestFirst,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        items: [
          DropdownMenuItem(
            value: true,
            child: Text(
              YorksV1MaterialRequestStrings.latestActivity.active(language),
            ),
          ),
          DropdownMenuItem(
            value: false,
            child: Text(
              YorksV1MaterialRequestStrings.oldestActivity.active(language),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.language,
    required this.compact,
    required this.expanded,
    required this.count,
    required this.onPressed,
  });

  final AppLanguage language;
  final bool compact;
  final bool expanded;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: YorksV1MaterialRequestStrings.filters.active(language),
        child: Stack(
          key: const ValueKey('material-request-centre-filter-button'),
          clipBehavior: Clip.none,
          children: [
            _ViewModeButton(
              tooltip: YorksV1MaterialRequestStrings.filters.active(language),
              selected: expanded || count > 0,
              icon: expanded
                  ? Icons.filter_alt_off_outlined
                  : Icons.filter_alt_outlined,
              onPressed: onPressed,
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      expanded: expanded,
      child: SizedBox(
        height: AppSpacing.minTapTarget,
        child: OutlinedButton.icon(
          key: const ValueKey('material-request-centre-filter-button'),
          onPressed: onPressed,
          icon: Icon(
            expanded
                ? Icons.filter_alt_off_outlined
                : Icons.filter_alt_outlined,
            size: 19,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              YorksV1ActiveText(
                copy: YorksV1MaterialRequestStrings.filters,
                language: language,
                style: AppTypography.labelLarge.copyWith(color: AppColors.blue),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: selected
          ? AppColors.blueContainer
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: SizedBox.square(
          dimension: AppSpacing.minTapTarget,
          child: Icon(
            icon,
            size: 19,
            color: selected ? AppColors.blue : AppColors.muted,
          ),
        ),
      ),
    ),
  );
}

class _ProjectFolderResults extends StatelessWidget {
  const _ProjectFolderResults({
    required this.folders,
    required this.language,
    required this.expandedProjectIds,
    required this.onProjectExpanded,
    required this.onOpen,
  });

  final List<_ProjectRequestFolder> folders;
  final AppLanguage language;
  final Set<String> expandedProjectIds;
  final ValueChanged<String> onProjectExpanded;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < folders.length; index++) ...[
        _ExpandableProjectFolder(
          folder: folders[index],
          language: language,
          expanded: expandedProjectIds.contains(folders[index].id),
          onExpanded: () => onProjectExpanded(folders[index].id),
          onOpen: onOpen,
        ),
        if (index != folders.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _ExpandableProjectFolder extends StatelessWidget {
  const _ExpandableProjectFolder({
    required this.folder,
    required this.language,
    required this.expanded,
    required this.onExpanded,
    required this.onOpen,
  });

  final _ProjectRequestFolder folder;
  final AppLanguage language;
  final bool expanded;
  final VoidCallback onExpanded;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(
        color: expanded
            ? AppColors.blue.withValues(alpha: 0.35)
            : AppColors.line,
      ),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Material(
          color: expanded
              ? AppColors.blueContainer.withValues(alpha: 0.35)
              : Colors.transparent,
          child: InkWell(
            key: ValueKey('material-request-project-${folder.id}'),
            onTap: onExpanded,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth >= 760;
                  final summary = _FolderSummary(
                    folder: folder,
                    language: language,
                  );
                  final latest = _FolderLatest(
                    folder: folder,
                    language: language,
                  );
                  final identity = _FolderIdentity(
                    folder: folder,
                    language: language,
                    expanded: expanded,
                  );
                  if (!horizontal) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: AppSpacing.sm),
                        _FolderCountBadge(count: folder.requests.length),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          key: ValueKey(
                            'material-request-project-arrow-${folder.id}',
                          ),
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.muted,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 5, child: identity),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 3, child: summary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 3, child: latest),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        key: ValueKey(
                          'material-request-project-arrow-${folder.id}',
                        ),
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: expanded
              ? Container(
                  key: ValueKey(
                    'material-request-project-contents-${folder.id}',
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < folder.requests.length;
                        index++
                      ) ...[
                        _ExplorerRequestRow(
                          request: folder.requests[index],
                          language: language,
                          onOpen: onOpen,
                        ),
                        if (index != folder.requests.length - 1)
                          const Divider(height: 1, color: AppColors.line),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

class _FolderCountBadge extends StatelessWidget {
  const _FolderCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.neutralContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text('$count', style: AppTypography.labelLarge),
  );
}

class _ExplorerRequestRow extends StatelessWidget {
  const _ExplorerRequestRow({
    required this.request,
    required this.language,
    required this.onOpen,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('material-request-row-${request.id}'),
      onTap: () => onOpen(request),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blueContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.requestNumber ?? YorksV1MaterialRequestStrings.draft.active(language)} · ${request.title?.trim().isNotEmpty == true ? request.title! : request.scopeName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.scopeName} · ${YorksV1MaterialRequestStrings.itemsCount(request.displayItemCount).active(language)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CentreStatePill(request: request, language: language),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FolderIdentity extends StatelessWidget {
  const _FolderIdentity({
    required this.folder,
    required this.language,
    required this.expanded,
  });

  final _ProjectRequestFolder folder;
  final AppLanguage language;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.warningContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(
          expanded ? Icons.folder_open_rounded : Icons.folder_rounded,
          color: AppColors.warning,
          size: 23,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folder.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLarge.copyWith(color: AppColors.blue),
            ),
            const SizedBox(height: 2),
            Text(
              folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            YorksV1ActiveText(
              copy: YorksV1MaterialRequestStrings.scopesCount(
                folder.scopeCount,
              ),
              language: language,
              style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _FolderSummary extends StatelessWidget {
  const _FolderSummary({required this.folder, required this.language});

  final _ProjectRequestFolder folder;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _FolderNumber(
          label: YorksV1MaterialRequestStrings.totalRequests,
          value: folder.requests.length,
          language: language,
        ),
      ),
      const VerticalDivider(width: AppSpacing.md, color: AppColors.line),
      Expanded(
        child: _FolderNumber(
          label: YorksV1MaterialRequestStrings.active,
          value: folder.active,
          language: language,
          color: AppColors.success,
        ),
      ),
      const VerticalDivider(width: AppSpacing.md, color: AppColors.line),
      Expanded(
        child: _FolderNumber(
          label: YorksV1MaterialRequestStrings.closedMetric,
          value: folder.closed,
          language: language,
        ),
      ),
    ],
  );
}

class _FolderNumber extends StatelessWidget {
  const _FolderNumber({
    required this.label,
    required this.value,
    required this.language,
    this.color = AppColors.ink,
  });

  final TranslatableString label;
  final int value;
  final AppLanguage language;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      YorksV1ActiveText(
        copy: label,
        language: language,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 4),
      Text('$value', style: AppTypography.titleMedium.copyWith(color: color)),
    ],
  );
}

class _FolderLatest extends StatelessWidget {
  const _FolderLatest({required this.folder, required this.language});

  final _ProjectRequestFolder folder;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final request = folder.latest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YorksV1ActiveText(
          copy: YorksV1MaterialRequestStrings.latestRequest,
          language: language,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 3),
        Text(
          request.requestNumber ??
              YorksV1MaterialRequestStrings.draft.active(language),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLarge.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: 2),
        Text(
          request.title?.trim().isNotEmpty == true
              ? request.title!
              : request.scopeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 5),
        _CentreStatePill(request: request, language: language),
      ],
    );
  }
}

class _RequestResults extends StatelessWidget {
  const _RequestResults({
    required this.requests,
    required this.language,
    required this.onOpen,
  });

  final List<YorksV1MaterialRequest> requests;
  final AppLanguage language;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < requests.length; index++) ...[
        _RequestCentreRow(
          request: requests[index],
          language: language,
          onOpen: onOpen,
        ),
        if (index != requests.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _RequestCentreRow extends StatelessWidget {
  const _RequestCentreRow({
    required this.request,
    required this.language,
    required this.onOpen,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    child: InkWell(
      key: ValueKey('material-request-row-${request.id}'),
      onTap: () => onOpen(request),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final identity = Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blueContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.blue,
              ),
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.requestNumber ??
                      YorksV1MaterialRequestStrings.draft.active(language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.projectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.projectReference} · ${request.scopeName} · ${YorksV1MaterialRequestStrings.itemsCount(request.displayItemCount).active(language)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            );
            final state = _CentreStatePill(
              request: request,
              language: language,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: details),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.minTapTarget + AppSpacing.sm,
                    ),
                    child: Align(alignment: Alignment.centerLeft, child: state),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                identity,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 144,
                  child: Align(alignment: Alignment.centerLeft, child: state),
                ),
                const SizedBox(width: AppSpacing.xs),
                const SizedBox(
                  width: AppSpacing.minTapTarget,
                  height: AppSpacing.minTapTarget,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _CentreStatePill extends StatelessWidget {
  const _CentreStatePill({required this.request, required this.language});

  final YorksV1MaterialRequest request;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (request.state) {
      YorksV1MaterialRequestState.cancelled => (
        AppColors.errorContainer,
        AppColors.onErrorContainer,
      ),
      YorksV1MaterialRequestState.awaitingRequestApproval ||
      YorksV1MaterialRequestState.changesRequested ||
      YorksV1MaterialRequestState.awaitingApproval => (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      YorksV1MaterialRequestState.approvedForArrangement ||
      YorksV1MaterialRequestState.arranging => (
        AppColors.purpleContainer,
        AppColors.onTertiaryContainer,
      ),
      YorksV1MaterialRequestState.received ||
      YorksV1MaterialRequestState.closed => (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      _ => (AppColors.blueContainer, AppColors.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        yorksV1MaterialRequestStateCopy(request.state).active(language),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelLarge.copyWith(color: foreground),
      ),
    );
  }
}

class _NoMatchingRequests extends StatelessWidget {
  const _NoMatchingRequests({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
    child: Column(
      children: [
        const Icon(Icons.search_off_rounded, size: 36, color: AppColors.muted),
        const SizedBox(height: AppSpacing.sm),
        YorksV1ActiveText(
          copy: YorksV1MaterialRequestStrings.noMatchingRequests,
          language: language,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.language,
    required this.currentPage,
    required this.pageCount,
    required this.totalItems,
    required this.pageSize,
    required this.onChanged,
  });

  final AppLanguage language;
  final int currentPage;
  final int pageCount;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.md,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${currentPage * pageSize + 1}–${((currentPage + 1) * pageSize).clamp(0, totalItems)} / $totalItems',
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ),
        IconButton(
          key: const ValueKey('material-request-centre-page-previous'),
          tooltip: MaterialLocalizations.of(context).previousPageTooltip,
          onPressed: currentPage == 0 ? null : () => onChanged(currentPage - 1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          '${currentPage + 1} / $pageCount',
          style: AppTypography.labelLarge,
        ),
        IconButton(
          key: const ValueKey('material-request-centre-page-next'),
          tooltip: MaterialLocalizations.of(context).nextPageTooltip,
          onPressed: currentPage >= pageCount - 1
              ? null
              : () => onChanged(currentPage + 1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _FilterForm extends StatelessWidget {
  const _FilterForm({
    required this.language,
    required this.status,
    required this.project,
    required this.scope,
    required this.requester,
    required this.dateRange,
    required this.attentionOnly,
    required this.requests,
    required this.onStatusChanged,
    required this.onProjectChanged,
    required this.onScopeChanged,
    required this.onRequesterChanged,
    required this.onDateRangeChanged,
    required this.onAttentionOnlyChanged,
    required this.onClear,
    required this.onApply,
    this.fixedProjectId,
  });

  final AppLanguage language;
  final String status;
  final String project;
  final String scope;
  final String requester;
  final _MaterialRequestCentreDateRange dateRange;
  final bool attentionOnly;
  final List<YorksV1MaterialRequest> requests;
  final String? fixedProjectId;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onProjectChanged;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onRequesterChanged;
  final ValueChanged<_MaterialRequestCentreDateRange> onDateRangeChanged;
  final ValueChanged<bool> onAttentionOnlyChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final projects = <String, YorksV1MaterialRequest>{
      for (final request in requests) request.projectId: request,
    };
    final scopes = <String, YorksV1MaterialRequest>{
      for (final request in requests) request.scopeId: request,
    };
    final requesters =
        requests
            .map((request) => request.requesterDisplayName)
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final states = YorksV1MaterialRequestState.values;
    final fields = <Widget>[
      _FilterDropdown<String>(
        label: YorksV1MaterialRequestStrings.requestStatus,
        value: status,
        language: language,
        onChanged: onStatusChanged,
        entries: [
          _FilterEntry(
            '__all__',
            YorksV1MaterialRequestStrings.allStatuses.active(language),
          ),
          for (final state in states)
            _FilterEntry(
              state.wireValue,
              yorksV1MaterialRequestStateCopy(state).active(language),
            ),
        ],
      ),
      if (fixedProjectId == null || fixedProjectId!.isEmpty)
        _FilterDropdown<String>(
          label: YorksV1MaterialRequestStrings.project,
          value: project,
          language: language,
          onChanged: onProjectChanged,
          entries: [
            _FilterEntry(
              '__all__',
              YorksV1MaterialRequestStrings.allProjects.active(language),
            ),
            for (final entry in projects.entries)
              _FilterEntry(
                entry.key,
                '${entry.value.projectReference} · ${entry.value.projectName}',
              ),
          ],
        ),
      _FilterDropdown<String>(
        label: YorksV1MaterialRequestStrings.scope,
        value: scope,
        language: language,
        onChanged: onScopeChanged,
        entries: [
          _FilterEntry(
            '__all__',
            YorksV1MaterialRequestStrings.allBuildings.active(language),
          ),
          for (final entry in scopes.entries)
            _FilterEntry(entry.key, entry.value.scopeName),
        ],
      ),
      _FilterDropdown<String>(
        label: YorksV1MaterialRequestStrings.requestedBy,
        value: requester,
        language: language,
        onChanged: onRequesterChanged,
        entries: [
          _FilterEntry(
            '__all__',
            YorksV1MaterialRequestStrings.allUsers.active(language),
          ),
          for (final name in requesters) _FilterEntry(name, name),
        ],
      ),
      _FilterDropdown<_MaterialRequestCentreDateRange>(
        label: YorksV1MaterialRequestStrings.dateRange,
        value: dateRange,
        language: language,
        onChanged: onDateRangeChanged,
        entries: [
          _FilterEntry(
            _MaterialRequestCentreDateRange.allTime,
            YorksV1MaterialRequestStrings.allTime.active(language),
          ),
          _FilterEntry(
            _MaterialRequestCentreDateRange.sevenDays,
            YorksV1MaterialRequestStrings.last7Days.active(language),
          ),
          _FilterEntry(
            _MaterialRequestCentreDateRange.thirtyDays,
            YorksV1MaterialRequestStrings.last30Days.active(language),
          ),
        ],
      ),
      Material(
        color: attentionOnly
            ? AppColors.warningContainer.withValues(alpha: 0.45)
            : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile.adaptive(
          key: const ValueKey('material-request-filter-attention'),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          value: attentionOnly,
          onChanged: onAttentionOnlyChanged,
          title: YorksV1ActiveText(
            copy: YorksV1MaterialRequestStrings.attentionRequired,
            language: language,
            style: AppTypography.labelLarge.copyWith(color: AppColors.ink),
          ),
          subtitle: YorksV1ActiveText(
            copy: YorksV1MaterialRequestStrings.requiresActionOnly,
            language: language,
            style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
          ),
        ),
      ),
    ];

    return LedgerCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.blue, size: 19),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: YorksV1ActiveText(
                  copy: YorksV1MaterialRequestStrings.filters,
                  language: language,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('material-request-centre-clear-filters'),
                onPressed: onClear,
                child: YorksV1ActiveText(
                  copy: YorksV1MaterialRequestStrings.clearAll,
                  language: language,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final fieldWidth = columns == 2
                  ? (constraints.maxWidth - AppSpacing.sm) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final field in fields)
                    SizedBox(width: fieldWidth, child: field),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: 190,
              height: AppSpacing.minTapTarget,
              child: FilledButton(
                key: const ValueKey('material-request-centre-apply-filters'),
                onPressed: onApply,
                child: YorksV1ActiveText(
                  copy: YorksV1MaterialRequestStrings.applyFilters,
                  language: language,
                  style: AppTypography.titleSmall.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterEntry<T> {
  const _FilterEntry(this.value, this.label);

  final T value;
  final String label;
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.language,
    required this.entries,
    required this.onChanged,
  });

  final TranslatableString label;
  final T value;
  final AppLanguage language;
  final List<_FilterEntry<T>> entries;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey('material-request-filter-${label.primary}-$value'),
    initialValue: entries.any((entry) => entry.value == value)
        ? value
        : entries.first.value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label.active(language)),
    items: [
      for (final entry in entries)
        DropdownMenuItem(
          value: entry.value,
          child: Text(entry.label, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}
