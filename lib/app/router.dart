import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/constants.dart';

import '../features/admin/presentation/screens/access_roles_screen.dart';
import '../features/admin/presentation/screens/admin_projects_screen.dart';
import '../features/admin/presentation/screens/admin_requests_screen.dart';
import '../features/admin/presentation/screens/data_sync_screen.dart';
import '../features/admin/presentation/screens/more_hub_screen.dart';
import '../features/admin/presentation/screens/user_management_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/engineer/presentation/screens/engineer_browse_screen.dart';
import '../features/engineer/presentation/screens/engineer_create_project_screen.dart';
import '../features/engineer/presentation/screens/engineer_home_screen.dart';
import '../features/engineer/presentation/screens/engineer_new_request_screen.dart';
import '../features/engineer/presentation/screens/engineer_projects_screen.dart';
import '../features/engineer/presentation/screens/engineer_profile_screen.dart';
import '../features/engineer/presentation/screens/material_picker_screen.dart';
import '../features/engineer/presentation/screens/confirm_receipt_screen.dart';
import '../features/engineer/presentation/screens/employee_detail_screen.dart';
import '../features/engineer/presentation/screens/plan_build_screen.dart';
import '../features/engineer/presentation/screens/plan_diff_screen.dart';
import '../features/engineer/presentation/screens/plan_review_screen.dart';
import '../features/engineer/presentation/screens/request_detail_screen.dart';
import '../features/engineer/presentation/screens/requests_list_screen.dart';
import '../features/engineer/presentation/screens/return_screen.dart';
import '../features/login/presentation/screens/change_password_screen.dart';
import '../features/login/presentation/screens/login_screen.dart';
import '../features/system/presentation/screens/gate_screens.dart';
import '../features/finance/presentation/screens/finance_screen.dart';
import '../features/inventory/presentation/screens/goods_receipt_screen.dart';
import '../features/inventory/presentation/screens/inventory_screen.dart';
import '../features/materials/presentation/screens/materials_hub_screen.dart';
import '../features/onboarding/presentation/screens/language_selection_screen.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/people/presentation/screens/employee_profile_screen.dart';
import '../features/people/presentation/screens/people_dashboard_screen.dart';
import '../features/procurement/presentation/screens/procurement_dispatch_screen.dart';
import '../features/procurement/presentation/screens/procurement_plan_review_screen.dart';
import '../features/procurement/presentation/screens/procurement_workspace_screen.dart';
import '../features/rentals/presentation/screens/rental_unit_detail_screen.dart';
import '../features/rentals/presentation/screens/rentals_dashboard_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';
import '../shared/models/app_config.dart';
import '../shared/models/app_user.dart';
import '../shared/models/role_permissions.dart';
import '../shared/models/user_role.dart';
import '../shared/screens/about_screen.dart';
import '../shared/screens/activity_log_screen.dart';
import '../shared/screens/notifications_screen.dart';
import '../shared/screens/privacy_policy_screen.dart';
import '../shared/screens/terms_of_service_screen.dart';
import 'app_shell.dart';
import 'engineer_shell.dart';

/// Route path constants
abstract final class RoutePaths {
  // ─── Onboarding & Auth ─────────────────────────────────────
  static const String splash = '/splash';
  static const String languageSelection = '/language-selection';
  static const String login = '/login';
  static const String changePassword = '/change-password';
  static const String updateRequired = '/update-required';
  static const String maintenance = '/maintenance';

  // ─── Tab roots (StatefulShellRoute branches) ───────────────
  static const String engineerHome = '/'; // Home (role-aware dashboard)
  static const String materials = '/materials'; // Materials hub
  static const String rentals = '/rentals'; // Rentals hub
  static const String people = '/people'; // People hub
  static const String more = '/more'; // Admin · settings hub
  /// Office home alias (kept for older call sites; Home is unified at root).
  static const String dashboard = '/';

  // ─── Materials flows (full-screen, reached from the hub/Home) ─
  static const String engineerBrowse = '/browse';
  static const String engineerProjects = '/projects';
  static const String engineerCreateProject = '/projects/new';
  static const String engineerProjectsView = '/my-projects';
  static const String engineerNewRequest = '/new-request';
  static const String engineerPickMaterials = '/pick-materials';
  static const String engineerProfile = '/profile';
  static const String requestDetail = '/request/:id';
  static const String requests = '/requests';
  static const String employeeDetail = '/me';
  static const String planReview = '/plan/:id';
  static const String planBuild = '/plan-build/:id';
  static const String planDiff = '/plan-diff/:id';
  static const String confirmReceipt = '/receipt/:id';
  static const String returnStore = '/return';

  static String planReviewPath(String projectId) => '/plan/$projectId';
  static String planBuildPath(String projectId) => '/plan-build/$projectId';
  static String planDiffPath(String projectId) => '/plan-diff/$projectId';
  static String confirmReceiptPath(String requestId) => '/receipt/$requestId';
  static String requestDetailPath(String requestId) => '/request/$requestId';

  // ─── Office / admin screens (full-screen, reached from hubs) ─
  static const String inventory = '/admin/inventory';
  static const String transactions = '/admin/transactions';
  static const String settings = '/admin/settings';
  static const String goodsReceipt = '/admin/goods-receipt';
  static const String finance = '/admin/finance';
  static const String adminPanel = '/admin/panel'; // legacy → redirects to /more
  static const String adminProjects = '/admin/projects';
  static const String adminRequests = '/admin/requests';
  static const String users = '/admin/users';
  static const String accessRoles = '/access-roles';
  static const String dataSync = '/data-sync';
  static const String procurement = '/admin/procurement';
  static const String planReviewProcurement = '/admin/plan-review/:id';
  static const String dispatch = '/admin/dispatch/:id';

  static String planReviewProcurementPath(String projectId) =>
      '/admin/plan-review/$projectId';
  static String dispatchPath(String requestId) => '/admin/dispatch/$requestId';

  // ─── Rentals / People details ───────────────────────────────
  static const String rentalUnit = '/rentals/:id';
  static String rentalUnitPath(String unitId) => '/rentals/$unitId';
  static const String employeeProfile = '/people/:id';
  static String employeeProfilePath(String employeeId) => '/people/$employeeId';

  // ─── Shared ─────────────────────────────────────────────────
  static const String about = '/about';
  static const String activityLog = '/activity';
  static const String notifications = '/notifications';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
}

// ─── Page transition helpers (keep route definitions terse) ──────────
Page<void> _fade(LocalKey key, Widget child, {int ms = 300}) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, _, c) =>
          FadeTransition(opacity: animation, child: c),
      transitionDuration: Duration(milliseconds: ms),
    );

Page<void> _slide(LocalKey key, Widget child, {Offset begin = const Offset(1, 0)}) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, _, c) => SlideTransition(
        position: Tween(begin: begin, end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: c,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );

/// Slide-in page for screens that were originally office-shell *tabs* and so
/// have no `Scaffold`/`Material` of their own. When reached as a full-screen
/// route from a hub we wrap them in a slim Scaffold so they get a Material
/// ancestor and an automatic back button.
Page<void> _framed(LocalKey key, Widget child) => _slide(
      key,
      Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 48,
        ),
        body: child,
      ),
    );

/// Routes open to a [UserRole]. The in-app half of role-based access control
/// (the Firestore Security Rules enforce the same server-side).
bool _isAllowedForRole(
  String path,
  UserRole role,
  AppUser? user,
  RolePermissions perms,
) {
  // Grantable boundaries resolve through: per-user override → editable role
  // default (Access & Roles matrix) → built-in baseline.
  final canReceiveGoods =
      resolveCapability(user, role, perms, RoleCapability.goods);
  final canViewFinance =
      resolveCapability(user, role, perms, RoleCapability.finance);
  final canAccessRentals =
      resolveCapability(user, role, perms, RoleCapability.rentals);
  final canAccessPeople =
      resolveCapability(user, role, perms, RoleCapability.people);

  // Reached from the profile menu / shared across every role.
  const sharedAll = {
    RoutePaths.engineerHome,
    RoutePaths.settings,
    RoutePaths.about,
    RoutePaths.notifications,
    RoutePaths.activityLog,
    RoutePaths.privacyPolicy,
    RoutePaths.termsOfService,
    RoutePaths.employeeDetail,
    RoutePaths.engineerProfile,
  };
  if (sharedAll.contains(path)) return true;

  // Materials hub is an office tab; engineers use their own Browse instead.
  if (path == RoutePaths.materials) return role.usesAdminPanel;

  // Admin-only: the More hub + administration screens + admin oversight.
  if (path == RoutePaths.more ||
      path == RoutePaths.users ||
      path == RoutePaths.accessRoles ||
      path == RoutePaths.dataSync ||
      path == RoutePaths.adminProjects ||
      path == RoutePaths.adminRequests) {
    return role.isAdmin;
  }
  if (path == RoutePaths.goodsReceipt) return canReceiveGoods;
  if (path == RoutePaths.finance) return canViewFinance;

  // Modules with their own tab + detail screens.
  if (path.startsWith('/rentals')) return canAccessRentals;
  if (path.startsWith('/people')) return canAccessPeople;

  // Remaining office screens (inventory, transactions, procurement, dispatch,
  // plan-review) — non-engineer roles only.
  if (path == RoutePaths.inventory ||
      path == RoutePaths.transactions ||
      path == RoutePaths.procurement ||
      path.startsWith('/admin/')) {
    return role.usesAdminPanel;
  }

  // Engineer materials flows (browse, projects, new-request, request/:id,
  // requests, receipt/:id, return, plan*) + anything else → all roles.
  return true;
}

/// Creates the app [GoRouter].
/// [isOnboarded], [isLoggedIn], [role] and [user] drive redirect / access logic.
GoRouter createAppRouter({
  required bool isOnboarded,
  required bool isLoggedIn,
  required UserRole role,
  AppUser? user,
  AppGate gate = AppGate.none,
  // Live editable role-permission defaults. A getter (not a snapshot) + the
  // [refreshListenable] let route guards re-evaluate the moment an Admin edits
  // the matrix, WITHOUT rebuilding the router (no nav reset).
  RolePermissions Function()? rolePermissions,
  Listenable? refreshListenable,
}) {
  // Engineers keep their original mobile shell; office roles use the new hub
  // shell. The router is rebuilt whenever the role changes.
  final useEngineerShell = !role.usesAdminPanel;
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;

      if (path == RoutePaths.splash) return null;

      // Hard global gates block everything (incl. login) until cleared.
      if (gate == AppGate.updateRequired) {
        return path == RoutePaths.updateRequired
            ? null
            : RoutePaths.updateRequired;
      }
      if (gate == AppGate.maintenance) {
        return path == RoutePaths.maintenance ? null : RoutePaths.maintenance;
      }
      // Gate cleared but still sitting on a gate screen → move on.
      if (path == RoutePaths.updateRequired ||
          path == RoutePaths.maintenance) {
        return RoutePaths.engineerHome;
      }

      // Force onboarding first (language selection).
      if (!isOnboarded) {
        return path == RoutePaths.languageSelection
            ? null
            : RoutePaths.splash;
      }

      // Onboarded but not logged in -> login only.
      if (!isLoggedIn) {
        return path == RoutePaths.login ? null : RoutePaths.login;
      }

      // Logged-in users shouldn't sit on onboarding/login — land at Home.
      if (path == RoutePaths.languageSelection || path == RoutePaths.login) {
        return RoutePaths.engineerHome;
      }

      // Force a password change for admin-created / reset accounts before they
      // can use anything else.
      if (user != null && user.mustChangePassword) {
        return path == RoutePaths.changePassword
            ? null
            : RoutePaths.changePassword;
      }
      if (path == RoutePaths.changePassword) {
        return RoutePaths.engineerHome; // nothing to change → leave
      }

      // Retire the old hub locations.
      if (path == '/admin') return RoutePaths.engineerHome;
      if (path == RoutePaths.adminPanel) {
        return role.isAdmin ? RoutePaths.more : RoutePaths.engineerHome;
      }

      // Role-based access guard for module routes → Home if not allowed.
      final perms =
          rolePermissions?.call() ?? RolePermissions.fromRoleDefaults();
      if (!_isAllowedForRole(path, role, user, perms)) {
        return RoutePaths.engineerHome;
      }

      return null;
    },
    routes: [
      // ─── Onboarding & Auth (outside the shell) ────────────
      GoRoute(
        path: RoutePaths.splash,
        pageBuilder: (context, state) =>
            _fade(state.pageKey, const SplashScreen(), ms: 400),
      ),
      GoRoute(
        path: RoutePaths.languageSelection,
        pageBuilder: (context, state) =>
            _fade(state.pageKey, const LanguageSelectionScreen(), ms: 500),
      ),
      GoRoute(
        path: RoutePaths.changePassword,
        pageBuilder: (context, state) =>
            _fade(state.pageKey, const ChangePasswordScreen(), ms: 300),
      ),
      GoRoute(
        path: RoutePaths.updateRequired,
        pageBuilder: (context, state) =>
            _fade(state.pageKey, const UpdateRequiredScreen(), ms: 300),
      ),
      GoRoute(
        path: RoutePaths.maintenance,
        pageBuilder: (context, state) =>
            _fade(state.pageKey, const MaintenanceScreen(), ms: 300),
      ),
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (context, state) =>
            _fade(state.pageKey, const LoginScreen(), ms: 350),
      ),

      // ─── Role shell ───────────────────────────────────────
      // Engineers keep their original 4-tab mobile shell (Home · Browse ·
      // Projects · Profile + New Request); office roles get the role-aware
      // hub shell (Home · Materials · Rentals · People · More).
      if (useEngineerShell)
        // Engineer: 4 state-preserving branches. Non-tab flows (New Request,
        // Create Project) are nested so the bottom bar stays visible AND their
        // typed input survives tab switches (IndexedStack keeps branches alive).
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              EngineerShellScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.engineerHome,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: EngineerHomeScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.engineerBrowse,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: EngineerBrowseScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.engineerProjects,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: EngineerProjectsScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.engineerProfile,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: EngineerProfileScreen()),
                ),
              ],
            ),
            // 5th branch (no visible tab) — New Request lives INSIDE the shell so
            // the bottom bar stays visible and the in-progress draft survives tab
            // switches (IndexedStack keeps it mounted). Reached via the centre
            // "+" FAB / rail button (goBranch), not a tab.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.engineerNewRequest,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: EngineerNewRequestScreen()),
                ),
              ],
            ),
          ],
        )
      else
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.engineerHome,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: DashboardScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.materials,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: MaterialsHubScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.rentals,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: RentalsDashboardScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.people,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: PeopleDashboardScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.more,
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: MoreHubScreen()),
                ),
              ],
            ),
          ],
        ),

      // Office roles reach the account/settings screen via the Home avatar menu
      // (engineers have it as their Profile tab). Same screen for consistency.
      if (!useEngineerShell)
        GoRoute(
          path: RoutePaths.engineerProfile,
          pageBuilder: (context, state) =>
              _framed(state.pageKey, const EngineerProfileScreen()),
        ),

      // ─── Engineer create-flows (full-screen over the shell) ─────────
      // Create Project overlays the shell with its own back; New Request now
      // lives INSIDE the shell as a branch (see above), so it's not here.
      GoRoute(
        path: RoutePaths.engineerCreateProject,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const EngineerCreateProjectScreen()),
      ),
      // Standalone projects view (reached from the profile quick links) — the
      // tab screen has no Scaffold of its own, so frame it for a back button.
      GoRoute(
        path: RoutePaths.engineerProjectsView,
        pageBuilder: (context, state) =>
            _framed(state.pageKey, const EngineerProjectsScreen()),
      ),

      // ─── Shared detail/workflow screens (full-screen, all roles) ─────
      // Material picker — pushed ON TOP of the New Request screen so the
      // engineer adds inventory + custom items, then returns to the request.
      GoRoute(
        path: RoutePaths.engineerPickMaterials,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const MaterialPickerScreen()),
      ),
      GoRoute(
        path: RoutePaths.requestDetail,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          RequestDetailScreen(requestId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.requests,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          RequestsListScreen(projectName: state.extra as String?),
        ),
      ),
      GoRoute(
        path: RoutePaths.planReview,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          PlanReviewScreen(projectId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.planBuild,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          PlanBuildScreen(projectId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.planDiff,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          PlanDiffScreen(projectId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.confirmReceipt,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          ConfirmReceiptScreen(requestId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.returnStore,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          ReturnScreen(initialProjectName: state.extra as String?),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeDetail,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const EmployeeDetailScreen()),
      ),

      // ─── Office / admin screens (full-screen over the shell) ─
      GoRoute(
        path: RoutePaths.inventory,
        pageBuilder: (context, state) =>
            _framed(state.pageKey, const InventoryScreen()),
      ),
      GoRoute(
        path: RoutePaths.transactions,
        pageBuilder: (context, state) =>
            _framed(state.pageKey, const TransactionsScreen()),
      ),
      GoRoute(
        path: RoutePaths.settings,
        pageBuilder: (context, state) =>
            _framed(state.pageKey, const SettingsScreen()),
      ),
      GoRoute(
        path: RoutePaths.goodsReceipt,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const GoodsReceiptScreen()),
      ),
      GoRoute(
        path: RoutePaths.finance,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const FinanceScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminProjects,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const AdminProjectsScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminRequests,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const AdminRequestsScreen()),
      ),
      GoRoute(
        path: RoutePaths.users,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const UserManagementScreen()),
      ),
      GoRoute(
        path: RoutePaths.accessRoles,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const AccessRolesScreen()),
      ),
      GoRoute(
        path: RoutePaths.dataSync,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const DataSyncScreen()),
      ),
      GoRoute(
        path: RoutePaths.procurement,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const ProcurementWorkspaceScreen()),
      ),
      GoRoute(
        path: RoutePaths.planReviewProcurement,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          ProcurementPlanReviewScreen(projectId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.dispatch,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          ProcurementDispatchScreen(requestId: state.pathParameters['id'] ?? ''),
        ),
      ),

      // ─── Rentals / People details (full-screen) ───────────
      GoRoute(
        path: RoutePaths.rentalUnit,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          RentalUnitDetailScreen(unitId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeProfile,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          EmployeeProfileScreen(employeeId: state.pathParameters['id'] ?? ''),
        ),
      ),

      // ─── Shared (full-screen) ─────────────────────────────
      GoRoute(
        path: RoutePaths.about,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const AboutScreen()),
      ),
      GoRoute(
        path: RoutePaths.activityLog,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const ActivityLogScreen()),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        pageBuilder: (context, state) => _slide(
          state.pageKey,
          const NotificationsScreen(),
          begin: const Offset(0, 1),
        ),
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: RoutePaths.termsOfService,
        pageBuilder: (context, state) =>
            _slide(state.pageKey, const TermsOfServiceScreen()),
      ),
    ],
  );
}
