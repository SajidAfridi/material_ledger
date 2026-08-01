import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/admin/presentation/screens/user_management_screen.dart';
import 'package:material_ledger/shared/models/effective_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';

void main() {
  Future<ProviderContainer> connectedContainer({
    required bool yorksV1Foundation,
    required List<Map<String, dynamic>> commands,
    AdminUsersInvocation? invocation,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(client),
        yorksV1FeatureFlagsProvider.overrideWithValue(
          YorksV1FeatureFlags(foundation: yorksV1Foundation),
        ),
        adminUsersInvocationProvider.overrideWithValue(
          invocation ??
              (body) async {
                commands.add(Map<String, dynamic>.from(body));
                return const {'ok': true, 'authUserId': 'auth-user-id'};
              },
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await client.dispose();
    });
    return container;
  }

  group('Yorks V1 user provisioning adapter', () {
    test('creates an exact V1 role without client capability claims', () async {
      final commands = <Map<String, dynamic>>[];
      final container = await connectedContainer(
        yorksV1Foundation: true,
        commands: commands,
      );

      final user = await container
          .read(usersProvider.notifier)
          .createYorksV1User(
            fullName: 'Project Engineer',
            email: 'pe@yorks.test',
            role: YorksV1Role.projectEngineer,
            password: 'temporary-password',
          );

      expect(commands, hasLength(1));
      expect(commands.single['action'], 'create');
      expect(commands.single['role'], 'project_engineer');
      expect(commands.single.containsKey('caps'), false);
      expect(commands.single.containsKey('legacyShell'), false);
      expect(
        Uuid.isValidUUID(fromString: commands.single['idempotencyKey']),
        isTrue,
      );
      expect(user.role, UserRole.engineer); // compatibility shell only
      expect(user.yorksV1RoleCache, YorksV1Role.projectEngineer);
      expect(user.passwordHash, isEmpty);
      expect(user.passwordSalt, isEmpty);
    });

    test(
      'maps a user to an exact role only after the server command succeeds',
      () async {
        final commands = <Map<String, dynamic>>[];
        final container = await connectedContainer(
          yorksV1Foundation: true,
          commands: commands,
        );
        final notifier = container.read(usersProvider.notifier);
        final user = await notifier.createYorksV1User(
          fullName: 'Site Engineer',
          email: 'site@yorks.test',
          role: YorksV1Role.siteEngineer,
          password: 'temporary-password',
        );
        commands.clear();

        final changed = await notifier.setYorksV1Role(
          user.id,
          YorksV1Role.procurement,
        );

        expect(changed, true);
        expect(commands, hasLength(1));
        expect(commands.single['action'], 'updateClaims');
        expect(commands.single['appUserId'], user.id);
        expect(commands.single['role'], 'procurement');
        expect(
          Uuid.isValidUUID(fromString: commands.single['idempotencyKey']),
          isTrue,
        );
        final updated = container
            .read(usersProvider)
            .firstWhere((candidate) => candidate.id == user.id);
        expect(updated.role, UserRole.procurement);
        expect(updated.yorksV1RoleCache, YorksV1Role.procurement);
      },
    );

    test(
      'reuses an exact create command after a lost response retry',
      () async {
        final commands = <Map<String, dynamic>>[];
        final container = await connectedContainer(
          yorksV1Foundation: true,
          commands: commands,
        );
        const appUserId = 'usr-retry01';
        final idempotencyKey = const Uuid().v4();
        final notifier = container.read(usersProvider.notifier);

        for (var attempt = 0; attempt < 2; attempt++) {
          await notifier.createYorksV1User(
            fullName: 'Retry-safe Engineer',
            email: 'retry@yorks.test',
            role: YorksV1Role.siteEngineer,
            password: 'temporary-password',
            idempotencyKey: idempotencyKey,
            appUserId: appUserId,
          );
        }

        expect(commands, hasLength(2));
        expect(
          commands.map((command) => command['idempotencyKey']),
          everyElement(idempotencyKey),
        );
        expect(
          commands.map((command) => command['appUserId']),
          everyElement(appUserId),
        );
        expect(
          container.read(usersProvider).where((user) => user.id == appUserId),
          hasLength(1),
        );
      },
    );

    test('reuses an explicit key for an account-state retry', () async {
      final commands = <Map<String, dynamic>>[];
      final container = await connectedContainer(
        yorksV1Foundation: true,
        commands: commands,
      );
      final idempotencyKey = const Uuid().v4();
      final notifier = container.read(usersProvider.notifier);

      await notifier.setActive(
        'usr-proc',
        false,
        idempotencyKey: idempotencyKey,
      );
      await notifier.setActive(
        'usr-proc',
        false,
        idempotencyKey: idempotencyKey,
      );

      expect(commands, hasLength(2));
      expect(
        commands.map((command) => command['idempotencyKey']),
        everyElement(idempotencyKey),
      );
      expect(commands.map((command) => command['active']), everyElement(false));
    });

    test('retains a legacy restamp key after a lost response', () async {
      final commands = <Map<String, dynamic>>[];
      var attempts = 0;
      final container = await connectedContainer(
        yorksV1Foundation: false,
        commands: commands,
        invocation: (body) async {
          commands.add(Map<String, dynamic>.from(body));
          if (attempts++ == 0) throw StateError('lost response');
          return const {'ok': true, 'authUserId': 'auth-user-id'};
        },
      );
      final notifier = container.read(usersProvider.notifier);

      expect(await notifier.restampRoleClaims(UserRole.engineer), 1);
      expect(await notifier.restampRoleClaims(UserRole.engineer), 0);

      expect(commands, hasLength(2));
      expect(
        commands.map((command) => command['idempotencyKey']).toSet(),
        hasLength(1),
      );
    });

    test('keeps the flag-off connected engineer flow quarantined', () async {
      final commands = <Map<String, dynamic>>[];
      final container = await connectedContainer(
        yorksV1Foundation: false,
        commands: commands,
      );

      final user = await container
          .read(usersProvider.notifier)
          .createUser(
            fullName: 'Legacy Engineer',
            email: 'legacy@yorks.test',
            role: UserRole.engineer,
            password: 'temporary-password',
          );

      expect(commands, hasLength(1));
      expect(commands.single['action'], 'createLegacy');
      expect(commands.single['role'], 'engineer');
      expect(commands.single['legacyShell'], true);
      expect(commands.single['caps'], isEmpty);
      expect(
        Uuid.isValidUUID(fromString: commands.single['idempotencyKey']),
        isTrue,
      );
      expect(user.yorksV1RoleCache, isNull);
    });

    test(
      'sends a permitted legacy override through the quarantined claim path',
      () async {
        final commands = <Map<String, dynamic>>[];
        final container = await connectedContainer(
          yorksV1Foundation: false,
          commands: commands,
        );
        final notifier = container.read(usersProvider.notifier);
        final engineer = container
            .read(usersProvider)
            .firstWhere((user) => user.role == UserRole.engineer);

        await notifier.setPermissionOverride(
          engineer.id,
          PermissionKey.finance,
          true,
        );

        expect(commands, hasLength(1));
        expect(commands.single['action'], 'updateLegacyClaims');
        expect(commands.single['role'], 'engineer');
        expect(commands.single['legacyShell'], true);
        expect(commands.single['caps'], contains('finance'));
        expect(
          Uuid.isValidUUID(fromString: commands.single['idempotencyKey']),
          isTrue,
        );
      },
    );

    test('never accepts a legacy engineer as a cached V1 engineering role', () {
      expect(YorksV1Role.fromServerClaim('engineer'), isNull);
    });

    testWidgets(
      'shows only the exact role choices in connected V1 management',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            yorksV1UserProvisioningEnabledProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const UserManagementScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Project Engineer'), findsOneWidget);
        expect(find.text('Site Engineer'), findsOneWidget);
        expect(find.text('Procurement'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
        expect(find.text('Engineer'), findsNothing);
      },
    );
  });
}
