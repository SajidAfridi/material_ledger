import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/services/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('verify accepts the right password and rejects others', () {
      final pw = PasswordHasher.create('s3cret!');
      expect(PasswordHasher.verify('s3cret!', pw.hash, pw.salt), true);
      expect(PasswordHasher.verify('wrong', pw.hash, pw.salt), false);
    });

    test('empty hash/salt never verifies', () {
      expect(PasswordHasher.verify('anything', '', ''), false);
    });

    test('salts are random — same password yields different hashes', () {
      final a = PasswordHasher.create('same');
      final b = PasswordHasher.create('same');
      expect(a.hash == b.hash, false);
    });
  });

  group('Credential sign-in', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    AuthController auth() => container.read(authControllerProvider);

    test('valid seed credentials sign in and set the role from the user',
        () async {
      final result = await auth().signIn(
        email: 'owner@yorksac.ae',
        password: kSeedPassword,
      );
      expect(result, SignInResult.ok);
      expect(container.read(isLoggedInProvider), true);
      expect(container.read(currentUserProvider)?.role, UserRole.admin);
      expect(container.read(currentRoleProvider), UserRole.admin);
    });

    test('engineer creds load the engineer role', () async {
      await auth().signIn(email: 'ahmed.khan@yorksac.ae', password: kSeedPassword);
      expect(container.read(currentRoleProvider), UserRole.engineer);
    });

    test('wrong password is rejected and no session opens', () async {
      final result = await auth().signIn(
        email: 'owner@yorksac.ae',
        password: 'nope',
      );
      expect(result, SignInResult.invalidCredentials);
      expect(container.read(isLoggedInProvider), false);
    });

    test('unknown email is rejected', () async {
      final result = await auth().signIn(
        email: 'ghost@yorksac.ae',
        password: kSeedPassword,
      );
      expect(result, SignInResult.invalidCredentials);
    });

    test('a deactivated account is blocked even with the right password',
        () async {
      // Deactivate the procurement seed, then try to sign in.
      final proc = container
          .read(usersProvider)
          .firstWhere((u) => u.role == UserRole.procurement);
      await container.read(usersProvider.notifier).setActive(proc.id, false);
      final result = await auth().signIn(
        email: proc.email,
        password: kSeedPassword,
      );
      expect(result, SignInResult.deactivated);
      expect(container.read(isLoggedInProvider), false);
    });

    test('an admin-created user must change password on first sign-in', () async {
      final u = await container.read(usersProvider.notifier).createUser(
            fullName: 'Temp User',
            email: 'temp@yorksac.ae',
            role: UserRole.engineer,
            password: 'temp1234',
          );
      final result =
          await auth().signIn(email: u.email, password: 'temp1234');
      expect(result, SignInResult.mustChangePassword);

      // After they set their own password, normal sign-in.
      await container.read(usersProvider.notifier).setPassword(u.id, 'mine5678');
      await auth().signOut();
      final after = await auth().signIn(email: u.email, password: 'mine5678');
      expect(after, SignInResult.ok);
    });

    test('signOut clears the session', () async {
      await auth().signIn(email: 'owner@yorksac.ae', password: kSeedPassword);
      expect(container.read(isLoggedInProvider), true);
      await auth().signOut();
      expect(container.read(isLoggedInProvider), false);
      expect(container.read(currentUserProvider), isNull);
    });
  });
}
