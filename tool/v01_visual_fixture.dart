import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/app/yorks_v1_workspace_shell.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_project_create_flow_screen.dart';
import 'package:material_ledger/features/projects/presentation/screens/yorks_v1_projects_screen.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_project_creation_draft.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_status.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_project_portfolio_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic browser fixture for the V01 screenshot-convergence pass.
///
/// This target composes the production presentation widgets above their
/// existing providers while replacing only identity and authorized read
/// projections. It performs no Supabase, repository, RPC or workflow writes.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final initialLocation =
      Uri.base.queryParameters['surface'] == 'project-create'
      ? RoutePaths.engineerCreateProject
      : RoutePaths.engineerHome;
  final user = AppUser(
    id: 'v01-omar-farooq',
    fullName: 'Omar Farooq',
    email: 'omar.farooq@yorks.com',
    role: UserRole.engineer,
    yorksV1RoleCache: YorksV1Role.projectEngineer,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  final referenceDraft = YorksV1ProjectCreationDraft(
    ownerAuthUserId: user.id,
    currentStage: YorksV1ProjectCreationStage.projectDetails,
    creationIdempotencyKey: 'v01-visual-reference-draft',
    reference: 'YRA-',
    name: '',
    startDate: DateTime.utc(2026, 8, 8),
    updatedAt: DateTime.utc(2026, 8, 8),
  );
  // The screenshot target is deliberately deterministic and local-only. Seed
  // the same visible form state as R38 without issuing a repository or RPC
  // command or changing the production draft controller.
  await preferences.setString(
    'yorks_v1_project_creation_draft_v1_${user.id}',
    jsonEncode([referenceDraft.toJson()]),
  );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.engineerHome,
        builder: (_, _) =>
            const YorksV1WorkspaceShell(child: YorksV1OverviewScreen()),
      ),
      GoRoute(
        path: RoutePaths.engineerCreateProject,
        builder: (_, _) => const YorksV1WorkspaceShell(
          child: YorksV1ProjectCreateFlowScreen(),
        ),
      ),
    ],
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        currentUserProvider.overrideWithValue(user),
        yorksV1AuthUserIdProvider.overrideWithValue(user.id),
        yorksV1CurrentRoleProvider.overrideWithValue(
          YorksV1Role.projectEngineer,
        ),
        yorksV1WorkspaceStatusProvider.overrideWithValue(
          const YorksV1WorkspaceStatus(
            state: YorksV1WorkspaceConnectionState.connected,
          ),
        ),
        yorksV1ProjectPortfolioProvider.overrideWith((ref) async => []),
        yorksV1MaterialRequestListProvider(
          null,
        ).overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
}
