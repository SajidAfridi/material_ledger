import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/hardware/hardware_action_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/sync/sync_engine.dart';
import 'idle_request_monitor.dart';
import 'router.dart';

/// Provider for the app router — lives here so the incremental
/// compiler always sees it in the same unit as [MaterialLedgerApp].
final appRouterProvider = Provider<GoRouter>((ref) {
  final isOnboarded = ref.watch(onboardingCompleteProvider);
  final isLoggedIn = ref.watch(authSessionProvider);
  final role = ref.watch(currentRoleProvider);
  return createAppRouter(
    isOnboarded: isOnboarded,
    isLoggedIn: isLoggedIn,
    role: role,
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
    );
  }
}
