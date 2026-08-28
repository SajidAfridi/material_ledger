import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presentation-only desktop workspace preferences shared by the shell and
/// focused editing routes. Authorization and feature state never depend on
/// this provider.
final yorksV1WorkspaceSidebarExpandedProvider = StateProvider<bool>(
  (ref) => true,
);
