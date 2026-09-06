import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/constants.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_role.dart';
import '../shared/models/yorks_v1_shell_strings.dart';
import '../shared/models/yorks_v1_workspace_search.dart';
import '../shared/providers/yorks_v1_workspace_search_provider.dart';

class YorksV1SearchNavigationTarget {
  const YorksV1SearchNavigationTarget({
    required this.label,
    required this.icon,
    required this.path,
  });

  final TranslatableString label;
  final IconData icon;
  final String path;
}

Future<void> showYorksV1WorkspaceSearch(
  BuildContext context, {
  required List<YorksV1SearchNavigationTarget> targets,
  required AppLanguage language,
  required YorksV1Role? role,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.scrim.withValues(alpha: .42),
    builder: (_) => YorksV1WorkspaceSearchDialog(
      targets: targets,
      language: language,
      role: role,
    ),
  );
}

class YorksV1WorkspaceSearchDialog extends ConsumerStatefulWidget {
  const YorksV1WorkspaceSearchDialog({
    super.key,
    required this.targets,
    required this.language,
    required this.role,
  });

  final List<YorksV1SearchNavigationTarget> targets;
  final AppLanguage language;
  final YorksV1Role? role;

  @override
  ConsumerState<YorksV1WorkspaceSearchDialog> createState() =>
      _YorksV1WorkspaceSearchDialogState();
}

class _YorksV1WorkspaceSearchDialogState
    extends ConsumerState<YorksV1WorkspaceSearchDialog> {
  final _queryController = TextEditingController();
  final _queryFocus = FocusNode();
  Timer? _debounce;
  List<YorksV1WorkspaceSearchResult> _results = const [];
  String _query = '';
  String? _error;
  bool _partial = false;
  int _selectedIndex = 0;
  int _requestVersion = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < AppSpacing.compactBreakpoint;
    final maxWidth = math.min(size.width - (compact ? 16 : 48), 820.0);
    final maxHeight = math.min(size.height - (compact ? 24 : 80), 720.0);
    final visible = _visibleResults;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 24,
        vertical: compact ? 12 : 40,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) => _handleKey(event, visible),
          child: Column(
            children: [
              _SearchHeader(
                controller: _queryController,
                focusNode: _queryFocus,
                language: widget.language,
                compact: compact,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _openSelected(visible),
                onClose: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1),
              Expanded(
                child: _SearchBody(
                  query: _query,
                  results: visible,
                  selectedIndex: _selectedIndex,
                  loading: _loading,
                  error: _error,
                  partial: _partial,
                  language: widget.language,
                  onSelect: _open,
                  onHover: (index) => setState(() => _selectedIndex = index),
                ),
              ),
              _SearchFooter(language: widget.language, compact: compact),
            ],
          ),
        ),
      ),
    );
  }

  List<YorksV1WorkspaceSearchResult> get _visibleResults {
    final moduleResults = [
      for (final target in widget.targets)
        YorksV1WorkspaceSearchResult(
          kind: YorksV1WorkspaceSearchResultKind.module,
          title: target.label.active(widget.language),
          subtitle: YorksV1ShellStrings.searchModule.active(widget.language),
          route: target.path,
          searchableText:
              '${target.label.active(widget.language)} ${_moduleAliases(target.path)}',
        ),
    ];
    if (_query.trim().isEmpty) return moduleResults;
    final query = normalizeYorksWorkspaceSearchText(_query);
    final terms = query.split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
    final modules = moduleResults
        .where(
          (item) => terms.every(
            (term) => normalizeYorksWorkspaceSearchText(
              item.searchableText,
            ).contains(term),
          ),
        )
        .toList(growable: false);
    return [...modules, ..._results];
  }

  KeyEventResult _handleKey(
    KeyEvent event,
    List<YorksV1WorkspaceSearchResult> visible,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (visible.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % visible.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + visible.length) % visible.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _openSelected(visible);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final version = ++_requestVersion;
    setState(() {
      _query = value;
      _selectedIndex = 0;
      _error = null;
      _partial = false;
      _results = const [];
      _loading = value.trim().isNotEmpty;
    });
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final response = await ref.read(
          yorksV1WorkspaceSearchResultsProvider(value.trim()).future,
        );
        if (!mounted || version != _requestVersion) return;
        setState(() {
          _results = response.results;
          _partial = response.isPartial;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || version != _requestVersion) return;
        setState(() {
          _loading = false;
          _error = YorksV1ShellStrings.searchUnavailable.active(
            widget.language,
          );
        });
      }
    });
  }

  void _openSelected(List<YorksV1WorkspaceSearchResult> visible) {
    if (visible.isEmpty) return;
    _open(visible[_selectedIndex.clamp(0, visible.length - 1)]);
  }

  void _open(YorksV1WorkspaceSearchResult result) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(result.route);
  }

  String _moduleAliases(String path) {
    if (path.contains('material-requests')) return 'mr request requisition';
    if (path.contains('inventory')) return 'stock warehouse materials';
    if (path.contains('returns')) return 'return material';
    if (path.contains('dispatch')) return 'delivery logistics';
    if (path.contains('projects')) return 'job contract site';
    if (path.contains('accounts')) return 'finance commercial money';
    if (path.contains('workforce')) return 'attendance timesheet workers';
    if (path.contains('rentals')) return 'rental property tenant';
    if (path.contains('users')) return 'people permissions access';
    if (path.contains('configuration')) return 'settings controls';
    if (path.contains('analytics')) return 'reports charts insights';
    if (path.contains('chat')) return 'messages conversation';
    return '';
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.language,
    required this.compact,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AppLanguage language;
  final bool compact;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      compact ? AppSpacing.md : AppSpacing.lg,
      compact ? AppSpacing.sm : AppSpacing.md,
      compact ? AppSpacing.sm : AppSpacing.md,
      compact ? AppSpacing.sm : AppSpacing.md,
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, color: AppColors.blue),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: AppTypography.titleMedium.copyWith(color: AppColors.ink),
            decoration: InputDecoration(
              hintText: YorksV1ShellStrings.searchHint.active(language),
              border: InputBorder.none,
              isDense: true,
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: YorksV1ShellStrings.searchWorkspace.active(language),
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.query,
    required this.results,
    required this.selectedIndex,
    required this.loading,
    required this.error,
    required this.partial,
    required this.language,
    required this.onSelect,
    required this.onHover,
  });

  final String query;
  final List<YorksV1WorkspaceSearchResult> results;
  final int selectedIndex;
  final bool loading;
  final String? error;
  final bool partial;
  final AppLanguage language;
  final ValueChanged<YorksV1WorkspaceSearchResult> onSelect;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: AppSpacing.md),
              Text(
                YorksV1ShellStrings.searchLoading.active(language),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (results.isEmpty && query.trim().isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                partial ? Icons.cloud_off_outlined : Icons.search_off_rounded,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                error ??
                    (partial
                        ? YorksV1ShellStrings.searchPartial.active(language)
                        : YorksV1ShellStrings.searchNoResults.active(language)),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partial)
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              color: AppColors.warningContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      YorksV1ShellStrings.searchPartial.active(language),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            query.trim().isEmpty
                ? YorksV1ShellStrings.searchModules.active(language)
                : YorksV1ShellStrings.searchResults.active(language),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final result = results[index];
              final selected = index == selectedIndex;
              return MouseRegion(
                onEnter: (_) => onHover(index),
                child: Material(
                  color: selected
                      ? AppColors.blueContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => onSelect(result),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.surfaceContainerLowest
                                  : AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            child: Icon(
                              result.icon,
                              size: 19,
                              color: AppColors.blue,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_kindLabel(result.kind)} · ${result.subtitle}',
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
                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 18,
                            color: selected ? AppColors.blue : AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _kindLabel(YorksV1WorkspaceSearchResultKind kind) => switch (kind) {
    YorksV1WorkspaceSearchResultKind.module =>
      YorksV1ShellStrings.searchModule.active(language),
    YorksV1WorkspaceSearchResultKind.project =>
      YorksV1ShellStrings.searchProject.active(language),
    YorksV1WorkspaceSearchResultKind.boqGroup =>
      YorksV1ShellStrings.searchBoqGroup.active(language),
    YorksV1WorkspaceSearchResultKind.boqItem =>
      YorksV1ShellStrings.searchBoqItem.active(language),
    YorksV1WorkspaceSearchResultKind.materialRequest =>
      YorksV1ShellStrings.searchMaterialRequest.active(language),
    YorksV1WorkspaceSearchResultKind.materialItem =>
      YorksV1ShellStrings.searchMaterialItem.active(language),
    YorksV1WorkspaceSearchResultKind.document =>
      YorksV1ShellStrings.searchDocument.active(language),
  };
}

class _SearchFooter extends StatelessWidget {
  const _SearchFooter({required this.language, required this.compact});

  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      compact ? AppSpacing.sm : AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Text(
      YorksV1ShellStrings.searchKeyboardHint.active(language),
      style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
      textAlign: TextAlign.center,
    ),
  );
}
