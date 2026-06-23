import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/hardware/hardware_action_service.dart';
import '../core/security/session_lock.dart';
import '../core/theme/app_theme.dart';
import '../features/system/presentation/screens/lock_screen.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/role_permissions_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/services/app_config_service.dart';
import '../shared/sync/sync_engine.dart';
import 'idle_request_monitor.dart';
import 'router.dart';

/// Bridges [rolePermissionsProvider] changes to the router's refreshListenable.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Provider for the app router — lives here so the incremental
/// compiler always sees it in the same unit as [MaterialLedgerApp].
final appRouterProvider = Provider<GoRouter>((ref) {
  final isOnboarded = ref.watch(onboardingCompleteProvider);
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final role = ref.watch(currentRoleProvider);
  final user = ref.watch(currentUserProvider);
  final gate = ref.watch(appGateProvider);

  // Re-run route guards when an Admin edits role permissions — WITHOUT
  // rebuilding the router (which would reset navigation). We bridge the provider
  // to a Listenable and read it live in the redirect.
  final refresh = _RouterRefresh();
  ref.listen(rolePermissionsProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return createAppRouter(
    isOnboarded: isOnboarded,
    isLoggedIn: isLoggedIn,
    role: role,
    user: user,
    gate: gate,
    rolePermissions: () => ref.read(rolePermissionsProvider),
    refreshListenable: refresh,
  );
});

/// Maps a rugged device's physical action button (and the F5 demo key) to the
/// current role's primary action: engineers raise a New Request, office roles
/// jump to the Materials hub. Read once at launch.
final hardwareActionProvider = Provider<HardwareActionService>((ref) {
  final service = HardwareActionService(() {
    final role = ref.read(currentRoleProvider);
    final router = ref.read(appRouterProvider);
    router.go(
      role.usesAdminPanel
          ? RoutePaths.materials
          : RoutePaths.engineerNewRequest,
    );
  });
  ref.onDispose(service.dispose);
  return service;
});

/// Root application widget.
///
/// Uses [ConsumerWidget] to read the router from Riverpod,
/// which rebuilds when onboarding state changes (redirect logic).
class MaterialLedgerApp extends ConsumerWidget {
  const MaterialLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Start the sync engine at launch (heartbeat, reconnect-flush, and resume
    // of any operations queued in a previous session).
    ref.watch(syncEngineProvider);
    // Listen for the hardware action button / demo key.
    ref.watch(hardwareActionProvider);
    // Flag any request idle 24h+ to admin (FR-066) — runs once at launch.
    ref.watch(idleRequestMonitorProvider);

    return MaterialApp.router(
      title: 'Yorks GodownPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Overlay the lock screen above whatever is on screen (preserves
      // navigation), and reset the idle timer on any interaction.
      builder: (context, child) => _AppChrome(child: child),
    );
  }
}

/// Wraps the app content with the session-lock overlay + idle-interaction
/// tracking. Kept as its own ConsumerWidget so it watches lock state in its own
/// build, independent of the router rebuild.
class _AppChrome extends ConsumerWidget {
  const _AppChrome({required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(sessionLockedProvider);
    final enabled = ref.watch(appLockEnabledProvider);
    final loggedIn = ref.watch(isLoggedInProvider);
    final showLock = locked && enabled && loggedIn;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          ref.read(sessionLockedProvider.notifier).registerInteraction(),
      child: Stack(
        children: [
          child ?? const SizedBox.shrink(),
          if (showLock) const Positioned.fill(child: LockScreen()),
        ],
      ),
    );
  }
}
