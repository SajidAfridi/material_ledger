import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/app/router.dart';
import 'package:material_ledger/shared/models/user_role.dart';

/// `GoRouter` validates its whole route tree at construction (duplicate paths,
/// malformed nested sub-routes, etc. throw immediately). Building it for every
/// role therefore validates the engineer `StatefulShellRoute` (with its nested
/// `/new-request` + `/projects/new`) and the office shell without a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createAppRouter builds a valid tree for every role', () {
    for (final role in UserRole.values) {
      test('role: ${role.name}', () {
        final router = createAppRouter(
          isOnboarded: true,
          isLoggedIn: true,
          role: role,
        );
        addTearDown(router.dispose);
        expect(router.configuration.routes, isNotEmpty);
      });
    }
  });
}
