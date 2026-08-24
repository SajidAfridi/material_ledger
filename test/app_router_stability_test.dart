import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/app/app.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/services/app_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'directory presentation refresh does not reconstruct the active router',
    () async {
      SharedPreferences.setMockInitialValues({kAuthUserIdPrefKey: 'usr-admin'});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appVersionProvider.overrideWithValue(
            const AppVersionInfo(version: '1.0.0', build: 35),
          ),
        ],
      );
      addTearDown(container.dispose);

      final firstRouter = container.read(appRouterProvider);
      final current = container.read(currentUserProvider)!;
      await container
          .read(usersProvider.notifier)
          .update(current.copyWith(fullName: 'Updated Admin Display Name'));

      final afterPresentationUpdate = container.read(appRouterProvider);
      expect(afterPresentationUpdate, same(firstRouter));

      await container
          .read(usersProvider.notifier)
          .update(container.read(currentUserProvider)!.copyWith(active: false));

      expect(container.read(appRouterProvider), isNot(same(firstRouter)));
    },
  );
}
