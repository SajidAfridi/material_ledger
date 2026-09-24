import 'package:flutter/material.dart';
import '../shared/models/app_language.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/yorks_v1_role.dart';
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

/// Search UI and its data sources load on user intent, not shell startup.
Future<void> showYorksV1WorkspaceSearch(
  BuildContext context, {
  required List<YorksV1SearchNavigationTarget> targets,
  required AppLanguage language,
  required YorksV1Role? role,
}) async {
  await search.loadLibrary();
  if (!context.mounted) return;
  await search.showYorksV1WorkspaceSearch(
    context,
    targets: targets,
    language: language,
    role: role,
  );
}
