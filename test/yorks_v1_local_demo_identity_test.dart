import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('explicit local demo maps the seeded engineer to the V1 persona', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        localDemoPasswordProvider.overrideWithValue('test-only-local-password'),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(authControllerProvider).signIn(
      email: 'imrankhan@gmail.com',
      password: 'test-only-local-password',
    );

    expect(result, SignInResult.ok);
    expect(
      container.read(yorksV1CurrentRoleProvider),
      YorksV1Role.projectEngineer,
    );
    expect(container.read(yorksV1AuthUserIdProvider), 'usr-eng');
  });
}
