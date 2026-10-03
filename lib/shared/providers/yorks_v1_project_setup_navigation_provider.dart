import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets route changes await the mounted editor's pending local write.
/// The callback owns the editor buffer; the router never reconstructs it.
class YorksV1ProjectSetupNavigationGuard {
  Future<bool> Function()? _guard;

  void register(Future<bool> Function() guard) => _guard = guard;

  void unregister(Future<bool> Function() guard) {
    if (identical(_guard, guard)) _guard = null;
  }

  Future<bool> canLeave() async {
    final guard = _guard;
    return guard == null || await guard();
  }
}

final yorksV1ProjectSetupNavigationGuardProvider =
    Provider<YorksV1ProjectSetupNavigationGuard>((ref) {
      return YorksV1ProjectSetupNavigationGuard();
    });
