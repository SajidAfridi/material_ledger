import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/features/engineer/presentation/screens/engineer_home_screen.dart';
import 'package:material_ledger/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:material_ledger/shared/models/app_strings.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';

void main() {
  testWidgets(
    'V1 project rollout hides the retained generic project dashboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(foundation: true, projects: true),
            ),
            yorksV1CurrentRoleProvider.overrideWithValue(
              YorksV1Role.projectEngineer,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: EngineerHomeScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(YorksV1ProjectStrings.newProject.primary),
        findsOneWidget,
      );
      expect(find.text(AppStrings.myProjects.primary), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'V1 office home hides retained project and procurement operations',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            currentRoleProvider.overrideWithValue(UserRole.admin),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(foundation: true, projects: true),
            ),
            yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
          ],
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(YorksV1ProjectStrings.newProject.primary),
        findsOneWidget,
      );
      expect(find.text(AppStrings.activeProjects.primary), findsNothing);
      expect(find.text(AppStrings.awaitingAction.primary), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
