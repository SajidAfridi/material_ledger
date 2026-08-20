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
    required this.onOpenProject,
    required this.onRefresh,
    this.localDraftNotice,
    this.fixedProjectId,
  });

  final List<YorksV1MaterialRequest> requests;
  final AppLanguage language;
  final bool canCreate;
  final VoidCallback onCreate;
  final ValueChanged<YorksV1MaterialRequest> onOpen;
  final ValueChanged<String> onOpenProject;
  final VoidCallback onRefresh;
  final Widget? localDraftNotice;
  final String? fixedProjectId;

  @override
  State<YorksV1MaterialRequestCentre> createState() =>
      _YorksV1MaterialRequestCentreState();
}

enum _MaterialRequestCentreTab {
  projectFolders,
  allRequests,
  attention,
  archive,
}

enum _MaterialRequestCentreDateRange { allTime, sevenDays, thirtyDays }

class _YorksV1MaterialRequestCentreState
    extends State<YorksV1MaterialRequestCentre> {
  static const _allSelection = '__all__';
  final _searchController = TextEditingController();
  _MaterialRequestCentreTab _tab = _MaterialRequestCentreTab.allRequests;
  _MaterialRequestCentreDateRange _dateRange =
      _MaterialRequestCentreDateRange.allTime;
  String _status = _allSelection;
  String _project = _allSelection;
  String _scope = _allSelection;
  String _requester = _allSelection;
  bool _newestFirst = true;
  bool _folderGrid = false;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(VoidCallback update) => setState(() {
    update();
    _page = 0;
  });

  void _clearFilters() => _update(() {
    _searchController.clear();
    _status = _allSelection;
    _project = _allSelection;
    _scope = _allSelection;
    _requester = _allSelection;
    _dateRange = _MaterialRequestCentreDateRange.allTime;
  });

  @override
  Widget build(BuildContext context) {
    final visible = _visibleRequests();
    final folders = _foldersFor(visible);
    final metrics = _MaterialRequestCentreMetrics.fromRequests(widget.requests);
    final isWide =
        MediaQuery.sizeOf(context).width >= AppSpacing.wideBreakpoint;
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
          onRefresh: widget.onRefresh,
        ),
        if (widget.localDraftNotice != null) ...[
          const SizedBox(height: AppSpacing.md),
          widget.localDraftNotice!,
        ],
        const SizedBox(height: AppSpacing.xl),
        _MetricsGrid(metrics: metrics, language: widget.language),
        const SizedBox(height: AppSpacing.lg),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MainCentrePanel(
                  language: widget.language,
                  tab: _tab,
                  onTabChanged: (value) => _update(() => _tab = value),
                  searchController: _searchController,
                  onSearchChanged: (_) => _update(() {}),
                  newestFirst: _newestFirst,
                  onSortChanged: (value) => _update(() => _newestFirst = value),
                  folderGrid: _folderGrid,
                  onFolderGridChanged: (value) =>
                      _update(() => _folderGrid = value),
                  folders: folders,
                  requests: visible,
                  page: _page,
                  onPageChanged: (value) => setState(() => _page = value),
                  onOpen: widget.onOpen,
                  onOpenProject: widget.onOpenProject,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    _FilterCard(
                      language: widget.language,
                      status: _status,
                      project: _project,
                      scope: _scope,
                      requester: _requester,
                      dateRange: _dateRange,
                      requests: widget.requests,
                      fixedProjectId: widget.fixedProjectId,
                      onStatusChanged: (value) =>
                          _update(() => _status = value),
                      onProjectChanged: (value) =>
                          _update(() => _project = value),
                      onScopeChanged: (value) => _update(() => _scope = value),
                      onRequesterChanged: (value) =>
                          _update(() => _requester = value),
                      onDateRangeChanged: (value) =>
                          _update(() => _dateRange = value),
                      onClear: _clearFilters,
                      onApply: () => _update(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RecentActivityCard(
                      requests: visible,
                      language: widget.language,
                      onOpen: widget.onOpen,
                    ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _FilterCard(
            language: widget.language,
            status: _status,
            project: _project,
            scope: _scope,
            requester: _requester,
            dateRange: _dateRange,
            requests: widget.requests,
            fixedProjectId: widget.fixedProjectId,
            collapsible: true,
            onStatusChanged: (value) => _update(() => _status = value),
            onProjectChanged: (value) => _update(() => _project = value),
            onScopeChanged: (value) => _update(() => _scope = value),
            onRequesterChanged: (value) => _update(() => _requester = value),
            onDateRangeChanged: (value) => _update(() => _dateRange = value),
            onClear: _clearFilters,
            onApply: () => _update(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          _MainCentrePanel(
            language: widget.language,
            tab: _tab,
            onTabChanged: (value) => _update(() => _tab = value),
            searchController: _searchController,
            onSearchChanged: (_) => _update(() {}),
            newestFirst: _newestFirst,
            onSortChanged: (value) => _update(() => _newestFirst = value),
            folderGrid: _folderGrid,
            onFolderGridChanged: (value) => _update(() => _folderGrid = value),
            folders: folders,
            requests: visible,
            page: _page,
            onPageChanged: (value) => setState(() => _page = value),
            onOpen: widget.onOpen,
            onOpenProject: widget.onOpenProject,
          ),
          const SizedBox(height: AppSpacing.md),
          _RecentActivityCard(
            requests: visible,
            language: widget.language,
            onOpen: widget.onOpen,
          ),
        ],
      ],
    );
  }

  List<YorksV1MaterialRequest> _visibleRequests() {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    final source =
        widget.requests
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
            .where((request) {
              return switch (_tab) {
                _MaterialRequestCentreTab.projectFolders ||
                _MaterialRequestCentreTab.allRequests => true,
                _MaterialRequestCentreTab.attention => _requiresAttention(
                  request,
                ),
                _MaterialRequestCentreTab.archive => _isArchived(request),
              };
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

class _MaterialRequestCentreMetrics {
  const _MaterialRequestCentreMetrics({
    required this.total,
    required this.active,
    required this.awaitingApproval,
    required this.procurement,
    required this.dispatched,
    required this.received,
    required this.closed,
  });

  final int total;
  final int active;
  final int awaitingApproval;
  final int procurement;
  final int dispatched;
  final int received;
  final int closed;

  factory _MaterialRequestCentreMetrics.fromRequests(
    List<YorksV1MaterialRequest> requests,
  ) => _MaterialRequestCentreMetrics(
    total: requests.length,
    active: requests.where(_isActive).length,
    awaitingApproval: requests
        .where(
          (request) =>
              request.state ==
                  YorksV1MaterialRequestState.awaitingRequestApproval ||
              request.state == YorksV1MaterialRequestState.changesRequested ||
              request.state == YorksV1MaterialRequestState.awaitingApproval,
        )
        .length,
    procurement: requests
        .where(
          (request) =>
              request.state ==
                  YorksV1MaterialRequestState.approvedForArrangement ||
              request.state == YorksV1MaterialRequestState.arranging,
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
}

class _ProjectRequestFolder {
  const _ProjectRequestFolder({required this.requests});

  final List<YorksV1MaterialRequest> requests;

  YorksV1MaterialRequest get latest => requests.first;
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

List<_ProjectRequestFolder> _foldersFor(List<YorksV1MaterialRequest> requests) {
  final grouped = <String, List<YorksV1MaterialRequest>>{};
  for (final request in requests) {
    (grouped[request.projectId] ??= []).add(request);
  }
  return grouped.values
      .map((requests) {
        requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return _ProjectRequestFolder(requests: List.unmodifiable(requests));
      })
      .toList(growable: false)
    ..sort((a, b) => b.latest.updatedAt.compareTo(a.latest.updatedAt));
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
  const _MetricsGrid({required this.metrics, required this.language});

  final _MaterialRequestCentreMetrics metrics;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= AppSpacing.wideBreakpoint
          ? 4
          : width >= AppSpacing.compactBreakpoint
          ? 3
          : 2;
      const gap = AppSpacing.sm;
      final cardWidth = (width - (columns - 1) * gap) / columns;
      final tiles = [
        _MetricData(
          YorksV1MaterialRequestStrings.totalRequests,
          YorksV1MaterialRequestStrings.allTime,
          metrics.total,
          Icons.description_outlined,
          AppColors.blue,
          AppColors.blueContainer,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.activeRequests,
          YorksV1MaterialRequestStrings.active,
          metrics.active,
          Icons.assignment_turned_in_outlined,
          AppColors.success,
          AppColors.successContainer,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.awaitingApprovalMetric,
          YorksV1MaterialRequestStrings.attentionRequired,
          metrics.awaitingApproval,
          Icons.schedule_rounded,
          AppColors.warning,
          AppColors.warningContainer,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.procurementQueue,
          YorksV1MaterialRequestStrings.inArrangement,
          metrics.procurement,
          Icons.shopping_cart_outlined,
          AppColors.purple,
          AppColors.purpleContainer,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.dispatchedMetric,
          YorksV1MaterialRequestStrings.onTheWay,
          metrics.dispatched,
          Icons.local_shipping_outlined,
          AppColors.blue,
          AppColors.blueContainer,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.receivedMetric,
          YorksV1MaterialRequestStrings.atSiteOrWarehouse,
          metrics.received,
          Icons.inventory_2_outlined,
          AppColors.success,
          AppColors.successContainer,
        ),
        _MetricData(
          YorksV1MaterialRequestStrings.closedMetric,
          YorksV1MaterialRequestStrings.completed,
          metrics.closed,
          Icons.archive_outlined,
          AppColors.neutralText,
          AppColors.neutralContainer,
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
              child: _MetricCard(data: tile, language: language),
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
  );

  final TranslatableString label;
  final TranslatableString hint;
  final int value;
  final IconData icon;
  final Color foreground;
  final Color background;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data, required this.language});

  final _MetricData data;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => LedgerCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: data.background,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(data.icon, color: data.foreground, size: 21),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YorksV1ActiveText(
                copy: data.label,
                language: language,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.value}',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              YorksV1ActiveText(
                copy: data.hint,
                language: language,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MainCentrePanel extends StatelessWidget {
  static const _folderPageSize = 10;
  static const _requestPageSize = 15;

  const _MainCentrePanel({
    required this.language,
    required this.tab,
    required this.onTabChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.newestFirst,
    required this.onSortChanged,
    required this.folderGrid,
    required this.onFolderGridChanged,
    required this.folders,
    required this.requests,
    required this.page,
    required this.onPageChanged,
    required this.onOpen,
    required this.onOpenProject,
  });

  final AppLanguage language;
  final _MaterialRequestCentreTab tab;
  final ValueChanged<_MaterialRequestCentreTab> onTabChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool newestFirst;
  final ValueChanged<bool> onSortChanged;
  final bool folderGrid;
  final ValueChanged<bool> onFolderGridChanged;
  final List<_ProjectRequestFolder> folders;
  final List<YorksV1MaterialRequest> requests;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<YorksV1MaterialRequest> onOpen;
  final ValueChanged<String> onOpenProject;

  @override
  Widget build(BuildContext context) {
    final isFolderTab = tab == _MaterialRequestCentreTab.projectFolders;
    final totalItems = isFolderTab ? folders.length : requests.length;
    final pageSize = isFolderTab ? _folderPageSize : _requestPageSize;
    final pageCount = totalItems == 0
        ? 1
        : (totalItems + pageSize - 1) ~/ pageSize;
    final currentPage = page.clamp(0, pageCount - 1);
    final start = currentPage * pageSize;
    final end = (start + pageSize).clamp(0, totalItems);
    final pageFolders = isFolderTab
        ? folders.sublist(start, end)
        : const <_ProjectRequestFolder>[];
    final pageRequests = isFolderTab
        ? const <YorksV1MaterialRequest>[]
        : requests.sublist(start, end);

    return LedgerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CentreTabs(
            language: language,
            selected: tab,
            attentionCount: requests.where(_requiresAttention).length,
            onChanged: onTabChanged,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 630;
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
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<bool>(
                        value: newestFirst,
                        onChanged: (value) {
                          if (value != null) onSortChanged(value);
                        },
                        items: [
                          DropdownMenuItem(
                            value: true,
                            child: Text(
                              YorksV1MaterialRequestStrings.latestActivity
                                  .active(language),
                            ),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text(
                              YorksV1MaterialRequestStrings.oldestActivity
                                  .active(language),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFolderTab) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _ViewModeButton(
                        tooltip: YorksV1MaterialRequestStrings.gridView.active(
                          language,
                        ),
                        selected: folderGrid,
                        icon: Icons.grid_view_rounded,
                        onPressed: () => onFolderGridChanged(true),
                      ),
                      _ViewModeButton(
                        tooltip: YorksV1MaterialRequestStrings.listView.active(
                          language,
                        ),
                        selected: !folderGrid,
                        icon: Icons.view_list_rounded,
                        onPressed: () => onFolderGridChanged(false),
                      ),
                    ],
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: AppSpacing.sm),
                      controls,
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
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: totalItems == 0
                ? _NoMatchingRequests(language: language)
                : isFolderTab
                ? _ProjectFolderResults(
                    folders: pageFolders,
                    grid: folderGrid,
                    language: language,
                    onOpenProject: onOpenProject,
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

class _CentreTabs extends StatelessWidget {
  const _CentreTabs({
    required this.language,
    required this.selected,
    required this.attentionCount,
    required this.onChanged,
  });

  final AppLanguage language;
  final _MaterialRequestCentreTab selected;
  final int attentionCount;
  final ValueChanged<_MaterialRequestCentreTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (
        _MaterialRequestCentreTab.projectFolders,
        YorksV1MaterialRequestStrings.projectFolders,
        Icons.folder_outlined,
      ),
      (
        _MaterialRequestCentreTab.allRequests,
        YorksV1MaterialRequestStrings.allRequests,
        Icons.assignment_outlined,
      ),
      (
        _MaterialRequestCentreTab.attention,
        YorksV1MaterialRequestStrings.attentionRequired,
        Icons.priority_high_rounded,
      ),
      (
        _MaterialRequestCentreTab.archive,
        YorksV1MaterialRequestStrings.closedArchive,
        Icons.archive_outlined,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final tab in tabs)
            _CentreTab(
              label: tab.$2,
              icon: tab.$3,
              language: language,
              selected: selected == tab.$1,
              count: tab.$1 == _MaterialRequestCentreTab.attention
                  ? attentionCount
                  : null,
              onTap: () => onChanged(tab.$1),
            ),
        ],
      ),
    );
  }
}

class _CentreTab extends StatelessWidget {
  const _CentreTab({
    required this.label,
    required this.icon,
    required this.language,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final TranslatableString label;
  final IconData icon;
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label.active(language),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        height: AppSpacing.minTapTarget + 4,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.blue : AppColors.muted,
            ),
            const SizedBox(width: AppSpacing.xs),
            YorksV1ActiveText(
              copy: label,
              language: language,
              style: AppTypography.labelLarge.copyWith(
                color: selected ? AppColors.blue : AppColors.muted,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall.copyWith(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
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
    required this.grid,
    required this.language,
    required this.onOpenProject,
  });

  final List<_ProjectRequestFolder> folders;
  final bool grid;
  final AppLanguage language;
  final ValueChanged<String> onOpenProject;

  @override
  Widget build(BuildContext context) {
    if (!grid) {
      return Column(
        children: [
          for (var index = 0; index < folders.length; index++) ...[
            _ProjectFolderCard(
              folder: folders[index],
              language: language,
              onOpenProject: onOpenProject,
            ),
            if (index != folders.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 720;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final folder in folders)
              SizedBox(
                width: width,
                child: _ProjectFolderCard(
                  folder: folder,
                  language: language,
                  onOpenProject: onOpenProject,
                  compact: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProjectFolderCard extends StatelessWidget {
  const _ProjectFolderCard({
    required this.folder,
    required this.language,
    required this.onOpenProject,
    this.compact = false,
  });

  final _ProjectRequestFolder folder;
  final AppLanguage language;
  final ValueChanged<String> onOpenProject;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    child: InkWell(
      key: ValueKey('material-request-project-${folder.id}'),
      onTap: () => onOpenProject(folder.id),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = !compact && constraints.maxWidth >= 620;
            final summary = _FolderSummary(folder: folder, language: language);
            final latest = _FolderLatest(folder: folder, language: language);
            final identity = _FolderIdentity(
              folder: folder,
              language: language,
            );
            if (!horizontal) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.md),
                  summary,
                  const SizedBox(height: AppSpacing.md),
                  latest,
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
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _FolderIdentity extends StatelessWidget {
  const _FolderIdentity({required this.folder, required this.language});

  final _ProjectRequestFolder folder;
  final AppLanguage language;

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
        child: const Icon(
          Icons.folder_rounded,
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
                  '${request.projectReference} · ${request.scopeName} · ${YorksV1MaterialRequestStrings.itemsCount(request.lines.length).active(language)}',
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
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      state,
                      const SizedBox(height: AppSpacing.xs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                    ],
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

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.language,
    required this.status,
    required this.project,
    required this.scope,
    required this.requester,
    required this.dateRange,
    required this.requests,
    required this.onStatusChanged,
    required this.onProjectChanged,
    required this.onScopeChanged,
    required this.onRequesterChanged,
    required this.onDateRangeChanged,
    required this.onClear,
    required this.onApply,
    this.fixedProjectId,
    this.collapsible = false,
  });

  final AppLanguage language;
  final String status;
  final String project;
  final String scope;
  final String requester;
  final _MaterialRequestCentreDateRange dateRange;
  final List<YorksV1MaterialRequest> requests;
  final String? fixedProjectId;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onProjectChanged;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onRequesterChanged;
  final ValueChanged<_MaterialRequestCentreDateRange> onDateRangeChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final body = _FilterForm(
      language: language,
      status: status,
      project: project,
      scope: scope,
      requester: requester,
      dateRange: dateRange,
      requests: requests,
      fixedProjectId: fixedProjectId,
      onStatusChanged: onStatusChanged,
      onProjectChanged: onProjectChanged,
      onScopeChanged: onScopeChanged,
      onRequesterChanged: onRequesterChanged,
      onDateRangeChanged: onDateRangeChanged,
      onClear: onClear,
      onApply: onApply,
    );
    if (!collapsible) return body;
    return Material(
      color: AppColors.surfaceContainerLowest,
      elevation: 1,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ExpansionTile(
        key: const ValueKey('material-request-centre-filter-expansion'),
        leading: const Icon(Icons.tune_rounded, color: AppColors.blue),
        title: YorksV1ActiveText(
          copy: YorksV1MaterialRequestStrings.filters,
          language: language,
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [body],
      ),
    );
  }
}

class _FilterForm extends StatelessWidget {
  const _FilterForm({
    required this.language,
    required this.status,
    required this.project,
    required this.scope,
    required this.requester,
    required this.dateRange,
    required this.requests,
    required this.onStatusChanged,
    required this.onProjectChanged,
    required this.onScopeChanged,
    required this.onRequesterChanged,
    required this.onDateRangeChanged,
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
  final List<YorksV1MaterialRequest> requests;
  final String? fixedProjectId;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onProjectChanged;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onRequesterChanged;
  final ValueChanged<_MaterialRequestCentreDateRange> onDateRangeChanged;
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
          const SizedBox(height: AppSpacing.sm),
          if (fixedProjectId == null || fixedProjectId!.isEmpty) ...[
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
            const SizedBox(height: AppSpacing.sm),
          ],
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
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          SizedBox(
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

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.requests,
    required this.language,
    required this.onOpen,
  });

  final List<YorksV1MaterialRequest> requests;
  final AppLanguage language;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final recent = [...requests]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return LedgerCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: YorksV1ActiveText(
                  copy: YorksV1MaterialRequestStrings.recentActivity,
                  language: language,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.history_rounded,
                color: AppColors.blue,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (recent.isEmpty)
            YorksV1ActiveText(
              copy: AppStrings.noRecentActivity,
              language: language,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            )
          else
            for (var index = 0; index < recent.take(5).length; index++) ...[
              _ActivityRow(
                request: recent[index],
                language: language,
                onOpen: onOpen,
              ),
              if (index != recent.take(5).length - 1)
                const Divider(height: AppSpacing.md * 2, color: AppColors.line),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.request,
    required this.language,
    required this.onOpen,
  });

  final YorksV1MaterialRequest request;
  final AppLanguage language;
  final ValueChanged<YorksV1MaterialRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final icon = switch (request.state) {
      YorksV1MaterialRequestState.awaitingRequestApproval ||
      YorksV1MaterialRequestState.changesRequested => Icons.schedule_rounded,
      YorksV1MaterialRequestState.approvedForArrangement ||
      YorksV1MaterialRequestState.arranging => Icons.shopping_cart_outlined,
      YorksV1MaterialRequestState.dispatched ||
      YorksV1MaterialRequestState.partiallyDispatched =>
        Icons.local_shipping_outlined,
      YorksV1MaterialRequestState.received ||
      YorksV1MaterialRequestState.partiallyReceived =>
        Icons.inventory_2_outlined,
      YorksV1MaterialRequestState.closed => Icons.archive_outlined,
      _ => Icons.description_outlined,
    };
    return InkWell(
      onTap: () => onOpen(request),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.blueContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: AppColors.blue),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
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
                  const SizedBox(height: 2),
                  Text(
                    yorksV1MaterialRequestStateCopy(
                      request.state,
                    ).active(language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(request.updatedAt.toLocal()),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
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
