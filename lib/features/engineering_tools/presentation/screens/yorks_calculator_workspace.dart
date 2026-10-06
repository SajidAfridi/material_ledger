import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/constants.dart';
import '../../../../shared/controllers/yorks_v1_calculator_controller.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_calculator_strings.dart';
import '../../../../shared/models/yorks_v1_calculator_workspace.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_calculator_provider.dart';
import 'yorks_v1_engineering_calculator_screens.dart';

const yorksCalculatorsPath = '/tools/calculators';
typedef S = YorksCalculatorStrings;

class YorksCalculatorWorkspace extends ConsumerWidget {
  const YorksCalculatorWorkspace({super.key, this.recordId, this.initial});
  final String? recordId;
  final Map<String, dynamic>? initial;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(
      yorksCalculatorControllerProvider(recordId ?? 'library'),
    );
    return _Workspace(
      key: ObjectKey(controller),
      controller: controller,
      recordId: recordId,
      initial: initial,
    );
  }
}

class _Workspace extends ConsumerStatefulWidget {
  const _Workspace({
    super.key,
    required this.controller,
    this.recordId,
    this.initial,
  });
  final YorksCalculatorController controller;
  final String? recordId;
  final Map<String, dynamic>? initial;
  @override
  ConsumerState<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<_Workspace> {
  YorksCalculatorController get c => widget.controller;
  final title = TextEditingController();
  YorksCalculatorEditorSession? editor;
  String kind = 'duct', id = '', filter = 'all', scopeFilter = 'all';
  String? projectId, projectName;
  String baseline = '', lastFingerprint = '';
  bool dirty = false, allowPop = false, firstSnapshot = true;
  int editorGeneration = 0;
  Timer? refreshTimer, searchTimer;
  YorksCalculatorExitGuard? exitGuard;
  String t(TranslatableString s) => s.active(ref.read(languageProvider));
  @override
  void initState() {
    super.initState();
    title.addListener(_changed);
    if (widget.recordId != null) {
      exitGuard = ref.read(yorksCalculatorExitGuardProvider);
      exitGuard!.check = _canLeave;
    }
    Future<void>.microtask(_initialize);
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) c.checkAccess();
    });
  }

  Future<void> _initialize() async {
    if (widget.recordId == null) {
      await c.load();
      return;
    }
    final pending = c.recoverPending();
    if (pending != null) {
      if ((pending['expected_version'] as int? ?? 0) > 0) {
        await c.open(pending['id'] as String);
        if (!mounted || c.record == null) return;
      } else {
        await c.load();
        if (!mounted || !c.canCreate) return;
      }
      id = pending['id'] as String;
      kind = pending['kind'] as String;
      projectId = pending['project_id'] as String?;
      title.text = pending['title'] as String;
      _setEditor(
        Map<String, dynamic>.from(pending['payload'] as Map),
        unsaved: true,
      );
      return;
    }
    if (widget.recordId == 'new') {
      await c.load();
      if (!mounted || !c.canCreate) {
        setState(() {});
        return;
      }
      final initial = widget.initial ?? {};
      id = const Uuid().v4();
      kind = initial['kind'] as String? ?? 'duct';
      projectId = initial['project_id'] as String?;
      projectName = initial['project_name'] as String?;
      title.text = initial['title'] as String? ?? '';
      _setEditor(
        Map<String, dynamic>.from(
          initial['payload'] as Map? ?? YorksCalculatorFiles.fresh(kind),
        ),
        unsaved: true,
      );
    } else {
      await c.open(widget.recordId!);
      if (!mounted) return;
      final record = c.record;
      if (record != null) {
        id = record.id;
        kind = record.kind;
        projectId = record.projectId;
        projectName = record.projectName;
        title.text = record.title;
        _setEditor(record.payload);
      }
    }
  }

  void _setEditor(Map<String, dynamic> data, {bool unsaved = false}) {
    if (!mounted) return;
    firstSnapshot = true;
    editorGeneration++;
    editor = YorksCalculatorEditorSession(
      initialData: data,
      onChanged: _changed,
    );
    baseline = '';
    lastFingerprint = '';
    dirty = unsaved;
    setState(() {});
  }

  void _changed() {
    if (!mounted || editor?.snapshot == null || editor?.ready != true) return;
    final fingerprint =
        '${title.text.trim()}|${YorksCalculatorFiles.fingerprint(Map<String, dynamic>.from(editor!.snapshot!()))}';
    if (firstSnapshot) {
      baseline = fingerprint;
      firstSnapshot = false;
    }
    final next = c.record == null || fingerprint != baseline;
    if (lastFingerprint == fingerprint && next == dirty) return;
    lastFingerprint = fingerprint;
    setState(() => dirty = next);
  }

  @override
  void dispose() {
    if (exitGuard?.check == _canLeave) exitGuard!.check = null;
    refreshTimer?.cancel();
    searchTimer?.cancel();
    title.dispose();
    super.dispose();
  }

  Future<bool> _canLeave() async {
    if (allowPop || (!dirty && !c.hasPending)) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t(S.leave)),
            content: Text(t(c.hasPending ? S.pending : S.leaveHelp)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t(S.stay)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t(c.hasPending ? S.leavePending : S.discard)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _back() async {
    if (await _canLeave() && mounted) {
      setState(() => allowPop = true);
      context.go(yorksCalculatorsPath);
    }
  }

  Future<void> _save() async {
    if (editor?.snapshot == null || title.text.trim().isEmpty) return;
    final result = await c.save({
      'id': id,
      'title': title.text.trim(),
      'kind': kind,
      'project_id': projectId,
      'expected_version': c.record?.version ?? 0,
      'payload': editor!.snapshot!(),
    });
    if (result != null && mounted) {
      ref.invalidate(yorksCalculatorControllerProvider('library'));
      baseline =
          '${title.text.trim()}|${YorksCalculatorFiles.fingerprint(Map<String, dynamic>.from(editor!.snapshot!()))}';
      setState(() => dirty = false);
      if (widget.recordId == 'new') {
        allowPop = true;
        context.go('$yorksCalculatorsPath/${result.id}');
      }
    }
  }

  Future<void> _new({String? type, Map<String, dynamic>? payload}) async {
    try {
      await c.loadOptions();
    } catch (_) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    final name = TextEditingController();
    String selected = type ?? 'duct';
    String? project;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(t(S.newCalculation)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t(S.startHelp)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 160,
                    onChanged: (_) => setDialog(() {}),
                    decoration: InputDecoration(labelText: t(S.name)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: [
                      DropdownMenuItem(value: 'duct', child: Text(t(S.duct))),
                      DropdownMenuItem(value: 'esp', child: Text(t(S.esp))),
                    ],
                    onChanged: payload != null
                        ? null
                        : (v) => setDialog(() => selected = v!),
                    decoration: InputDecoration(labelText: t(S.calculators)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: 'general',
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: 'general',
                        child: Text(t(S.general)),
                      ),
                      for (final p in c.options['projects'] as List? ?? [])
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(
                            p['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => project = v == 'general' ? null : v,
                    decoration: InputDecoration(labelText: t(S.scope)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t(S.cancel)),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'title': name.text.trim(),
                      'kind': selected,
                      'project_id': project,
                      'project_name': (c.options['projects'] as List? ?? [])
                          .where((p) => p['id'] == project)
                          .firstOrNull?['name'],
                      'payload':
                          payload ??
                          {
                            ...YorksCalculatorFiles.fresh(selected),
                            if (selected == 'esp' && project != null)
                              'header': {
                                'projectName':
                                    (c.options['projects'] as List? ?? [])
                                        .where((p) => p['id'] == project)
                                        .firstOrNull?['name'] ??
                                    '',
                              },
                          },
                    }),
              child: Text(t(S.create)),
            ),
          ],
        ),
      ),
    );
    // The dialog's exit animation can still reference its controller.
    Future<void>.delayed(const Duration(milliseconds: 300), name.dispose);
    if (value != null && mounted) {
      context.go('$yorksCalculatorsPath/new', extra: value);
    }
  }

  Future<void> _import({bool legacy = false}) async {
    try {
      String? raw;
      if (legacy) {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(t(S.legacy)),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'duct'),
                child: Text(t(S.duct)),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'esp'),
                child: Text(t(S.esp)),
              ),
            ],
          ),
        );
        if (selected == null) return;
        raw = ref
            .read(sharedPreferencesProvider)
            .getString('yorks_r35_${selected}_calculation');
        if (raw == null) throw const FormatException();
      } else {
        final file = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'JSON', extensions: ['json']),
          ],
        );
        if (file == null) return;
        if (await file.length() > YorksCalculatorFiles.maximumBytes) {
          throw const FormatException();
        }
        raw = await file.readAsString();
      }
      final data = YorksCalculatorFiles.decode(raw);
      if (mounted) {
        await _new(
          type: data['app'] == 'duct-calc' ? 'duct' : 'esp',
          payload: data,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t(S.invalidFile))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => PopScope(
        canPop: allowPop || (!dirty && !c.hasPending),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Material(
          color: AppColors.surfaceContainerLowest,
          child: widget.recordId == null ? _home() : _record(),
        ),
      ),
    );
  }

  Widget _home() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth > 1000;
      return Row(
        children: [
          if (wide) SizedBox(width: 210, child: _libraryRail()),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(
                      constraints.maxWidth < 600 ? 16 : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 24,
                          runSpacing: 16,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(S.calculators),
                                  style: AppTypography.headlineLarge,
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: constraints.maxWidth < 600
                                      ? constraints.maxWidth - 32
                                      : 480,
                                  child: Text(
                                    t(S.subtitle),
                                    style: AppTypography.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            FilledButton.icon(
                              onPressed: c.canCreate ? () => _new() : null,
                              icon: const Icon(Icons.add),
                              label: Text(t(S.newCalculation)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _typeCard('duct', Icons.straighten, t(S.duct)),
                            _typeCard('esp', Icons.speed_outlined, t(S.esp)),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in ['all', 'duct', 'esp'])
                              ChoiceChip(
                                label: Text(
                                  t(
                                    f == 'all'
                                        ? S.all
                                        : f == 'duct'
                                        ? S.duct
                                        : S.esp,
                                  ),
                                ),
                                selected: filter == f,
                                onSelected: (_) {
                                  setState(() => filter = f);
                                  c.kind = f;
                                  c.load();
                                },
                              ),
                            FilterChip(
                              label: Text(t(S.archived)),
                              selected: c.archived,
                              onSelected: (v) {
                                c.archived = v;
                                c.load();
                              },
                            ),
                            DropdownButton<String>(
                              value: scopeFilter,
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text(t(S.all)),
                                ),
                                DropdownMenuItem(
                                  value: 'general',
                                  child: Text(t(S.general)),
                                ),
                                DropdownMenuItem(
                                  value: 'project',
                                  child: Text(t(S.project)),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => scopeFilter = v!);
                                c.scope = v!;
                                c.load();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) {
                                  searchTimer?.cancel();
                                  searchTimer = Timer(
                                    const Duration(milliseconds: 250),
                                    () {
                                      c.search = v;
                                      c.load();
                                    },
                                  );
                                },
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText: t(S.search),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: t(S.refresh),
                              onPressed: () => c.load(),
                              icon: const Icon(Icons.refresh),
                            ),
                            PopupMenuButton<String>(
                              tooltip: t(S.import),
                              onSelected: (v) => _import(legacy: v == 'legacy'),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'file',
                                  enabled: c.canCreate,
                                  child: Text(t(S.import)),
                                ),
                                PopupMenuItem(
                                  value: 'legacy',
                                  enabled: c.canCreate,
                                  child: Text(t(S.legacy)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (c.error != null) _error(),
                      ],
                    ),
                  ),
                ),
                if (c.loading)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                ..._recordList(),
                if (c.hasMore)
                  SliverToBoxAdapter(
                    child: Center(
                      child: TextButton(
                        onPressed: c.loading ? null : () => c.load(more: true),
                        child: Text(t(S.more)),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
          ),
        ],
      );
    },
  );
  List<Widget> _recordList() {
    final visible = c.items
        .where(
          (r) =>
              (filter == 'all' || r.kind == filter) &&
              (scopeFilter == 'all' ||
                  (scopeFilter == 'general'
                      ? r.projectId == null
                      : r.projectId != null)),
        )
        .toList();
    if (visible.isEmpty && !c.loading) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  size: 42,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 16),
                Text(
                  t(c.search.isEmpty ? S.empty : S.noResults),
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(t(S.emptyHelp), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final r = visible[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: Icon(
                  r.kind == 'duct' ? Icons.straighten : Icons.speed_outlined,
                ),
                title: Text(r.title, style: AppTypography.titleMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${t(r.kind == 'duct' ? S.duct : S.esp)} · ${r.projectName ?? t(S.general)}\n${r.owner} · ${_date(r.updatedAt)}',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('$yorksCalculatorsPath/${r.id}'),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _libraryRail() => Material(
    color: AppColors.surfaceContainerLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(t(S.calculators), style: AppTypography.titleMedium),
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(t(S.newCalculation)),
          onTap: c.canCreate ? () => _new() : null,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t(S.recent), style: AppTypography.labelSmall),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final r in c.items.take(15))
                ListTile(
                  title: Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r.projectName ?? t(S.general),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.go('$yorksCalculatorsPath/${r.id}'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _typeCard(String type, IconData icon, String label) => SizedBox(
    width: 260,
    child: OutlinedButton(
      onPressed: c.canCreate ? () => _new(type: type) : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 14),
          Expanded(child: Text(label)),
          const Icon(Icons.add, size: 20),
        ],
      ),
    ),
  );
  Widget _record() {
    if (c.denied) return Column(children: [_backButton(), _error()]);
    if (editor == null) {
      return Column(
        children: [
          _backButton(),
          if (c.busy) const LinearProgressIndicator(),
          if (c.error != null) _error(),
        ],
      );
    }
    final canEdit = (c.record?.canEdit ?? true) && !c.busy && !c.hasPending;
    editor!.readOnly = !canEdit;
    editor!
      ..title = title.text
      ..scope = projectName ?? t(S.general)
      ..revision = dirty
          ? t(S.unsaved)
          : '${t(S.revision)} ${c.record?.version ?? 0}';
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _backButton(),
                  if (c.record?.canManage == true)
                    IconButton(
                      tooltip: t(S.share),
                      onPressed: c.busy || dirty || c.hasPending
                          ? null
                          : _sharing,
                      icon: const Icon(Icons.group_outlined, size: 20),
                    ),
                  FilledButton.icon(
                    onPressed:
                        !c.busy &&
                            (canEdit || c.hasPending) &&
                            title.text.trim().isNotEmpty
                        ? _save
                        : null,
                    icon: Icon(
                      c.hasPending ? Icons.refresh : Icons.save_outlined,
                      size: 18,
                    ),
                    label: Text(
                      t(
                        c.busy
                            ? S.saving
                            : c.hasPending
                            ? S.retry
                            : S.save,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: title,
                readOnly: !canEdit,
                maxLength: 160,
                style: AppTypography.headlineSmall,
                decoration: InputDecoration(
                  hintText: t(S.name),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      projectId == null
                          ? Icons.folder_outlined
                          : Icons.apartment,
                      size: 16,
                    ),
                    label: Text(projectName ?? t(S.general)),
                  ),
                  Text(
                    t(
                      c.hasPending
                          ? S.pending
                          : c.record?.archived == true
                          ? S.archived
                          : !canEdit
                          ? S.viewOnly
                          : dirty
                          ? S.unsaved
                          : S.saved,
                    ),
                    style: AppTypography.bodySmall,
                  ),
                  if (c.record != null)
                    Text(
                      '${t(S.revision)} ${c.record!.version} · ${c.record!.updatedBy} · ${_date(c.record!.updatedAt)}',
                      style: AppTypography.labelSmall,
                    ),
                ],
              ),
              if (compact)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _output(print: true),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(t(S.print)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: t(S.access),
                      onSelected: (value) {
                        switch (value) {
                          case 'import':
                            editor!.importFile?.call();
                          case 'export':
                            _output(print: false);
                          case 'fittings':
                            editor!.showFittings?.call();
                          case 'archive':
                            _archive();
                          case 'refresh':
                            _initialize();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'import',
                          enabled: canEdit,
                          child: Text(t(S.import)),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: Text(t(S.export)),
                        ),
                        if (kind == 'esp')
                          PopupMenuItem(
                            value: 'fittings',
                            child: Text(t(S.fittings)),
                          ),
                        if (c.record?.canManage == true)
                          PopupMenuItem(
                            value: 'archive',
                            enabled: !dirty && !c.busy && !c.hasPending,
                            child: Text(
                              t(c.record!.archived ? S.restore : S.archive),
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: canEdit
                          ? () => editor!.importFile?.call()
                          : null,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: Text(t(S.import)),
                    ),
                    TextButton.icon(
                      onPressed: () => _output(print: false),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(t(S.export)),
                    ),
                    TextButton.icon(
                      onPressed: () => _output(print: true),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(t(S.print)),
                    ),
                    if (kind == 'esp')
                      TextButton.icon(
                        onPressed: () => editor!.showFittings?.call(),
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: Text(t(S.fittings)),
                      ),
                    if (c.record?.canManage == true)
                      TextButton.icon(
                        onPressed: dirty || c.busy || c.hasPending
                            ? null
                            : _archive,
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: Text(
                          t(c.record!.archived ? S.restore : S.archive),
                        ),
                      ),
                    if (c.error != null)
                      TextButton(
                        onPressed: () async {
                          if (await _canLeave() && mounted) {
                            await _initialize();
                          }
                        },
                        child: Text(t(S.refresh)),
                      ),
                  ],
                ),
              if (c.error != null) _error(),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: kind == 'duct'
              ? YorksV1DuctSizerScreen(
                  key: ValueKey(editorGeneration),
                  session: editor,
                )
              : YorksV1EspCalculatorScreen(
                  key: ValueKey(editorGeneration),
                  session: editor,
                ),
        ),
      ],
    );
  }

  Widget _backButton() => TextButton.icon(
    onPressed: _back,
    icon: const Icon(Icons.arrow_back, size: 18),
    label: Text(t(S.back)),
  );
  Widget _error() {
    final message = c.error.toString();
    final text =
        message.contains('INVALID_INPUT') || message.contains('FILE_TOO_LARGE')
        ? S.invalidInputs
        : c.denied
        ? S.denied
        : message.contains('VERSION_CONFLICT')
        ? S.conflict
        : c.hasPending
        ? S.pending
        : S.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        t(text),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
      ),
    );
  }

  String _date(String value) {
    final d = DateTime.tryParse(value)?.toLocal();
    return d == null
        ? ''
        : MaterialLocalizations.of(context).formatShortDate(d);
  }

  Future<void> _output({required bool print}) async {
    if (c.record != null) {
      await c.checkAccess();
      if (c.denied || !mounted) return;
    }
    try {
      if (print) {
        await editor!.printFile?.call();
      } else {
        await editor!.exportFile?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t(S.error))));
      }
    }
  }

  Future<bool> _manage(Map<String, dynamic> change) async {
    final ok = await c.manage(change);
    if (ok && mounted) {
      ref.invalidate(yorksCalculatorControllerProvider('library'));
    }
    return ok;
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(c.record!.archived ? S.restore : S.archive)),
        content: Text(t(S.archiveHelp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(S.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(S.confirm)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _manage({'action': 'archive', 'archived': !c.record!.archived});
    }
  }

  Future<void> _sharing() async {
    try {
      await c.loadOptions();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    String? person;
    String access = 'view';
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(t(S.access)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t(S.sharingHelp)),
                  const SizedBox(height: 16),
                  for (final grant in c.record!.grants)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(grant['name'] as String),
                      subtitle: Text(
                        t(grant['access'] == 'edit' ? S.edit : S.view),
                      ),
                      trailing: IconButton(
                        tooltip: t(S.remove),
                        onPressed: saving
                            ? null
                            : () async {
                                setDialog(() => saving = true);
                                await _manage({
                                  'action': 'access',
                                  'user_id': grant['user_id'],
                                  'access': 'none',
                                });
                                if (context.mounted) {
                                  setDialog(() => saving = false);
                                }
                              },
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(labelText: t(S.person)),
                    items: [
                      for (final p in c.options['people'] as List? ?? [])
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(
                            p['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setDialog(() => person = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: access,
                    items: [
                      DropdownMenuItem(value: 'view', child: Text(t(S.view))),
                      DropdownMenuItem(value: 'edit', child: Text(t(S.edit))),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setDialog(() => access = v!),
                  ),
                  if (c.error != null) _error(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(t(S.cancel)),
            ),
            FilledButton(
              onPressed: person == null || saving
                  ? null
                  : () async {
                      setDialog(() => saving = true);
                      final ok = await _manage({
                        'action': 'access',
                        'user_id': person,
                        'access': access,
                      });
                      if (dialogContext.mounted) {
                        if (ok) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialog(() => saving = false);
                        }
                      }
                    },
              child: Text(t(saving ? S.saving : S.apply)),
            ),
          ],
        ),
      ),
    );
  }
}
