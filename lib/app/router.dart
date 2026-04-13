import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/engineer/presentation/screens/engineer_browse_screen.dart';
import '../features/engineer/presentation/screens/engineer_home_screen.dart';
import '../features/engineer/presentation/screens/engineer_new_request_screen.dart';
import '../features/engineer/presentation/screens/engineer_profile_screen.dart';
import '../features/engineer/presentation/screens/request_detail_screen.dart';
import '../features/login/presentation/screens/login_screen.dart';
import '../features/inventory/presentation/screens/inventory_screen.dart';
import '../features/onboarding/presentation/screens/language_selection_screen.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';
import '../shared/screens/about_screen.dart';
import '../shared/screens/notifications_screen.dart';
import '../shared/screens/privacy_policy_screen.dart';
import '../shared/screens/terms_of_service_screen.dart';
import 'engineer_shell.dart';
import 'shell_screen.dart';

/// Route path constants
abstract final class RoutePaths {
  // ─── Onboarding & Auth ─────────────────────────────────────
  static const String splash = '/splash';
  static const String languageSelection = '/language-selection';
  static const String login = '/login';

  // ─── Engineer (default post-login) ─────────────────────────
  static const String engineerHome = '/';
  static const String engineerBrowse = '/browse';
  static const String engineerNewRequest = '/new-request';
  static const String engineerProfile = '/profile';
  static const String requestDetail = '/request/:id';

  // ─── Admin / Office (legacy — kept for future) ─────────────
  static const String dashboard = '/admin';
  static const String inventory = '/admin/inventory';
  static const String transactions = '/admin/transactions';
  static const String settings = '/admin/settings';

  // ─── Shared ─────────────────────────────────────────────────
  static const String about = '/about';
  static const String notifications = '/notifications';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
}

/// Creates the app [GoRouter].
/// [isOnboarded] and [isLoggedIn] drive redirect logic.
GoRouter createAppRouter({
  required bool isOnboarded,
  required bool isLoggedIn,
}) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final path = state.uri.path;
      final isSplashRoute = path == RoutePaths.splash;
      final isLanguageSelectionRoute = path == RoutePaths.languageSelection;
      final isLoginRoute = path == RoutePaths.login;

      // Always allow the splash screen through.
      if (isSplashRoute) return null;

      // Force onboarding first (language selection).
      if (!isOnboarded) {
        if (isLanguageSelectionRoute) return null;
        return RoutePaths.splash;
      }

      // Onboarded but not logged in -> login only.
      if (!isLoggedIn) {
        if (isLoginRoute) return null;
        return RoutePaths.login;
      }

      // Logged in users shouldn't visit onboarding/login routes.
      if (isLanguageSelectionRoute || isLoginRoute) {
        return RoutePaths.engineerHome;
      }

      return null;
    },
    routes: [
      // ─── Onboarding ──────────────────────────────────────
      GoRoute(
        path: RoutePaths.splash,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      GoRoute(
        path: RoutePaths.languageSelection,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LanguageSelectionScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),

      // ─── Auth ────────────────────────────────────────────
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),

      // ─── Engineer Shell ────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => EngineerShellScreen(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.engineerHome,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EngineerHomeScreen()),
          ),
          GoRoute(
            path: RoutePaths.engineerBrowse,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EngineerBrowseScreen()),
          ),
          GoRoute(
            path: RoutePaths.engineerNewRequest,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EngineerNewRequestScreen()),
          ),
          GoRoute(
            path: RoutePaths.engineerProfile,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EngineerProfileScreen()),
          ),
        ],
      ),

      // ─── Request Detail (outside shell — full screen) ─────
      GoRoute(
        path: RoutePaths.requestDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: RequestDetailScreen(requestId: id),
            transitionsBuilder: (context, animation, _, child) =>
                SlideTransition(
                  position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),

      // ─── About (shared — full screen) ──────────────────────
      GoRoute(
        path: RoutePaths.about,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AboutScreen(),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),

      // ─── Notifications (shared — full screen) ──────────────
      GoRoute(
        path: RoutePaths.notifications,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),

      // ─── Privacy Policy (shared — full screen) ─────────────
      GoRoute(
        path: RoutePaths.privacyPolicy,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PrivacyPolicyScreen(),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),

      // ─── Terms of Service (shared — full screen) ───────────
      GoRoute(
        path: RoutePaths.termsOfService,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TermsOfServiceScreen(),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),

      // ─── Admin/Office Shell (future) ───────────────────────
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: RoutePaths.inventory,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryScreen()),
          ),
          GoRoute(
            path: RoutePaths.transactions,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TransactionsScreen()),
          ),
          GoRoute(
            path: RoutePaths.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  );
}
