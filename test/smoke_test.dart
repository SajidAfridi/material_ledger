import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/core/widgets/widgets.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/rental_unit.dart';
import 'package:material_ledger/shared/models/role_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/project_provider.dart';
import 'package:material_ledger/shared/providers/rentals_provider.dart';
import 'package:material_ledger/shared/providers/role_permissions_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/services/observability_service.dart';
import 'package:material_ledger/shared/services/app_config_service.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:material_ledger/shared/sync/outbox.dart';
import 'package:material_ledger/shared/sync/sync_backend.dart';
import 'package:material_ledger/shared/sync/sync_engine.dart';

// Screens / widgets under smoke test.
import 'package:material_ledger/features/engineer/presentation/screens/engineer_create_project_screen.dart';
import 'package:material_ledger/features/engineer/presentation/screens/engineer_projects_screen.dart';
import 'package:material_ledger/features/engineer/presentation/screens/engineer_home_screen.dart';
import 'package:material_ledger/features/engineer/presentation/screens/engineer_profile_screen.dart';
import 'package:material_ledger/features/admin/presentation/screens/access_roles_screen.dart';
import 'package:material_ledger/features/admin/presentation/screens/user_management_screen.dart';
import 'package:material_ledger/features/admin/presentation/screens/admin_projects_screen.dart';
import 'package:material_ledger/features/admin/presentation/screens/admin_requests_screen.dart';
import 'package:material_ledger/features/rentals/presentation/screens/rentals_dashboard_screen.dart';
import 'package:material_ledger/features/rentals/presentation/widgets/record_payment_sheet.dart';
import 'package:material_ledger/features/leave/presentation/screens/my_leave_screen.dart';
import 'package:material_ledger/features/leave/presentation/screens/leave_requests_screen.dart';
import 'package:material_ledger/features/people/presentation/screens/people_dashboard_screen.dart';
import 'package:material_ledger/features/procurement/presentation/screens/procurement_workspace_screen.dart';
import 'package:material_ledger/shared/screens/activity_log_screen.dart';

const _testLocalPassword = 'test-only-local-password';

Future<ProviderContainer> _container({String? email}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appVersionProvider.overrideWithValue(
        const AppVersionInfo(version: '1.0.0', build: 1),
      ),
      localDemoPasswordProvider.overrideWithValue(_testLocalPassword),
      observabilityProvider.overrideWithValue(const NoopObservability()),
      // Construct the sync engine WITHOUT start() so no periodic timer leaks
      // into the widget test when a screen triggers a write (enqueueSync).
      syncEngineProvider.overrideWith((ref) {
        final e = SyncEngine(
          backend: ref.watch(syncBackendProvider),
          outbox: ref.watch(outboxProvider.notifier),
          connectivity: ref.watch(connectivityProvider),
        );
        ref.onDispose(e.dispose);
        return e;
      }),
    ],
  );
  addTearDown(c.dispose);
  if (email != null) {
    await c
        .read(authControllerProvider)
        .signIn(email: email, password: _testLocalPassword);
  }
  return c;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer c,
  Widget screen,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Render [screen] signed in as [email] and assert nothing threw during build.
Future<void> _smoke(
  WidgetTester tester,
  Widget screen, {
  required String email,
}) async {
  final c = await _container(email: email);
  await _pump(tester, c, screen);
  expect(tester.takeException(), isNull);
}

const _eng = 'imrankhan@gmail.com';
const _owner = 'owner@gmail.com';
const _proc = 'alasad@gmail.com';

void main() {
  group('Engineer screens render', () {
    testWidgets('Create project (Scaffold + job register)', (t) async {
      await _smoke(t, const EngineerCreateProjectScreen(), email: _eng);
      expect(find.text('Job register'), findsOneWidget);
    });
    testWidgets('Projects list', (t) async {
      await _smoke(t, const EngineerProjectsScreen(), email: _eng);
    });
    testWidgets('Home dashboard', (t) async {
      await _smoke(t, const EngineerHomeScreen(), email: _eng);
    });
    testWidgets('My Leave', (t) async {
      await _smoke(t, const MyLeaveScreen(), email: _eng);
    });
  });

  group('Office / admin screens render', () {
    testWidgets('Access & Roles matrix', (t) async {
      await _smoke(t, const AccessRolesScreen(), email: _owner);
      expect(find.text('Approve leave'), findsOneWidget);
    });
    testWidgets('User management', (t) async {
      await _smoke(t, const UserManagementScreen(), email: _owner);
    });
    testWidgets('Configuration profile', (t) async {
      await _smoke(t, const EngineerProfileScreen(), email: _owner);
    });
    testWidgets('Audit activity', (t) async {
      await _smoke(t, const ActivityLogScreen(), email: _owner);
    });
    testWidgets('Admin projects (job register + value)', (t) async {
      await _smoke(t, const AdminProjectsScreen(), email: _owner);
    });
    testWidgets('Admin requests (search + status filter)', (t) async {
      await _smoke(t, const AdminRequestsScreen(), email: _owner);
      // Status filter chips render.
      expect(find.text('On hold'), findsOneWidget);
    });
    testWidgets('Rentals dashboard', (t) async {
      await _smoke(t, const RentalsDashboardScreen(), email: _owner);
    });
    testWidgets('Leave approvals', (t) async {
      await _smoke(t, const LeaveRequestsScreen(), email: _owner);
    });
    testWidgets('People / HR dashboard', (t) async {
      await _smoke(t, const PeopleDashboardScreen(), email: _proc);
    });
    testWidgets('Procurement workspace', (t) async {
      await _smoke(t, const ProcurementWorkspaceScreen(), email: _proc);
      expect(find.text('New projects'), findsOneWidget);
    });
  });

  group('Procurement — project acceptance', () {
    testWidgets('accepting a new project removes it from the queue', (t) async {
      final c = await _container(email: _proc);
      c
          .read(projectsProvider.notifier)
          .addProject(
            const Project(
              id: 'proj-smoke-accept',
              name: 'Smoke Test Tower',
              nameSecondary: '',
            ),
          );
      await _pump(t, c, const ProcurementWorkspaceScreen());

      expect(find.text('Smoke Test Tower'), findsOneWidget);
      expect(
        c
            .read(projectsProvider.notifier)
            .byId('proj-smoke-accept')!
            .acceptedByProcurement,
        false,
      );

      await t.tap(find.text('Accept project'));
      await t.pumpAndSettle();
      // Confirm dialog — its own button carries the same "Accept project" label
      // as the trailing card button, so target it via the dialog role.
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Accept project'),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(
        c
            .read(projectsProvider.notifier)
            .byId('proj-smoke-accept')!
            .acceptedByProcurement,
        true,
      );
      expect(find.text('Smoke Test Tower'), findsNothing);
    });
  });

  group('Record-payment sheet', () {
    testWidgets('renders + blocks overpayment via the UI validator', (t) async {
      final c = await _container(email: _owner);
      // No rental units are pre-seeded — create a fresh occupied unit fixture,
      // which naturally has an outstanding balance this month (due 4500, paid 0).
      final unit = await c
          .read(rentalUnitsProvider.notifier)
          .addUnit(
            unitName: 'TEST-UNIT',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 4500,
            tenantName: 'Test Tenant',
            createdBy: 'test',
          );
      await _pump(t, c, RecordPaymentSheet(unit: unit));
      expect(t.takeException(), isNull);

      // The "Amount paid (AED)" field is the only field whose label carries the
      // "(AED)" suffix.
      final paidField = find.descendant(
        of: find.ancestor(
          of: find.textContaining('(AED)'),
          matching: find.byType(LedgerTextField),
        ),
        matching: find.byType(TextFormField),
      );
      expect(paidField, findsOneWidget);
      await t.enterText(paidField, '999999');
      await t.pump();
      // Tap the primary CTA (its label is exactly "Record payment").
      await t.tap(find.text('Record payment').last);
      await t.pump(const Duration(milliseconds: 100));
      // Overpayment is rejected with the balance-due validator error.
      expect(find.textContaining('balance due'), findsOneWidget);
    });
  });

  group('Critical flow — wiring', () {
    testWidgets('tapping an Access & Roles cell grants the capability', (
      t,
    ) async {
      final c = await _container(email: _owner);
      await _pump(t, c, const AccessRolesScreen());
      int engineerCaps() => RoleCapability.values
          .where(
            (cap) =>
                c.read(rolePermissionsProvider).has(UserRole.engineer, cap),
          )
          .length;
      final before = engineerCaps();
      // An unchecked (off) editable cell — tapping it should grant that cap.
      await t.tap(find.byIcon(Icons.radio_button_unchecked_rounded).first);
      await t.pump();
      expect(engineerCaps(), greaterThan(before));
    });
  });
}
