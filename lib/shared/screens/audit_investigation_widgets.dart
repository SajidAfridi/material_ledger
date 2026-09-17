part of 'activity_log_screen.dart';

class _InvestigationToolbar extends ConsumerStatefulWidget {
  const _InvestigationToolbar({
    required this.language,
    required this.state,
    required this.onClear,
  });
  final AppLanguage language;
  final YorksV1AuditViewState state;
  final VoidCallback onClear;
  @override
  ConsumerState<_InvestigationToolbar> createState() =>
      _InvestigationToolbarState();
}

class _InvestigationToolbarState extends ConsumerState<_InvestigationToolbar> {
  bool _exporting = false;
  String? _exportId;
  YorksV1AuditFilter? _exportFilter;
  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final state = widget.state;
    final controller = ref.read(yorksV1AuditControllerProvider.notifier);
    final f = state.filter;
    final w = state.workspace!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (MediaQuery.sizeOf(context).width >= 760)
              FilterChip(
                label: Text(
                  YorksV1AuditInvestigationStrings.compact.active(language),
                ),
                selected: ref.watch(_auditCompactRowsProvider),
                onSelected: (value) =>
                    ref.read(_auditCompactRowsProvider.notifier).state = value,
              ),
            for (final quick
                in MediaQuery.sizeOf(context).width < 760
                    ? <YorksV1AuditQuickFilter>[]
                    : YorksV1AuditQuickFilter.values)
              FilterChip(
                label: Text(
                  YorksV1AuditStrings.quickFilter(quick).active(language),
                ),
                selected: f.quickFilter == quick,
                onSelected: (_) => controller.setQuickFilter(
                  f.quickFilter == quick ? null : quick,
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _showFilters(context, ref, state, language),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                YorksV1AuditInvestigationStrings.filters.active(language),
              ),
            ),
            TextButton(
              onPressed: widget.onClear,
              child: Text(
                YorksV1AuditInvestigationStrings.clearAll.active(language),
              ),
            ),
            OutlinedButton.icon(
              onPressed: !state.canExport || _exporting || w.events.isEmpty
                  ? null
                  : _download,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: Text(
                YorksV1AuditInvestigationStrings.download.active(language),
              ),
            ),
          ],
        ),
        if (f.actorId != null ||
            f.projectId != null ||
            f.eventType != null ||
            f.severity != null ||
            f.scope != null)
          Wrap(
            spacing: 6,
            children: [
              for (final text in [
                if (f.actorId != null) _optionLabel(w, 'actors', f.actorId!),
                if (f.projectId != null)
                  _optionLabel(w, 'projects', f.projectId!),
                if (f.eventType != null)
                  YorksV1AuditStrings.eventLabel(f.eventType!, language),
                if (f.severity != null) _severityLabel(f.severity!, language),
                if (f.scope != null) _scopeLabel(f.scope!, language),
              ])
                Chip(label: Text(text)),
              ActionChip(
                label: Text(
                  YorksV1AuditInvestigationStrings.clearAll.active(language),
                ),
                onPressed: () =>
                    controller.applyFilter(f.copyWith(clearAdvanced: true)),
              ),
            ],
          ),
        const Gap(6),
        Text(
          '${YorksV1AuditInvestigationStrings.updated.active(language)}: ${_dateTime(context, w.generatedAt)} · '
          '${YorksV1AuditInvestigationStrings.timezone.active(language)}: ${DateTime.now().timeZoneName}',
          style: AppTypography.bodySmall,
        ),
        if (!state.canExport)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              YorksV1AuditInvestigationStrings.stale.active(language),
              style: AppTypography.bodySmall,
            ),
          ),
        if (!state.canExport && state.loadedFilter != null)
          Text(
            '${YorksV1AuditInvestigationStrings.lastSuccessful.active(language)}: ${_loadedScope(context, state.loadedFilter!, w, language)}',
            style: AppTypography.bodySmall,
          ),
      ],
    );
  }

  Future<void> _download() async {
    final filter = widget.state.loadedFilter!;
    if (!identical(_exportFilter, filter)) {
      _exportFilter = filter;
      _exportId = const Uuid().v4();
    }
    setState(() => _exporting = true);
    try {
      final controller = ref.read(yorksV1AuditControllerProvider.notifier);
      final workspace = await controller.export(_exportId!);
      if (!mounted ||
          !ref.read(yorksV1AuditControllerProvider).canExport ||
          !identical(
            filter,
            ref.read(yorksV1AuditControllerProvider).loadedFilter,
          )) {
        return;
      }
      final name =
          'yorks-audit-${workspace.generatedAt.toUtc().millisecondsSinceEpoch}.csv';
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null ||
          !mounted ||
          !ref.read(yorksV1AuditControllerProvider).canExport ||
          !identical(
            filter,
            ref.read(yorksV1AuditControllerProvider).loadedFilter,
          )) {
        return;
      }
      await XFile.fromData(
        Uint8List.fromList(utf8.encode(yorksV1AuditCsv(workspace, filter))),
        name: name,
        mimeType: 'text/csv',
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              YorksV1AuditInvestigationStrings.exportSaved.active(
                widget.language,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              YorksV1AuditInvestigationStrings.exportFailed.active(
                widget.language,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

String _optionLabel(YorksV1AuditWorkspace w, String kind, String id) =>
    (w.filterOptions[kind] ?? [])
        .where((v) => v['id'] == id)
        .map((v) => v['label'] ?? id)
        .firstOrNull ??
    id;

String _loadedScope(
  BuildContext context,
  YorksV1AuditFilter f,
  YorksV1AuditWorkspace w,
  AppLanguage language,
) {
  final dates = MaterialLocalizations.of(context);
  return [
    f.from == null || f.to == null
        ? YorksV1AuditStrings.allTime.active(language)
        : '${dates.formatShortDate(f.from!)} – ${dates.formatShortDate(f.to!.subtract(const Duration(microseconds: 1)))}',
    if (f.search.isNotEmpty) f.search,
    if (f.module != null)
      YorksV1AuditStrings.module(f.module!).active(language),
    if (f.quickFilter != null)
      YorksV1AuditStrings.quickFilter(f.quickFilter!).active(language),
    if (f.actorId != null) _optionLabel(w, 'actors', f.actorId!),
    if (f.projectId != null) _optionLabel(w, 'projects', f.projectId!),
    if (f.eventType != null)
      YorksV1AuditStrings.eventLabel(f.eventType!, language),
    if (f.severity != null) _severityLabel(f.severity!, language),
    if (f.scope != null) _scopeLabel(f.scope!, language),
  ].join(' · ');
}

String _scopeLabel(String scope, AppLanguage language) => (switch (scope) {
  'company' => YorksV1AuditInvestigationStrings.company,
  'project' => YorksV1AuditInvestigationStrings.project,
  _ => YorksV1AuditInvestigationStrings.organization,
}).active(language);

String _severityLabel(String severity, AppLanguage language) =>
    (switch (severity) {
      'unclassified' => YorksV1AuditInvestigationStrings.unclassified,
      'critical' => YorksV1AuditInvestigationStrings.critical,
      'warning' => YorksV1AuditInvestigationStrings.warning,
      _ => YorksV1AuditInvestigationStrings.normal,
    }).active(language);

Future<void> _showFilters(
  BuildContext context,
  WidgetRef ref,
  YorksV1AuditViewState state,
  AppLanguage language,
) async {
  var actor = state.filter.actorId;
  var project = state.filter.projectId;
  var eventType = state.filter.eventType;
  var severity = state.filter.severity;
  var scope = state.filter.scope;
  var quick = state.filter.quickFilter?.wireValue;
  final owner = ref.read(yorksV1AuditControllerProvider.notifier);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => _AuditAccessBoundary(
        owner: owner,
        child: AlertDialog(
          title: Text(
            YorksV1AuditInvestigationStrings.filters.active(language),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item
                      in <
                        (
                          String,
                          String?,
                          List<Map<String, String>>,
                          void Function(String?),
                        )
                      >[
                        (
                          YorksV1AuditStrings.quickFilters.active(language),
                          quick,
                          [
                            for (final q in YorksV1AuditQuickFilter.values)
                              {
                                'id': q.wireValue,
                                'label': YorksV1AuditStrings.quickFilter(
                                  q,
                                ).active(language),
                              },
                          ],
                          (v) => quick = v,
                        ),
                        (
                          YorksV1AuditInvestigationStrings.actor.active(
                            language,
                          ),
                          actor,
                          state.workspace!.filterOptions['actors'] ?? [],
                          (v) => actor = v,
                        ),
                        (
                          YorksV1AuditInvestigationStrings.project.active(
                            language,
                          ),
                          project,
                          state.workspace!.filterOptions['projects'] ?? [],
                          (v) => project = v,
                        ),
                        (
                          YorksV1AuditInvestigationStrings.eventType.active(
                            language,
                          ),
                          eventType,
                          [
                            for (final o
                                in state.workspace!.filterOptions['events'] ??
                                    <Map<String, String>>[])
                              {
                                'id': o['id']!,
                                'label': YorksV1AuditStrings.eventLabel(
                                  o['id']!,
                                  language,
                                ),
                              },
                          ],
                          (v) => eventType = v,
                        ),
                        (
                          YorksV1AuditInvestigationStrings.severity.active(
                            language,
                          ),
                          severity,
                          [
                            for (final v in [
                              'normal',
                              'warning',
                              'critical',
                              'unclassified',
                            ])
                              {'id': v, 'label': _severityLabel(v, language)},
                          ],
                          (v) => severity = v,
                        ),
                        (
                          YorksV1AuditInvestigationStrings.scope.active(
                            language,
                          ),
                          scope,
                          [
                            for (final v in [
                              'project',
                              'company',
                              'organization',
                            ])
                              {'id': v, 'label': _scopeLabel(v, language)},
                          ],
                          (v) => scope = v,
                        ),
                      ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: item.$2 ?? '',
                        isExpanded: true,
                        decoration: InputDecoration(labelText: item.$1),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(
                              YorksV1AuditInvestigationStrings.all.active(
                                language,
                              ),
                            ),
                          ),
                          for (final option in item.$3)
                            DropdownMenuItem(
                              value: option['id'],
                              child: Text(
                                option['label']!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (item.$2 != null &&
                              !item.$3.any((option) => option['id'] == item.$2))
                            DropdownMenuItem(
                              value: item.$2,
                              child: Text(item.$2!),
                            ),
                        ],
                        onChanged: (v) =>
                            setLocal(() => item.$4(v == '' ? null : v)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                YorksV1AuditInvestigationStrings.apply.active(language),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (accepted == true && context.mounted) {
    ref
        .read(yorksV1AuditControllerProvider.notifier)
        .applyFilter(
          state.filter
              .copyWith(clearAdvanced: true)
              .copyWith(clearQuickFilter: true)
              .copyWith(
                quickFilter: YorksV1AuditQuickFilter.values
                    .where((q) => q.wireValue == quick)
                    .firstOrNull,
                actorId: actor,
                projectId: project,
                eventType: eventType,
                severity: severity,
                scope: scope,
              ),
        );
  }
}

class _AuditAccessBoundary extends ConsumerWidget {
  const _AuditAccessBoundary({required this.owner, required this.child});
  final YorksV1AuditController owner;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(yorksV1AuditControllerProvider);
    if (!identical(owner, ref.watch(yorksV1AuditControllerProvider.notifier)) ||
        state.workspace == null) {
      return AlertDialog(
        content: Text(
          YorksV1AuditInvestigationStrings.denied.active(
            ref.watch(languageProvider),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      );
    }
    return child;
  }
}

Future<void> _showAuditDetails(
  BuildContext context,
  YorksV1AuditEvent event,
) async {
  final destination = await showDialog<String>(
    context: context,
    builder: (context) {
      final mobile = MediaQuery.sizeOf(context).width < 760;
      return Dialog(
        insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(20),
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          width: mobile ? double.infinity : 620,
          child: _AuditDetails(event: event),
        ),
      );
    },
  );
  if (destination != null && context.mounted) await context.push(destination);
}

class _AuditDetails extends ConsumerStatefulWidget {
  const _AuditDetails({required this.event});
  final YorksV1AuditEvent event;
  @override
  ConsumerState<_AuditDetails> createState() => _AuditDetailsState();
}

class _AuditDetailsState extends ConsumerState<_AuditDetails> {
  final List<YorksV1AuditEvent> _events = [];
  YorksV1AuditWorkspace? _history;
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final next = await ref
          .read(yorksV1AuditControllerProvider.notifier)
          .history(
            widget.event,
            page: _history == null
                ? 0
                : _history!.offset ~/ _history!.limit + 1,
            asOf: _history?.asOf,
            after: _events.lastOrNull,
          );
      if (mounted) {
        setState(() {
          _history = next;
          _events.addAll(next.events);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    ref.listen(yorksV1AuthUserIdProvider, (previous, next) {
      if (previous != next && mounted) Navigator.of(context).pop();
    });
    ref.listen(yorksV1CurrentRoleProvider, (previous, next) {
      if (previous != next && mounted) Navigator.of(context).pop();
    });
    final state = ref.watch(yorksV1AuditControllerProvider);
    // The modal must not retain its event or timeline after the parent loses authority.
    if (state.workspace == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(YorksV1AuditInvestigationStrings.denied.active(language)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      );
    }
    final e = widget.event;
    final path = switch (e.entityType) {
      'material_request' => RoutePaths.yorksV1MaterialRequestPath(e.entityId),
      'material_return' => RoutePaths.yorksV1MaterialReturnPath(e.entityId),
      _ => null,
    };
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    YorksV1AuditInvestigationStrings.details.active(language),
                    style: AppTypography.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    YorksV1AuditStrings.eventLabel(e.eventType, language),
                    style: AppTypography.titleLarge,
                  ),
                  const Gap(12),
                  SelectableText(
                    '${e.actorDisplayName} · ${YorksV1AuditStrings.roleLabel(e.actorExactRole, language)}',
                  ),
                  Text(
                    '${YorksV1AuditStrings.module(e.module).active(language)} · ${_severityLabel(e.severity.name, language)}',
                  ),
                  SelectableText(
                    '${e.occurredAt.toUtc().toIso8601String()} (UTC)',
                  ),
                  if (!e.attributionVerified)
                    Text(YorksV1AuditStrings.historicalGap.active(language)),
                  const Gap(12),
                  SelectableText(
                    '${e.reference}\n${e.projectName ?? _scopeLabel(e.scope, language)}',
                  ),
                  if (e.reason != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SelectableText(
                        '${YorksV1AuditInvestigationStrings.reason.active(language)}: ${e.reason}',
                      ),
                    ),
                  if (path != null)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, path),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        YorksV1AuditInvestigationStrings.openRecord.active(
                          language,
                        ),
                      ),
                    ),
                  const Gap(16),
                  Text(
                    YorksV1AuditInvestigationStrings.facts.active(language),
                    style: AppTypography.titleMedium,
                  ),
                  if (e.facts.isEmpty && e.beforeFacts.isEmpty)
                    Text(
                      YorksV1AuditInvestigationStrings.noFacts.active(language),
                    ),
                  for (final key in {...e.beforeFacts.keys, ...e.facts.keys})
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            YorksV1AuditInvestigationStrings.fact(
                              key,
                            ).active(language),
                            style: AppTypography.labelLarge,
                          ),
                          if (e.beforeFacts.containsKey(key))
                            SelectableText(
                              '${YorksV1AuditInvestigationStrings.before.active(language)}: ${e.beforeFacts[key]}',
                            ),
                          if (e.facts.containsKey(key))
                            SelectableText(
                              '${YorksV1AuditInvestigationStrings.after.active(language)}: ${e.facts[key]}',
                            ),
                        ],
                      ),
                    ),
                  const Gap(12),
                  SelectableText(
                    '${YorksV1AuditInvestigationStrings.eventId.active(language)}: ${e.id}',
                    style: AppTypography.bodySmall,
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: e.id)),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(
                      YorksV1AuditInvestigationStrings.copyId.active(language),
                    ),
                  ),
                  const Divider(),
                  Text(
                    YorksV1AuditInvestigationStrings.timeline.active(language),
                    style: AppTypography.titleMedium,
                  ),
                  Text(
                    YorksV1AuditInvestigationStrings.historyHint.active(
                      language,
                    ),
                    style: AppTypography.bodySmall,
                  ),
                  for (final h in _events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        YorksV1AuditStrings.eventLabel(h.eventType, language),
                      ),
                      subtitle: Text(
                        '${h.actorDisplayName} · ${_dateTime(context, h.occurredAt)}${h.reason == null ? '' : '\n${h.reason}'}',
                      ),
                      onTap: () => _showAuditDetails(context, h),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  if (_failed)
                    TextButton(
                      onPressed: _load,
                      child: Text(YorksV1AuditStrings.refresh.active(language)),
                    ),
                  if (!_loading &&
                      !_failed &&
                      _history != null &&
                      _events.length < _history!.filteredCount)
                    TextButton(
                      onPressed: _load,
                      child: Text(
                        YorksV1AuditInvestigationStrings.more.active(language),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
