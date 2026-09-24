import 'dart:async';
import 'package:flutter/material.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_role.dart';
import '../shared/models/yorks_v1_shell_strings.dart';
import 'yorks_v1_workspace_search.dart' deferred as search;

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

final _workspaceSearchLauncher = YorksV1WorkspaceSearchLauncher();

/// Search UI and its data sources load on user intent, not shell startup.
Future<void> showYorksV1WorkspaceSearch(
  BuildContext context, {
  required List<YorksV1SearchNavigationTarget> targets,
  required AppLanguage language,
  required YorksV1Role? role,
}) => _workspaceSearchLauncher.open(
  context,
  targets: targets,
  language: language,
  role: role,
);

typedef WorkspaceSearchPresentation =
    Future<void> Function(
      BuildContext context,
      List<YorksV1SearchNavigationTarget> targets,
      AppLanguage language,
      YorksV1Role? role,
    );

class YorksV1WorkspaceSearchLauncher {
  YorksV1WorkspaceSearchLauncher({
    Future<void> Function()? load,
    WorkspaceSearchPresentation? present,
  }) : _load = load ?? search.loadLibrary,
       _present =
           present ??
           ((context, targets, language, role) =>
               search.showYorksV1WorkspaceSearch(
                 context,
                 targets: targets,
                 language: language,
                 role: role,
               ));
  final Future<void> Function() _load;
  final WorkspaceSearchPresentation _present;
  bool _active = false;

  Future<void> open(
    BuildContext context, {
    required List<YorksV1SearchNavigationTarget> targets,
    required AppLanguage language,
    required YorksV1Role? role,
  }) async {
    if (_active) return;
    _active = true;
    try {
      try {
        await _load();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              YorksV1ShellStrings.searchUnavailable.active(language),
            ),
            action: SnackBarAction(
              label: AppStrings.retry.active(language),
              onPressed: () => unawaited(
                open(context, targets: targets, language: language, role: role),
              ),
            ),
          ),
        );
        return;
      }
      if (!context.mounted) return;
      await _present(context, targets, language, role);
    } finally {
      _active = false;
    }
  }
}
