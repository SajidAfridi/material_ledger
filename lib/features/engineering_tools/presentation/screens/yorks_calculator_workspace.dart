import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/constants.dart';
import '../../../../shared/controllers/yorks_v1_calculator_controller.dart';
import '../../../../shared/controllers/yorks_v1_calculator_edit_history.dart';
import '../../../../shared/models/analytics_event.dart';
import '../widgets/yorks_calculator_controls.dart';
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
  final search = TextEditingController();
  final editHistory = YorksCalculatorEditHistory();
  final editorFocus = FocusNode(debugLabel: 'calculator-editor');
  bool applyingHistory = false, atomicEdit = false;
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
    HardwareKeyboard.instance.addHandler(_keyboard);
    if (widget.recordId != null) {
      exitGuard = ref.read(yorksCalculatorExitGuardProvider);
      exitGuard!.check = _canLeave;
      exitGuard!.beforeNavigation = _beforeNavigation;
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
        c.track(
          AnalyticsEvent.calculatorOpened,
          kind: record.kind,
          scope: record.projectId == null ? 'general' : 'project',
          source: 'route',
        );
      }
    }
  }

  void _setEditor(Map<String, dynamic> data, {bool unsaved = false}) {
    if (!mounted) return;
    firstSnapshot = true;
    allowPop = false;
    editorGeneration++;
    editor = YorksCalculatorEditorSession(
      initialData: data,
      onChanged: _changed,
      onAction: (action) => _track(action),
    );
    baseline = '';
    lastFingerprint = '';
    dirty = unsaved;
    setState(() {});
  }

  void _changed() {
    if (!mounted ||
        applyingHistory ||
        editor?.snapshot == null ||
        editor?.ready != true) {
      return;
    }
    final fingerprint =
        '${title.text.trim()}|${YorksCalculatorFiles.fingerprint(Map<String, dynamic>.from(editor!.snapshot!()))}';
    if (firstSnapshot) {
      baseline = fingerprint;
      firstSnapshot = false;
      editHistory.reset(_editSnapshot());
    }
    final next = c.record == null || fingerprint != baseline;
    if (lastFingerprint == fingerprint && next == dirty) return;
    lastFingerprint = fingerprint;
    editHistory.record(_editSnapshot(), atomic: atomicEdit);
    atomicEdit = false;
    setState(() => dirty = next);
  }

  @override
  void dispose() {
    if (exitGuard?.check == _canLeave) {
      exitGuard!.check = null;
      exitGuard!.beforeNavigation = null;
    }
    HardwareKeyboard.instance.removeHandler(_keyboard);
    editorFocus.dispose();
    refreshTimer?.cancel();
    searchTimer?.cancel();
    title.dispose();
    search.dispose();
    super.dispose();
  }

  bool get _editable =>
      editor?.ready == true &&
      !c.busy &&
      !c.hasPending &&
      !c.denied &&
      (c.record?.canEdit ?? c.canCreate);
  Map<String, dynamic> _editSnapshot() => {
    'title': title.text,
    'payload': editor!.snapshot!(),
  };
  void _track(String action, {String source = 'button'}) => c.track(
    AnalyticsEvent.calculatorInteraction,
    kind: kind,
    scope: projectId == null ? 'general' : 'project',
    action: action,
    source: source,
  );
  Future<bool> _beforeNavigation() async {
    final accepted = await _canLeave();
    if (accepted && mounted) setState(() => allowPop = true);
    return accepted;
  }

  Future<void> _history({required bool redo, String source = 'button'}) async {
    if (!_editable) return;
    _changed();
    final value = redo ? editHistory.redo() : editHistory.undo();
    if (value == null) return;
    applyingHistory = true;
    title.text = value['title'] as String;
    await editor!.restoreData?.call(
      Map<String, dynamic>.from(value['payload'] as Map),
    );
    applyingHistory = false;
    if (!mounted) return;
    lastFingerprint =
        '${title.text.trim()}|${YorksCalculatorFiles.fingerprint(Map<String, dynamic>.from(editor!.snapshot!()))}';
    setState(() => dirty = c.record == null || lastFingerprint != baseline);
    _track(redo ? 'redo' : 'undo', source: source);
  }

  void _rowAction({required bool duplicate, String source = 'button'}) {
    if (!_editable || kind != 'esp') return;
    _changed();
    editHistory.checkpoint();
    atomicEdit = true;
    (duplicate ? editor!.duplicateRow : editor!.addRow)?.call();
    _track(duplicate ? 'row_duplicate' : 'row_add', source: source);
  }

  bool _keyboard(KeyEvent event) {
    if (event is! KeyDownEvent || widget.recordId == null) return false;
    final focused = FocusManager.instance.primaryFocus;
    if (focused != editorFocus &&
        !(focused?.ancestors.contains(editorFocus) ?? false)) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyS &&
        !keyboard.isAltPressed &&
        !keyboard.isShiftPressed) {
      if ((!c.busy && c.hasPending) || (_editable && dirty)) {
        unawaited(_save(source: 'keyboard'));
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyP &&
        !keyboard.isAltPressed &&
        !keyboard.isShiftPressed) {
      unawaited(_output(print: true, source: 'keyboard'));
      return true;
    }
    if (key == LogicalKeyboardKey.enter && kind == 'esp') {
      if (keyboard.isShiftPressed && !keyboard.isAltPressed) {
        _rowAction(duplicate: false, source: 'keyboard');
        return true;
      }
      if (keyboard.isAltPressed && !keyboard.isShiftPressed) {
        _rowAction(duplicate: true, source: 'keyboard');
        return true;
      }
    }
    return false;
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

  Future<void> _save({String source = 'button'}) async {
    if (c.busy || editor?.snapshot == null || title.text.trim().isEmpty) return;
    _changed();
    editHistory.checkpoint();
    final result = await c.save({
      'id': id,
      'title': title.text.trim(),
      'kind': kind,
      'project_id': projectId,
      'expected_version': c.record?.version ?? 0,
      'payload': editor!.snapshot!(),
    }, source: source);
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
    c.track(
      AnalyticsEvent.calculatorInteraction,
      kind: type ?? 'all',
      action: 'create_open',
    );
    final name = TextEditingController();
    var selected = type ?? 'duct';
    var project = 'general';
    var scopeValid = true;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          void create() {
            if (name.text.trim().isEmpty || !scopeValid) return;
            Navigator.pop(dialogContext, {
              'title': name.text.trim(),
              'kind': selected,
              'project_id': project == 'general' ? null : project,
              'project_name': (c.options['projects'] as List? ?? [])
                  .where((p) => p['id'] == project)
                  .firstOrNull?['name'],
              'payload':
                  payload ??
                  {
                    ...YorksCalculatorFiles.fresh(selected),
                    if (selected == 'esp' && project != 'general')
                      'header': {
                        'projectName':
                            (c.options['projects'] as List? ?? [])
                                .where((p) => p['id'] == project)
                                .firstOrNull?['name'] ??
                            '',
                      },
                  },
            });
          }

          return _dialogSurface(
            context,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                    create,
                const SingleActivator(LogicalKeyboardKey.enter, control: true):
                    create,
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dialogHeader(
                    t(S.newCalculation),
                    () => Navigator.pop(dialogContext),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(t(S.startHelp), style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(t(S.calculatorType), style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'duct',
                        icon: const YorksDuctIcon(size: 18),
                        label: Text(t(S.duct)),
                        enabled: payload == null || selected == 'duct',
                      ),
                      ButtonSegment(
                        value: 'esp',
                        icon: const Icon(Icons.speed_outlined, size: 18),
                        label: Text(t(S.esp)),
                        enabled: payload == null || selected == 'esp',
                      ),
                    ],
                    selected: {selected},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppColors.line),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                    ),
                    onSelectionChanged: payload == null
                        ? (v) => setDialog(() => selected = v.single)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(t(S.name), style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 160,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: t(S.name),
                      counterStyle: AppTypography.bodySmall,
                    ),
                    onChanged: (_) => setDialog(() {}),
                    onSubmitted: (_) => create(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  YorksCalculatorSelect<String>(
                    label: t(S.scope),
                    onValidityChanged: (valid) {
                      if (scopeValid != valid) {
                        setDialog(() => scopeValid = valid);
                      }
                    },
                    value: project,
                    searchable: true,
                    hint: t(S.chooseProject),
                    entries: [
                      DropdownMenuEntry(
                        value: 'general',
                        label: t(S.general),
                        leadingIcon: const Icon(
                          Icons.folder_outlined,
                          size: 18,
                        ),
                      ),
                      for (final p in c.options['projects'] as List? ?? [])
                        DropdownMenuEntry(
                          value: p['id'] as String,
                          label: p['name'] as String,
                          leadingIcon: const Icon(
                            Icons.apartment_outlined,
                            size: 18,
                          ),
                        ),
                    ],
                    onSelected: (v) {
                      if (v != null) setDialog(() => project = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    t(project == 'general' ? S.generalHelp : S.projectHelp),
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(t(S.cancel)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: name.text.trim().isEmpty || !scopeValid
                            ? null
                            : create,
                        child: Text(t(S.create)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), name.dispose);
    if (value != null && mounted) {
      c.track(
        AnalyticsEvent.calculatorCreationStarted,
        kind: value['kind'] as String,
        scope: value['project_id'] == null ? 'general' : 'project',
      );
      context.go('$yorksCalculatorsPath/new', extra: value);
    } else {
      c.track(
        AnalyticsEvent.calculatorInteraction,
        kind: selected,
        action: 'create_cancel',
        outcome: 'cancelled',
      );
    }
  }

  Widget _dialogSurface(BuildContext context, {required Widget child}) => Theme(
    data: Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkSecondary,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
        ),
      ),
    ),
    child: Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height - 2 * AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: child,
        ),
      ),
    ),
  );
  Widget _dialogHeader(String label, VoidCallback? close) => Row(
    children: [
      Expanded(child: Text(label, style: AppTypography.titleLarge)),
      IconButton(
        tooltip: t(S.close),
        onPressed: close,
        icon: const Icon(Icons.close, size: 20),
      ),
    ],
  );

  Future<void> _import({bool legacy = false}) async {
    try {
      String? raw;
      if (legacy) {
        await _deviceImports();
        return;
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
      c.track(
        AnalyticsEvent.calculatorImportResult,
        kind: data['app'] == 'duct-calc' ? 'duct' : 'esp',
        source: 'file',
        outcome: 'confirmed',
      );
      if (mounted) {
        await _new(
          type: data['app'] == 'duct-calc' ? 'duct' : 'esp',
          payload: data,
        );
      }
    } catch (_) {
      c.track(
        AnalyticsEvent.calculatorImportResult,
        source: 'file',
        outcome: 'invalid',
      );
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
        child: Focus(
          focusNode: editorFocus,
          autofocus: widget.recordId != null,
          child: Material(
            color: AppColors.surfaceContainerLowest,
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: Theme.of(context).inputDecorationTheme
                    .copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTapTarget,
                      ),
                    ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    minimumSize: const Size(0, AppSpacing.minTapTarget),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSecondary,
                    minimumSize: const Size(0, AppSpacing.minTapTarget),
                  ),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.inkSecondary,
                    minimumSize: const Size(
                      AppSpacing.minTapTarget,
                      AppSpacing.minTapTarget,
                    ),
                  ),
                ),
              ),
              child: widget.recordId == null
                  ? _home()
                  : Shortcuts(
                      shortcuts: {
                        const SingleActivator(
                          LogicalKeyboardKey.keyZ,
                          control: true,
                        ): const UndoTextIntent(
                          SelectionChangedCause.keyboard,
                        ),
                        const SingleActivator(
                          LogicalKeyboardKey.keyZ,
                          meta: true,
                        ): const UndoTextIntent(
                          SelectionChangedCause.keyboard,
                        ),
                        const SingleActivator(
                          LogicalKeyboardKey.keyZ,
                          control: true,
                          shift: true,
                        ): const RedoTextIntent(
                          SelectionChangedCause.keyboard,
                        ),
                        const SingleActivator(
                          LogicalKeyboardKey.keyZ,
                          meta: true,
                          shift: true,
                        ): const RedoTextIntent(
                          SelectionChangedCause.keyboard,
                        ),
                        const SingleActivator(
                          LogicalKeyboardKey.keyY,
                          control: true,
                        ): const RedoTextIntent(
                          SelectionChangedCause.keyboard,
                        ),
                      },
                      child: Actions(
                        actions: {
                          UndoTextIntent:
                              YorksCalculatorHistoryAction<UndoTextIntent>(
                                () => unawaited(
                                  _history(redo: false, source: 'keyboard'),
                                ),
                              ),
                          RedoTextIntent:
                              YorksCalculatorHistoryAction<RedoTextIntent>(
                                () => unawaited(
                                  _history(redo: true, source: 'keyboard'),
                                ),
                              ),
                        },
                        child: _record(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _home() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < AppSpacing.compactBreakpoint;
      final gutter = compact ? AppSpacing.lg : AppSpacing.xxxl;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpacing.xxl, gutter, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t(S.calculators),
                      style: AppTypography.titleLarge,
                    ),
                  ),
                  _importMenu(),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: c.canCreate ? () => _new() : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(t(S.newCalculation)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    AppSpacing.huge,
                    gutter,
                    AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(S.start), style: AppTypography.headlineMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(t(S.subtitle), style: AppTypography.bodyMedium),
                      const SizedBox(height: AppSpacing.xxl),
                      LayoutBuilder(
                        builder: (context, box) {
                          final duct = _typeCard(
                            'duct',
                            Icons.air_outlined,
                            S.duct,
                            S.ductHelp,
                          );
                          final esp = _typeCard(
                            'esp',
                            Icons.speed_outlined,
                            S.esp,
                            S.espHelp,
                          );
                          return box.maxWidth < 560
                              ? Column(
                                  children: [
                                    duct,
                                    const SizedBox(height: AppSpacing.md),
                                    esp,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: duct),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(child: esp),
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: AppSpacing.huge),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t(S.recent),
                              style: AppTypography.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: t(S.refresh),
                            onPressed: c.loading ? null : () => c.load(),
                            icon: const Icon(Icons.refresh, size: 19),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: search,
                        onChanged: (v) {
                          searchTimer?.cancel();
                          searchTimer = Timer(
                            const Duration(milliseconds: 250),
                            () {
                              c.search = v;
                              c.track(
                                AnalyticsEvent.calculatorInteraction,
                                action: 'search',
                              );
                              c.load();
                            },
                          );
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 19),
                          hintText: t(S.search),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _filterMenu(
                            label: t(
                              filter == 'all'
                                  ? S.all
                                  : filter == 'duct'
                                  ? S.duct
                                  : S.esp,
                            ),
                            value: filter,
                            choices: {
                              'all': S.all,
                              'duct': S.duct,
                              'esp': S.esp,
                            },
                            onChanged: (v) {
                              setState(() => filter = v);
                              c.kind = v;
                              c.track(
                                AnalyticsEvent.calculatorInteraction,
                                kind: v,
                                action: 'filter_type',
                              );
                              c.load();
                            },
                          ),
                          _filterMenu(
                            label: t(
                              scopeFilter == 'all'
                                  ? S.allScopes
                                  : scopeFilter == 'general'
                                  ? S.general
                                  : S.project,
                            ),
                            value: scopeFilter,
                            choices: {
                              'all': S.allScopes,
                              'general': S.general,
                              'project': S.project,
                            },
                            onChanged: (v) {
                              setState(() => scopeFilter = v);
                              c.scope = v;
                              c.track(
                                AnalyticsEvent.calculatorInteraction,
                                scope: v,
                                action: 'filter_scope',
                              );
                              c.load();
                            },
                          ),
                          _filterMenu(
                            label: t(c.archived ? S.archived : S.active),
                            value: c.archived ? 'archived' : 'active',
                            choices: {
                              'active': S.active,
                              'archived': S.archived,
                            },
                            onChanged: (v) {
                              c.archived = v == 'archived';
                              c.track(
                                AnalyticsEvent.calculatorInteraction,
                                action: 'filter_state',
                              );
                              c.load();
                            },
                          ),
                        ],
                      ),
                      if (c.error != null) _error(),
                      if (c.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.lg),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      _recordList(),
                      if (c.hasMore)
                        Center(
                          child: TextButton(
                            onPressed: c.loading
                                ? null
                                : () => c.load(more: true),
                            child: Text(t(S.more)),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.huge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _importMenu() => PopupMenuButton<String>(
    tooltip: t(S.import),
    onSelected: (v) => _import(legacy: v == 'legacy'),
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'file',
        enabled: c.canCreate,
        child: _menuLabel(Icons.file_upload_outlined, t(S.importFile)),
      ),
      PopupMenuItem(
        value: 'legacy',
        enabled: c.canCreate,
        child: _menuLabel(Icons.computer_outlined, t(S.legacy)),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        height: AppSpacing.minTapTarget,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_upload_outlined, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(t(S.import), style: AppTypography.labelLarge),
          ],
        ),
      ),
    ),
  );

  Widget _filterMenu({
    required String label,
    required String value,
    required Map<String, TranslatableString> choices,
    required ValueChanged<String> onChanged,
  }) => PopupMenuButton<String>(
    tooltip: label,
    initialValue: value,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final entry in choices.entries)
        CheckedPopupMenuItem(
          value: entry.key,
          checked: value == entry.key,
          child: Text(t(entry.value)),
        ),
    ],
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppColors.muted,
          ),
        ],
      ),
    ),
  );

  Widget _recordList() {
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
      final filtered =
          c.search.isNotEmpty ||
          filter != 'all' ||
          scopeFilter != 'all' ||
          c.archived;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.huge,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 30,
              color: AppColors.mutedLight,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              t(filtered ? S.noResults : S.empty),
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              t(filtered ? S.filteredHelp : S.emptyHelp),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            if (filtered)
              TextButton(
                onPressed: () {
                  searchTimer?.cancel();
                  search.clear();
                  setState(() {
                    filter = 'all';
                    scopeFilter = 'all';
                  });
                  c
                    ..search = ''
                    ..kind = 'all'
                    ..scope = 'all'
                    ..archived = false;
                  c.load();
                },
                child: Text(t(S.clearFilters)),
              ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final r in visible)
          Material(
            color: AppColors.surfaceContainerLowest,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: () => context.go('$yorksCalculatorsPath/${r.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _toolIcon(
                      r.kind == 'duct'
                          ? Icons.air_outlined
                          : Icons.speed_outlined,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: AppTypography.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${t(r.kind == 'duct' ? S.duct : S.esp)} · ${r.projectName ?? t(S.general)}',
                            style: AppTypography.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${r.owner} · ${_date(r.updatedAt)} · ${t(r.archived
                                ? S.archived
                                : r.canEdit
                                ? S.edit
                                : S.viewOnly)}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.mutedLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _toolIcon(IconData icon) => Container(
    width: AppSpacing.massive,
    height: AppSpacing.massive,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Center(
      child: icon == Icons.air_outlined
          ? const YorksDuctIcon()
          : Icon(icon, size: 22, color: AppColors.inkSecondary),
    ),
  );

  Widget _typeCard(
    String type,
    IconData icon,
    TranslatableString label,
    TranslatableString help,
  ) => Material(
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: c.canCreate ? () => _new(type: type) : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _toolIcon(icon),
                const Spacer(),
                const Icon(Icons.add, size: 20, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(t(label), style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(t(help), style: AppTypography.bodyMedium),
          ],
        ),
      ),
    ),
  );
  Widget _record() {
    if (c.denied) return Center(child: _error());
    if (editor == null) {
      return Column(
        children: [
          if (c.busy) const LinearProgressIndicator(),
          if (c.error != null) _error(),
        ],
      );
    }
    final canEdit = (c.record?.canEdit ?? true) && !c.busy && !c.hasPending;
    editor!.readOnly = !canEdit;
    editor!.rowAction = (duplicate) => _rowAction(duplicate: duplicate);
    editor!
      ..title = title.text
      ..scope = projectName ?? t(S.general)
      ..revision = dirty
          ? t(S.unsaved)
          : '${t(S.revision)} ${c.record?.version ?? 0}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppSpacing.compactBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact)
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: t(S.name),
                            child: TextField(
                              controller: title,
                              readOnly: !canEdit,
                              maxLength: 160,
                              style: compact
                                  ? AppTypography.titleLarge
                                  : AppTypography.headlineMedium,
                              decoration: InputDecoration(
                                hintText: t(S.name),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.blue),
                                ),
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                counterText: '',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        _recordMenu(canEdit, compact: compact),
                        if (c.record?.canManage == true)
                          IconButton(
                            tooltip: t(S.access),
                            onPressed: c.busy || dirty || c.hasPending
                                ? null
                                : _sharing,
                            icon: const Icon(Icons.group_outlined, size: 20),
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed:
                              !c.busy &&
                                  ((canEdit && dirty) || c.hasPending) &&
                                  title.text.trim().isNotEmpty
                              ? _save
                              : null,
                          icon: Icon(
                            c.hasPending ? Icons.refresh : Icons.check,
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
                  if (compact) ...[
                    Semantics(
                      label: t(S.name),
                      child: TextField(
                        controller: title,
                        readOnly: !canEdit,
                        maxLength: 160,
                        style: AppTypography.titleLarge,
                        decoration: InputDecoration(
                          hintText: t(S.name),
                          border: InputBorder.none,
                          filled: false,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _historyControls(),
                        const Spacer(),
                        FilledButton(
                          onPressed:
                              !c.busy &&
                                  ((canEdit && dirty) || c.hasPending) &&
                                  title.text.trim().isNotEmpty
                              ? _save
                              : null,
                          child: Text(
                            t(
                              c.busy
                                  ? S.saving
                                  : c.hasPending
                                  ? S.retry
                                  : S.save,
                            ),
                          ),
                        ),
                        _recordMenu(canEdit, compact: true),
                      ],
                    ),
                    Wrap(
                      spacing: AppSpacing.md,
                      children: [
                        _filesMenu(canEdit),
                        if (c.record?.canManage == true)
                          TextButton.icon(
                            onPressed: c.busy || dirty || c.hasPending
                                ? null
                                : _sharing,
                            icon: const Icon(Icons.group_outlined, size: 18),
                            label: Text(t(S.access)),
                          ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          _historyControls(),
                          const SizedBox(width: AppSpacing.lg),
                          _fileControls(canEdit),
                          const Spacer(),
                          if (kind == 'esp')
                            Text(
                              t(S.rowShortcutHelp),
                              style: AppTypography.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            projectId == null
                                ? Icons.folder_outlined
                                : Icons.apartment_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth - 100,
                            ),
                            child: Text(
                              projectName ?? t(S.general),
                              style: AppTypography.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            c.busy
                                ? Icons.sync
                                : c.hasPending
                                ? Icons.cloud_off_outlined
                                : c.record?.archived == true
                                ? Icons.archive_outlined
                                : !canEdit
                                ? Icons.lock_outline
                                : dirty
                                ? Icons.circle_outlined
                                : Icons.check_circle_outline,
                            size: 14,
                            color: c.hasPending && !c.busy
                                ? AppColors.warning
                                : AppColors.muted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              t(
                                c.busy
                                    ? S.saving
                                    : c.hasPending
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
                          ),
                        ],
                      ),
                      if (c.record != null)
                        Text(
                          '${t(S.revision)} ${c.record!.version} · ${c.record!.updatedBy} · ${_date(c.record!.updatedAt)}',
                          style: AppTypography.bodySmall,
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
      },
    );
  }

  Widget _historyControls() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '${t(S.undo)} (${YorksCalculatorShortcuts.undo})',
        onPressed: _editable && editHistory.canUndo
            ? () => _history(redo: false)
            : null,
        icon: const Icon(Icons.undo, size: 20),
      ),
      IconButton(
        tooltip: '${t(S.redo)} (${YorksCalculatorShortcuts.redo})',
        onPressed: _editable && editHistory.canRedo
            ? () => _history(redo: true)
            : null,
        icon: const Icon(Icons.redo, size: 20),
      ),
    ],
  );

  Widget _fileControls(bool canEdit) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton.icon(
        onPressed: canEdit ? _editorImport : null,
        icon: const Icon(Icons.file_upload_outlined, size: 18),
        label: Text(t(S.importAction)),
      ),
      const SizedBox(width: AppSpacing.sm),
      PopupMenuButton<String>(
        tooltip: t(S.exportAction),
        onSelected: (v) => _output(print: v == 'print'),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'export',
            child: _menuLabel(Icons.file_download_outlined, t(S.export)),
          ),
          PopupMenuItem(
            value: 'print',
            child: _menuLabel(
              Icons.print_outlined,
              t(S.print),
              shortcut: YorksCalculatorShortcuts.print,
            ),
          ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.file_download_outlined, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(t(S.exportAction), style: AppTypography.labelLarge),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _filesMenu(bool canEdit) => PopupMenuButton<String>(
    tooltip: t(S.fileActions),
    onSelected: (v) async {
      switch (v) {
        case 'import':
          await _editorImport();
        case 'export':
          await _output(print: false);
        case 'print':
          await _output(print: true);
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'import',
        enabled: canEdit,
        child: _menuLabel(Icons.file_upload_outlined, t(S.import)),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'export',
        child: _menuLabel(Icons.file_download_outlined, t(S.export)),
      ),
      PopupMenuItem(
        value: 'print',
        child: _menuLabel(
          Icons.print_outlined,
          t(S.print),
          shortcut: YorksCalculatorShortcuts.print,
        ),
      ),
    ],
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t(S.fileActions), style: AppTypography.labelLarge),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    ),
  );
  Widget _menuLabel(IconData icon, String label, {String? shortcut}) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.inkSecondary),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text(label)),
      if (shortcut != null) ...[
        const SizedBox(width: AppSpacing.xl),
        YorksShortcutHint(shortcut),
      ],
    ],
  );

  Future<void> _editorImport() async {
    if (!_editable) return;
    _track('import_open');
    if (dirty) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => _dialogSurface(
          context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dialogHeader(
                t(S.replaceInputs),
                () => Navigator.pop(context, false),
              ),
              Text(t(S.replaceHelp), style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t(S.cancel)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t(S.import)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
    }
    _changed();
    editHistory.checkpoint();
    atomicEdit = true;
    final outcome = await editor!.importFile?.call();
    if (!mounted) return;
    _changed();
    editHistory.checkpoint();
    atomicEdit = false;
    c.track(
      AnalyticsEvent.calculatorImportResult,
      kind: kind,
      scope: projectId == null ? 'general' : 'project',
      source: 'file',
      outcome: outcome?.name ?? 'failed',
    );
  }

  Future<void> _showShortcuts() async {
    _track('shortcuts_open');
    await showDialog<void>(
      context: context,
      builder: (context) => _dialogSurface(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dialogHeader(t(S.shortcuts), () => Navigator.pop(context)),
            for (final row in <(String, String)>[
              (t(S.save), YorksCalculatorShortcuts.save),
              (t(S.undo), YorksCalculatorShortcuts.undo),
              (t(S.redo), YorksCalculatorShortcuts.redo),
              (t(S.print), YorksCalculatorShortcuts.print),
              if (kind == 'esp') (t(S.addRow), YorksCalculatorShortcuts.addRow),
              if (kind == 'esp')
                (t(S.duplicateRow), YorksCalculatorShortcuts.duplicateRow),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1)),
                    YorksShortcutHint(row.$2),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deviceImports() async {
    final device = c.deviceImports();
    final available = device.available;
    final invalid = device.invalid;
    c.track(
      AnalyticsEvent.calculatorImportResult,
      source: 'device',
      outcome: available.isNotEmpty
          ? 'ready'
          : invalid.isNotEmpty
          ? 'invalid'
          : 'missing',
    );
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _dialogSurface(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dialogHeader(t(S.legacy), () => Navigator.pop(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(t(S.deviceImportHelp), style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            if (available.isEmpty && invalid.isEmpty) ...[
              Text(t(S.noDeviceCalculations), style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final tool in ['duct', 'esp'])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    leading: tool == 'duct'
                        ? const YorksDuctIcon()
                        : const Icon(Icons.speed_outlined),
                    title: Text(t(tool == 'duct' ? S.duct : S.esp)),
                    subtitle: Text(
                      t(
                        available.containsKey(tool)
                            ? S.deviceReady
                            : invalid.contains(tool)
                            ? S.deviceInvalid
                            : S.deviceUnavailable,
                      ),
                    ),
                    trailing: available.containsKey(tool)
                        ? const Icon(Icons.arrow_forward, size: 18)
                        : null,
                    onTap: available.containsKey(tool)
                        ? () => Navigator.pop(context, tool)
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'file'),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(t(S.importFile)),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'file') {
      await _import();
      return;
    }
    c.track(
      AnalyticsEvent.calculatorImportResult,
      kind: selected,
      source: 'device',
      outcome: 'confirmed',
    );
    await _new(type: selected, payload: available[selected]);
  }

  Widget _recordMenu(bool canEdit, {required bool compact}) =>
      PopupMenuButton<String>(
        tooltip: t(S.actions),
        icon: const Icon(Icons.more_horiz, size: 20),
        onSelected: (value) async {
          switch (value) {
            case 'import':
              await _editorImport();
            case 'export':
              await _output(print: false);
            case 'print':
              await _output(print: true);
            case 'fittings':
              await editor!.showFittings?.call();
            case 'shortcuts':
              await _showShortcuts();
            case 'archive':
              await _archive();
            case 'refresh':
              if (await _canLeave() && mounted) await _initialize();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'shortcuts', child: Text(t(S.shortcuts))),
          if (kind == 'esp')
            PopupMenuItem(value: 'fittings', child: Text(t(S.fittings))),
          if (c.error != null)
            PopupMenuItem(value: 'refresh', child: Text(t(S.refresh))),
          if (c.record?.canManage == true) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'archive',
              enabled: !dirty && !c.busy && !c.hasPending,
              child: Text(t(c.record!.archived ? S.restore : S.archive)),
            ),
          ],
        ],
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
        : message.contains('CALCULATOR_PROJECT_ARCHIVED')
        ? S.projectArchived
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

  Future<void> _output({required bool print, String source = 'button'}) async {
    _track(print ? 'print' : 'export', source: source);
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
    if (c.record?.canManage != true || dirty || c.busy || c.hasPending) return;
    _track('access_open');
    try {
      await c.loadOptions();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    String? person;
    var access = 'view';
    var saving = false;
    var updated = false;
    var personValid = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          Future<void> apply(Map<String, dynamic> change) async {
            if (saving) return;
            setDialog(() {
              saving = true;
              updated = false;
            });
            final ok = await _manage(change);
            if (!dialogContext.mounted) return;
            setDialog(() {
              saving = false;
              updated = ok;
              if (ok) person = null;
            });
          }

          final people = (c.options['people'] as List? ?? []).where(
            (p) => !c.record!.grants.any((g) => g['user_id'] == p['id']),
          );
          return PopScope(
            canPop: !saving,
            child: _dialogSurface(
              context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dialogHeader(
                    t(S.access),
                    saving ? null : () => Navigator.pop(dialogContext),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(t(S.accessHelp), style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(t(S.peopleWithAccess), style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceContainerLow,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    title: Text(c.record!.owner),
                    trailing: Text(t(S.owner), style: AppTypography.bodySmall),
                  ),
                  if (c.record!.grants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        t(S.noSharedPeople),
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  for (final grant in c.record!.grants)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              grant['name'] as String,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: 130,
                            child: YorksCalculatorSelect<String>(
                              label: t(S.accessLevel),
                              value: grant['access'] as String,
                              entries: [
                                DropdownMenuEntry(
                                  value: 'view',
                                  label: t(S.view),
                                ),
                                DropdownMenuEntry(
                                  value: 'edit',
                                  label: t(S.edit),
                                ),
                              ],
                              onSelected: saving
                                  ? null
                                  : (v) {
                                      if (v != null && v != grant['access']) {
                                        unawaited(
                                          apply({
                                            'action': 'access',
                                            'user_id': grant['user_id'],
                                            'access': v,
                                          }),
                                        );
                                      }
                                    },
                            ),
                          ),
                          IconButton(
                            tooltip: t(S.remove),
                            onPressed: saving
                                ? null
                                : () => apply({
                                    'action': 'access',
                                    'user_id': grant['user_id'],
                                    'access': 'none',
                                  }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.xl),
                  Text(t(S.addPeople), style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  YorksCalculatorSelect<String>(
                    label: t(S.person),
                    onValidityChanged: (valid) {
                      if (personValid != valid) {
                        setDialog(() => personValid = valid);
                      }
                    },
                    hint: t(S.choosePerson),
                    value: person,
                    searchable: true,
                    entries: [
                      for (final p in people)
                        DropdownMenuEntry(
                          value: p['id'] as String,
                          label: p['name'] as String,
                        ),
                    ],
                    onSelected: saving
                        ? null
                        : (v) => setDialog(() => person = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  YorksCalculatorSelect<String>(
                    label: t(S.accessLevel),
                    value: access,
                    entries: [
                      DropdownMenuEntry(
                        value: 'view',
                        label: t(S.view),
                        leadingIcon: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                        ),
                      ),
                      DropdownMenuEntry(
                        value: 'edit',
                        label: t(S.edit),
                        leadingIcon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ],
                    onSelected: saving
                        ? null
                        : (v) {
                            if (v != null) setDialog(() => access = v);
                          },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    t(access == 'view' ? S.viewHelp : S.editHelp),
                    style: AppTypography.bodySmall,
                  ),
                  if (c.error != null) _error(),
                  if (updated)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        t(S.accessSaved),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        child: Text(t(S.close)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: person == null || !personValid || saving
                            ? null
                            : () => apply({
                                'action': 'access',
                                'user_id': person,
                                'access': access,
                              }),
                        child: Text(t(saving ? S.saving : S.grantAccess)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
