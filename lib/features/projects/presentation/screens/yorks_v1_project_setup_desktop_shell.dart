import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/yorks_v1_workspace_search_launcher.dart';
import '../../../../app/yorks_v1_workspace_shell.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/zoom/yorks_workspace_zoom.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_project_creation_draft.dart';
import '../../../../shared/models/yorks_v1_project_strings.dart';
import '../../../../shared/models/yorks_v1_project_setup_shell_strings.dart';
import '../../../../shared/models/yorks_v1_shell_strings.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../../shared/providers/yorks_v1_workspace_status_provider.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../../shared/widgets/yorks_sign_out_action.dart';

/// Dedicated desktop setup chrome. Controllers, permissions, guards, operation
/// journals and all navigation decisions remain owned by the feature screen.
class YorksV1ProjectSetupDesktopShell extends ConsumerStatefulWidget {
  const YorksV1ProjectSetupDesktopShell({
    super.key,
    required this.language,
    required this.stage,
    required this.visitedStages,
    required this.completeStages,
    required this.reference,
    required this.projectName,
    required this.localStatus,
    required this.saving,
    required this.readOnly,
    required this.body,
    required this.scrollController,
    required this.onSelectStage,
    required this.onSaveDraft,
    required this.onBack,
    required this.onReturnToProjects,
    required this.onContinue,
    required this.onSkip,
    required this.onFinalAction,
    required this.primaryLabel,
    this.notices = const [],
    this.headerActions = const [],
    this.completed = false,
    this.isEditing = false,
    this.savedOnDevice = false,
    this.footerHint,
  });

  final AppLanguage language;
  final YorksV1ProjectCreationStage stage;
  final Set<YorksV1ProjectCreationStage> visitedStages;
  final Set<YorksV1ProjectCreationStage> completeStages;
  final String reference, projectName, localStatus;
  final bool saving, readOnly, completed, isEditing, savedOnDevice;
  final Widget body;
  final ScrollController scrollController;
  final ValueChanged<YorksV1ProjectCreationStage> onSelectStage;
  final VoidCallback? onSaveDraft, onContinue, onSkip, onFinalAction;
  final VoidCallback onBack, onReturnToProjects;
  final TranslatableString primaryLabel;
  final TranslatableString? footerHint;
  final List<Widget> notices, headerActions;

  @override
  ConsumerState<YorksV1ProjectSetupDesktopShell> createState() =>
      _YorksV1ProjectSetupDesktopShellState();
}

class _YorksV1ProjectSetupDesktopShellState
    extends ConsumerState<YorksV1ProjectSetupDesktopShell> {
  bool _railExpanded = true;
  final _menu = MenuController();
  final _nodes = [
    for (final stage in YorksV1ProjectCreationStage.values)
      FocusNode(debugLabel: 'project-setup-${stage.name}'),
  ];

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  static const _navy = Color(0xff153457);
  static const _ink = Color(0xff08244d);
  static const _muted = Color(0xff607aa5);
  static const _line = Color(0xffdbe5ef);
  static const _blue = Color(0xff0065ff);
  static const _rail = Color(0xfff2f6f9);
  static TextStyle _text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _ink,
  }) => AppTypography.bodyMedium.copyWith(
    fontSize: size,
    height: 1.4,
    fontWeight: weight,
    color: color,
  );

  void _openSearch() => unawaited(
    showYorksV1WorkspaceSearch(
      context,
      targets: const [
        YorksV1SearchNavigationTarget(
          label: YorksV1ProjectStrings.projects,
          icon: Icons.folder_outlined,
          path: RoutePaths.yorksV1Projects,
        ),
      ],
      language: widget.language,
      role: ref.read(yorksV1CurrentRoleProvider),
    ),
  );

  void _closeThenGo(String path) {
    _menu.close();
    context.go(path);
  }

  KeyEventResult _moveFocus(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final eligible = [
      for (final stage in YorksV1ProjectCreationStage.values)
        if (widget.visitedStages.contains(stage)) stage.index,
    ];
    if (eligible.isEmpty) return KeyEventResult.ignored;
    final current = eligible.indexOf(_nodes.indexWhere((n) => n.hasFocus));
    final key = event.logicalKey;
    int? destination;
    if (key == LogicalKeyboardKey.home) {
      destination = eligible.first;
    } else if (key == LogicalKeyboardKey.end) {
      destination = eligible.last;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      destination = eligible[(current + 1).clamp(0, eligible.length - 1)];
    } else if (key == LogicalKeyboardKey.arrowUp) {
      destination = eligible[(current - 1).clamp(0, eligible.length - 1)];
    }
    if (destination == null) return KeyEventResult.ignored;
    _nodes[destination].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(yorksV1CurrentRoleProvider);
    final workspaceStatus = ref.watch(yorksV1WorkspaceStatusProvider);
    final name = user?.fullName ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    final review = widget.stage == YorksV1ProjectCreationStage.reviewAndCreate;
    final subtitle = [
      widget.reference.trim(),
      widget.projectName.trim(),
    ].where((s) => s.isNotEmpty).join(' · ');
    final theme = Theme.of(context);
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: _ink,
      side: const BorderSide(color: Color(0xffbdcee4)),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      textStyle: _text(14, weight: FontWeight.w600),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
      },
      child: Theme(
        data: theme.copyWith(
          // The desktop references use explicit control dimensions. Applying
          // adaptive compact density would subtract pixels on browser builds.
          visualDensity: VisualDensity.standard,
          outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff084477),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xffd9dee6),
              disabledForegroundColor: const Color(0xff7488a5),
              minimumSize: const Size(44, 46),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              textStyle: _text(14, weight: FontWeight.w600),
            ),
          ),
        ),
        child: Scaffold(
          key: const ValueKey('project-setup-desktop-shell'),
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Material(
                color: _navy,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('project-setup-rail-toggle'),
                          tooltip:
                              (_railExpanded
                                      ? YorksV1ShellStrings.collapsePanel
                                      : YorksV1ShellStrings.expandPanel)
                                  .active(language),
                          onPressed: () =>
                              setState(() => _railExpanded = !_railExpanded),
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 28),
                        Text(
                          YorksV1ShellStrings.companyName.active(language),
                          style: _text(
                            20,
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 372,
                          height: 44,
                          child: Center(
                            child: Material(
                              color: Colors.white.withValues(alpha: .04),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: .35),
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: InkWell(
                                key: const ValueKey(
                                  'project-setup-workspace-search',
                                ),
                                borderRadius: BorderRadius.circular(5),
                                onTap: _openSearch,
                                child: SizedBox(
                                  height: 36,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.search,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            YorksV1ProjectSetupShellStrings
                                                .search
                                                .active(language),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _text(
                                              12,
                                              color: const Color(0xffd3dfe9),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: .12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '⌘K',
                                            style: _text(
                                              10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 34),
                        const NotificationBell(foregroundColor: Colors.white),
                        const SizedBox(width: 24),
                        MenuAnchor(
                          controller: _menu,
                          menuChildren: [
                            YorksAccountPopover(
                              fallbackName: name,
                              fallbackRole: role,
                              language: language,
                              workspaceStatus: workspaceStatus,
                              onOpenProfile: () =>
                                  _closeThenGo(RoutePaths.engineerProfile),
                              onNotifications: () =>
                                  _closeThenGo(RoutePaths.notifications),
                              onHelp: () => _closeThenGo(RoutePaths.about),
                              onSignOut: () async {
                                _menu.close();
                                await showYorksSignOut(context, ref);
                              },
                            ),
                          ],
                          builder: (context, controller, child) => IconButton(
                            key: const ValueKey('project-setup-account'),
                            tooltip: AppStrings.profile.active(language),
                            onPressed: () => controller.isOpen
                                ? controller.close()
                                : controller.open(),
                            icon: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xffedf5fb),
                              child: Text(
                                initials.isEmpty ? '•' : initials,
                                style: _text(13, weight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_railExpanded)
                      Container(
                        key: const ValueKey('project-setup-desktop-rail'),
                        width: 232,
                        decoration: const BoxDecoration(
                          color: _rail,
                          border: BorderDirectional(
                            end: BorderSide(color: _line),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                26,
                                28,
                                12,
                                widget.stage ==
                                            YorksV1ProjectCreationStage
                                                .projectDetails &&
                                        widget.visitedStages.length == 1
                                    ? 14
                                    : 10,
                              ),
                              child: Text(
                                YorksV1ProjectSetupShellStrings.setup.active(
                                  language,
                                ),
                                style: _text(12, weight: FontWeight.w600),
                              ),
                            ),
                            FocusTraversalGroup(
                              policy: OrderedTraversalPolicy(),
                              child: Focus(
                                canRequestFocus: false,
                                onKeyEvent: _moveFocus,
                                child: Column(
                                  children: [
                                    for (final stage
                                        in YorksV1ProjectCreationStage.values)
                                      _stageItem(stage),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                18,
                                12,
                                10,
                                20,
                              ),
                              child: TextButton.icon(
                                onPressed: widget.saving
                                    ? null
                                    : widget.onReturnToProjects,
                                icon: const Icon(Icons.arrow_back, size: 21),
                                label: Text(
                                  YorksV1ProjectSetupShellStrings
                                      .returnToProjects
                                      .active(language),
                                  style: _text(14, color: _muted),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: widget.completed
                                ? 127
                                : switch (widget.stage) {
                                    YorksV1ProjectCreationStage
                                        .projectDetails =>
                                      124,
                                    YorksV1ProjectCreationStage.buildings =>
                                      127,
                                    YorksV1ProjectCreationStage
                                        .reviewAndCreate =>
                                      119,
                                    _ => 126,
                                  },
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              30,
                              17,
                              21,
                              14,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: _line)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            YorksV1ProjectStrings.projects
                                                .active(language),
                                            style: _text(14),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              '/',
                                              style: _text(14, color: _muted),
                                            ),
                                          ),
                                          Text(
                                            (widget.isEditing
                                                    ? YorksV1ProjectStrings
                                                          .editProject
                                                    : YorksV1ProjectSetupShellStrings
                                                          .create)
                                                .active(language),
                                            style: _text(14, color: _muted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        (widget.isEditing
                                                ? YorksV1ProjectStrings
                                                      .editProject
                                                : review && !widget.completed
                                                ? YorksV1ProjectStrings
                                                      .reviewAndCreate
                                                : YorksV1ProjectSetupShellStrings
                                                      .create)
                                            .active(language),
                                        style: _text(
                                          32,
                                          weight: FontWeight.w700,
                                        ).copyWith(height: 1.2),
                                      ),
                                      Text(
                                        subtitle.isEmpty ||
                                                (!widget.completed &&
                                                    !widget.isEditing &&
                                                    widget.stage ==
                                                        YorksV1ProjectCreationStage
                                                            .projectDetails)
                                            ? YorksV1ProjectSetupShellStrings
                                                  .description
                                                  .active(language)
                                            : subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _text(16, color: _muted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!widget.completed) ...[
                                  const SizedBox(width: 16),
                                  Semantics(
                                    liveRegion: true,
                                    child: Row(
                                      children: [
                                        Icon(
                                          widget.savedOnDevice
                                              ? Icons.laptop_mac
                                              : widget.saving
                                              ? Icons.sync
                                              : Icons.info_outline,
                                          color: _ink,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 270,
                                          ),
                                          child: Text(
                                            widget.savedOnDevice
                                                ? YorksV1ProjectSetupShellStrings
                                                      .saved
                                                      .active(language)
                                                : widget.localStatus,
                                            style: _text(13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  ...widget.headerActions,
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(114, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 9,
                                      ),
                                    ),
                                    key: const ValueKey(
                                      'project-setup-save-draft',
                                    ),
                                    onPressed: widget.saving || widget.readOnly
                                        ? null
                                        : widget.onSaveDraft,
                                    child: Text(
                                      YorksV1ProjectStrings.saveDraft.active(
                                        language,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            child: YorksWorkspaceZoomViewport(
                              routeKey: 'project-setup',
                              language: language,
                              child: LayoutBuilder(
                                builder: (context, constraints) =>
                                    SingleChildScrollView(
                                      controller: widget.scrollController,
                                      padding: EdgeInsets.fromLTRB(
                                        widget.completed
                                            ? 29
                                            : switch (widget.stage) {
                                                YorksV1ProjectCreationStage
                                                    .projectDetails =>
                                                  25,
                                                YorksV1ProjectCreationStage
                                                    .buildings =>
                                                  27,
                                                YorksV1ProjectCreationStage
                                                    .attachments =>
                                                  28,
                                                _ => 29,
                                              },
                                        widget.completed
                                            ? 15
                                            : switch (widget.stage) {
                                                YorksV1ProjectCreationStage
                                                    .projectDetails =>
                                                  0,
                                                YorksV1ProjectCreationStage
                                                    .reviewAndCreate =>
                                                  12,
                                                _ => 18,
                                              },
                                        widget.completed ? 26 : 22,
                                        18,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight:
                                              (constraints.maxHeight - 36)
                                                  .clamp(0, double.infinity),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ...widget.notices,
                                            widget.body,
                                          ],
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.completed)
                Container(
                  height: switch (widget.stage) {
                    YorksV1ProjectCreationStage.projectDetails ||
                    YorksV1ProjectCreationStage.attachments => 86,
                    YorksV1ProjectCreationStage.partiesAndAccess => 66,
                    YorksV1ProjectCreationStage.buildings => 92,
                    YorksV1ProjectCreationStage.reviewAndCreate => 74,
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.saving
                            ? null
                            : widget.stage ==
                                  YorksV1ProjectCreationStage.projectDetails
                            ? widget.onReturnToProjects
                            : widget.onBack,
                        icon: const Icon(Icons.arrow_back, size: 20),
                        label: Text(
                          (widget.stage ==
                                      YorksV1ProjectCreationStage.projectDetails
                                  ? YorksV1ProjectSetupShellStrings
                                        .returnToProjects
                                  : YorksV1ProjectStrings.back)
                              .active(language),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: widget.footerHint != null || review
                              ? Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 28,
                                  ),
                                  child: Text(
                                    (widget.footerHint ??
                                            YorksV1ProjectSetupShellStrings
                                                .reviewHint)
                                        .active(language),
                                    style: _text(12, color: _muted),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      if (widget.stage ==
                          YorksV1ProjectCreationStage.attachments) ...[
                        OutlinedButton(
                          onPressed: widget.saving ? null : widget.onSkip,
                          child: Text(
                            YorksV1ProjectStrings.skipForNow.active(language),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      FilledButton(
                        key: ValueKey(
                          'yorks-v1-project-${review ? 'create' : 'continue'}',
                        ),
                        onPressed: widget.saving
                            ? null
                            : review
                            ? widget.onFinalAction
                            : widget.onContinue,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.saving) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              (review
                                      ? widget.primaryLabel
                                      : switch (widget.stage) {
                                          YorksV1ProjectCreationStage
                                              .projectDetails =>
                                            YorksV1ProjectSetupShellStrings
                                                .continueParties,
                                          YorksV1ProjectCreationStage
                                              .partiesAndAccess =>
                                            YorksV1ProjectSetupShellStrings
                                                .continueBuildings,
                                          YorksV1ProjectCreationStage
                                              .buildings =>
                                            YorksV1ProjectSetupShellStrings
                                                .continueAttachments,
                                          _ =>
                                            YorksV1ProjectSetupShellStrings
                                                .continueLabel,
                                        })
                                  .active(language),
                            ),
                            if (!review &&
                                widget.stage !=
                                    YorksV1ProjectCreationStage
                                        .attachments) ...[
                              const SizedBox(width: 16),
                              const Icon(Icons.arrow_forward, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageItem(YorksV1ProjectCreationStage stage) {
    final selected = widget.stage == stage && !widget.completed;
    final initialDetails =
        !widget.completed &&
        widget.stage == YorksV1ProjectCreationStage.projectDetails &&
        widget.visitedStages.length == 1;
    final complete =
        !initialDetails &&
        (widget.completed || widget.completeStages.contains(stage));
    final enabled =
        !widget.saving &&
        !widget.completed &&
        widget.visitedStages.contains(stage);
    final copy = switch (stage) {
      YorksV1ProjectCreationStage.projectDetails =>
        YorksV1ProjectStrings.projectDetails,
      YorksV1ProjectCreationStage.partiesAndAccess =>
        YorksV1ProjectStrings.partiesAndAccess,
      YorksV1ProjectCreationStage.buildings => YorksV1ProjectStrings.buildings,
      YorksV1ProjectCreationStage.attachments =>
        YorksV1ProjectStrings.attachments,
      YorksV1ProjectCreationStage.reviewAndCreate =>
        YorksV1ProjectStrings.reviewAndCreate,
    };
    return FocusTraversalOrder(
      order: NumericFocusOrder(stage.index.toDouble()),
      child: Semantics(
        selected: selected,
        button: true,
        enabled: enabled,
        label:
            '${copy.active(widget.language)}${complete ? ', ${YorksV1ProjectSetupShellStrings.completed.active(widget.language)}' : ''}',
        child: Material(
          color: selected ? const Color(0xffe3efff) : Colors.transparent,
          child: InkWell(
            key: ValueKey('yorks-v1-project-stage-${stage.name}'),
            focusNode: _nodes[stage.index],
            onTap: enabled ? () => widget.onSelectStage(stage) : null,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    width: 8,
                    color: selected ? _blue : Colors.transparent,
                  ),
                ),
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 24, 0),
              child: Row(
                children: [
                  if (initialDetails) ...[
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _blue : const Color(0xffd8e1eb),
                      ),
                      child: Text(
                        '${stage.index + 1}',
                        style: _text(13, color: selected ? Colors.white : _ink),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      copy.active(widget.language),
                      style: _text(
                        14,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? _blue : _ink,
                      ),
                    ),
                  ),
                  if (complete)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xff008c69),
                      size: 20,
                    )
                  else if (stage == YorksV1ProjectCreationStage.attachments)
                    Text(
                      YorksV1ProjectStrings.optional.active(widget.language),
                      style: _text(12, color: _muted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
