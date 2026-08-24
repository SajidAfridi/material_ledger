import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/hardware/hardware_action_service.dart';
import '../core/security/session_lock.dart';
import '../core/scroll/yorks_scroll_behavior.dart';
import '../core/theme/app_theme.dart';
import '../features/system/presentation/screens/lock_screen.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/material_request_provider.dart';
import '../shared/providers/role_permissions_provider.dart';
import '../shared/providers/session_provider.dart';
import '../shared/providers/yorks_v1_arrangement_provider.dart';
import '../shared/providers/yorks_v1_boq_provider.dart';
import '../shared/providers/yorks_v1_documents_provider.dart';
import '../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../shared/providers/yorks_v1_identity_provider.dart';
import '../shared/providers/yorks_v1_logistics_provider.dart';
import '../shared/providers/yorks_v1_material_request_provider.dart';
import '../shared/providers/yorks_v1_notification_provider.dart';
import '../shared/providers/yorks_v1_permission_provider.dart';
import '../shared/providers/yorks_v1_project_portfolio_provider.dart';
import '../shared/services/app_config_service.dart';
import '../shared/sync/realtime_sync.dart';
import '../shared/sync/sync_engine.dart';
import '../shared/widgets/notification_alert_host.dart';
import '../shared/widgets/notification_attention_host.dart';
import 'document_expiry_monitor.dart';
import 'idle_request_monitor.dart';
import 'push_bridge.dart';
import 'router.dart';

/// Bridges [rolePermissionsProvider] changes to the router's refreshListenable.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

void _invalidateYorksV1ProtectedProjectionCaches(Ref ref) {
  // A permission revision is a refresh signal, never a row-level transaction.
  // Destroy each protected cache so a revoked project/request cannot remain in
  // memory while the same actor retains access to other projects.
  ref.invalidate(yorksV1ProjectPortfolioProvider);
  ref.invalidate(yorksV1BoqGroupsProvider);
  ref.invalidate(yorksV1ScopedBoqGroupsProvider);
  ref.invalidate(yorksV1BoqWorksheetControllerProvider);
  ref.invalidate(yorksV1DocumentWorkspaceProvider);
  ref.invalidate(yorksV1MaterialRequestSummaryPageProvider);
  ref.invalidate(yorksV1MaterialRequestCommentPageProvider);
  ref.invalidate(yorksV1MaterialRequestWorkAssignmentProvider);
  ref.invalidate(yorksV1MaterialRequestChangeSummaryProvider);
  ref.invalidate(yorksV1MaterialRequestListProvider);
  ref.invalidate(yorksV1MaterialRequestDraftProjectsProvider);
  ref.invalidate(yorksV1MaterialRequestScopesProvider);
  ref.invalidate(yorksV1MaterialRequestMentionCandidatesProvider);
  ref.invalidate(yorksV1MaterialRequestInventorySearchProvider);
  ref.invalidate(yorksV1MaterialRequestDetailProvider);
  ref.invalidate(yorksV1MaterialRequestPhase3PolicyProvider);
  ref.invalidate(yorksV1MaterialRequestDocumentProvider);
  ref.invalidate(yorksV1ArrangementWorkspaceProvider);
  ref.invalidate(yorksV1ArrangementInventoryProvider);
  ref.invalidate(yorksV1LogisticsWorkspaceProvider);
  ref.invalidate(yorksV1ProjectMaterialMovementsProvider);
  ref.invalidate(yorksV1ReturnsDocumentsWorkspaceProvider);
  ref.invalidate(yorksV1MaterialReturnRegisterProvider);
  ref.invalidate(yorksV1MaterialReturnProjectsProvider);
  ref.invalidate(yorksV1ProjectMaterialReturnProvider);
  ref.invalidate(yorksV1MaterialReturnCreationWorkspaceProvider);
}

/// Provider for the app router — lives here so the incremental
/// compiler always sees it in the same unit as [MaterialLedgerApp].
final appRouterProvider = Provider<GoRouter>((ref) {
  final isOnboarded = ref.watch(onboardingCompleteProvider);
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final role = ref.watch(currentRoleProvider);
  // The Admin directory is presentation data. A roster refresh may replace
  // names, emails or other users, but must not reconstruct GoRouter and throw
  // away the current location. Observe only fields that route guards actually
  // consume, then read the matching user snapshot when one of those fields
  // changes.
  ref.watch(
    currentUserProvider.select(
      (user) => user == null
          ? null
          : (
              id: user.id,
              role: user.role,
              active: user.active,
              mustChangePassword: user.mustChangePassword,
              canSeeCost: user.canSeeCostOverride,
              canViewFinance: user.canViewFinanceOverride,
              canSeeSalary: user.canSeeSalaryOverride,
              canAccessRentals: user.canAccessRentalsOverride,
              canAccessPeople: user.canAccessPeopleOverride,
              canReceiveGoods: user.canReceiveGoodsOverride,
            ),
    ),
  );
  final user = ref.read(currentUserProvider);
  final gate = ref.watch(appGateProvider);
  final yorksV1ProjectsEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .projects;
  final yorksV1BoqEnabled = ref.watch(yorksV1FeatureFlagsProvider).boq;
  final yorksV1RequestsEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .requests;
  final yorksV1ArrangementEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .arrangement;
  final yorksV1LogisticsEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .logistics;
  final yorksV1ReturnsDocumentsEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .returnsDocuments;
  final yorksV1DocumentsEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .documents;
  final yorksV1TeamChatEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .teamChat;
  final yorksV1InventorySuppliersEnabled = ref
      .watch(yorksV1FeatureFlagsProvider)
      .inventorySuppliers;
  final yorksV1Role = ref.watch(yorksV1CurrentRoleProvider);
  final connectedV1Permissions =
      yorksV1ProjectsEnabled && ref.watch(supabaseClientProvider) != null;

  // Re-run route guards when an Admin edits role permissions — WITHOUT
  // rebuilding the router (which would reset navigation). We bridge the provider
  // to a Listenable and read it live in the redirect.
  final refresh = _RouterRefresh();
  ref.listen(rolePermissionsProvider, (_, _) => refresh.ping());
  ref.listen(yorksV1CurrentPermissionSnapshotProvider, (previous, next) {
    refresh.ping();
    final previousSnapshot = previous?.snapshot;
    if (previousSnapshot == null) return;
    final nextSnapshot = next.snapshot;
    if (nextSnapshot == null ||
        nextSnapshot.revision != previousSnapshot.revision) {
      _invalidateYorksV1ProtectedProjectionCaches(ref);
    }
  });
  ref.onDispose(refresh.dispose);

  final router = createAppRouter(
    isOnboarded: isOnboarded,
    isLoggedIn: isLoggedIn,
    role: role,
    user: user,
    gate: gate,
    yorksV1ProjectsEnabled: yorksV1ProjectsEnabled,
    yorksV1BoqEnabled: yorksV1BoqEnabled,
    yorksV1RequestsEnabled: yorksV1RequestsEnabled,
    yorksV1ArrangementEnabled: yorksV1ArrangementEnabled,
    yorksV1LogisticsEnabled: yorksV1LogisticsEnabled,
    yorksV1ReturnsDocumentsEnabled: yorksV1ReturnsDocumentsEnabled,
    yorksV1DocumentsEnabled: yorksV1DocumentsEnabled,
    yorksV1TeamChatEnabled: yorksV1TeamChatEnabled,
    yorksV1InventorySuppliersEnabled: yorksV1InventorySuppliersEnabled,
    yorksV1Role: yorksV1Role,
    yorksV1PermissionResolver: connectedV1Permissions
        ? (
            capabilityKey, {
            required legacyAllowed,
            requireWrite = false,
            organizationSummary = false,
            projectId,
          }) => ref
              .read(yorksV1CurrentPermissionSnapshotProvider)
              .hybridRouteAllows(
                capabilityKey,
                legacyAllowed: legacyAllowed,
                requireWrite: requireWrite,
                organizationSummary: organizationSummary,
                projectId: projectId,
              )
        : null,
    rolePermissions: () => ref.read(rolePermissionsProvider),
    refreshListenable: refresh,
  );
  ref.onDispose(router.dispose);
  return router;
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
    // Keep the local compatibility shell synchronized with Supabase Auth. This
    // verifies restored sessions, clears remote sign-outs and re-reads exact
    // role claims after token refresh before route guards run on stale state.
    ref.watch(authSessionLifecycleProvider);
    final router = ref.watch(appRouterProvider);
    // Start the sync engine at launch (heartbeat, reconnect-flush, and resume
    // of any operations queued in a previous session).
    ref.watch(syncEngineProvider);
    // Live sync: subscribe to Postgres changes while signed in (no-op offline /
    // logged out / in tests) so other devices' writes appear without a relaunch.
    ref.watch(realtimeSyncProvider);
    // Keep inventory reservations reconciled with open requests (self-healing:
    // fixes seed under-reservation, missed releases, and cross-device edits).
    ref.watch(inventoryReconcilerProvider);
    // Listen for the hardware action button / demo key.
    ref.watch(hardwareActionProvider);
    // Flag any request idle 24h+ to admin (FR-066) — runs once at launch.
    ref.watch(idleRequestMonitorProvider);
    // Flag any employee visa/Emirates-ID/passport expiring within 30 days.
    ref.watch(documentExpiryMonitorProvider);
    // Register this device for push whenever the signed-in user changes.
    ref.watch(pushBridgeProvider);
    // Mount the recipient-scoped normalized notification feed globally. This
    // powers the badge/centre and provides a polling fallback if Realtime is
    // temporarily unavailable.
    ref.watch(yorksV1NotificationsProvider);

    return MaterialApp.router(
      title: 'Yorks AC. & Ref.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      scrollBehavior: const YorksScrollBehavior(),
      // Overlay the lock screen above whatever is on screen (preserves
      // navigation), and reset the idle timer on any interaction.
      builder: (context, child) => NotificationAttentionHost(
        child: _AppChrome(
          child: NotificationAlertHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Overlays the session-lock screen above the app content. Kept as its own
/// ConsumerWidget so it watches lock state in its own build, independent of the
/// router rebuild. The lock only ever appears on a cold start (see
/// [SessionLockController]); it never triggers on resume from background.
class _AppChrome extends ConsumerWidget {
  const _AppChrome({required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(sessionLockedProvider);
    final enabled = ref.watch(appLockEnabledProvider);
    final loggedIn = ref.watch(isLoggedInProvider);
    final showLock = locked && enabled && loggedIn;

    return Stack(
      children: [
        child ?? const SizedBox.shrink(),
        if (showLock) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
