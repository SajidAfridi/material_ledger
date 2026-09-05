import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Analytics route fails closed while its rollout is off', (
    tester,
  ) async {
    final router = _router(enabled: false, permitted: true);
    addTearDown(router.dispose);
    await _mount(tester, router, enabled: false);

    router.go(RoutePaths.yorksV1Analytics);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      RoutePaths.engineerHome,
    );
  });

  testWidgets('Analytics route requires the independent view capability', (
    tester,
  ) async {
    final router = _router(enabled: true, permitted: false);
    addTearDown(router.dispose);
    await _mount(tester, router, enabled: true);

    router.go(RoutePaths.yorksV1Analytics);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      RoutePaths.engineerHome,
    );
  });

  testWidgets('delegated Analytics view opens the read-only workspace', (
    tester,
  ) async {
    final decisions = <({String key, bool organizationSummary})>[];
    final router = _router(
      enabled: true,
      resolver:
          (
            capabilityKey, {
            required legacyAllowed,
            requireWrite = false,
            organizationSummary = false,
            projectId,
          }) {
            decisions.add((
              key: capabilityKey,
              organizationSummary: organizationSummary,
            ));
            return capabilityKey == YorksV1CapabilityKeys.analyticsView;
          },
    );
    addTearDown(router.dispose);
    await _mount(tester, router, enabled: true);

    router.go(RoutePaths.yorksV1Analytics);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      RoutePaths.yorksV1Analytics,
    );
    expect(
      decisions,
      contains((
        key: YorksV1CapabilityKeys.analyticsView,
        organizationSummary: true,
      )),
    );
  });
}

GoRouter _router({
  required bool enabled,
  bool permitted = false,
  YorksV1HybridPermissionResolver? resolver,
}) => createAppRouter(
  isOnboarded: true,
  isLoggedIn: true,
  role: UserRole.admin,
  user: AppUser(
    id: 'analytics-admin',
    fullName: 'Analytics Admin',
    email: 'analytics.admin@yorks.test',
    role: UserRole.admin,
    yorksV1RoleCache: YorksV1Role.admin,
    yorksV1Roles: const [YorksV1Role.admin],
    createdAt: DateTime.utc(2026, 9, 4),
  ),
  yorksV1ProjectsEnabled: true,
  yorksV1BoqEnabled: true,
  yorksV1RequestsEnabled: true,
  yorksV1ArrangementEnabled: true,
  yorksV1LogisticsEnabled: true,
  yorksV1ReturnsDocumentsEnabled: true,
  yorksV1DocumentsEnabled: true,
  yorksV1AnalyticsEnabled: enabled,
  yorksV1Role: YorksV1Role.admin,
  yorksV1PermissionResolver:
      resolver ??
      (
        capabilityKey, {
        required legacyAllowed,
        requireWrite = false,
        organizationSummary = false,
        projectId,
      }) => capabilityKey == YorksV1CapabilityKeys.analyticsView
          ? permitted
          : true,
);

Future<void> _mount(
  WidgetTester tester,
  GoRouter router, {
  required bool enabled,
}) async {
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1FeatureFlagsProvider.overrideWithValue(
          YorksV1FeatureFlags(
            foundation: true,
            projects: true,
            boq: true,
            excel: true,
            requests: true,
            arrangement: true,
            logistics: true,
            returnsDocuments: true,
            documents: true,
            analytics: enabled,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
