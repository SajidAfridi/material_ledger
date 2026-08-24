import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_configuration_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_configuration_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lost master-create response reuses the command key and target id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _LostResponseConfigurationRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          yorksV1AuthUserIdProvider.overrideWithValue('admin-user'),
          yorksV1ConfigurationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        yorksV1ConfigurationCommandProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(
        yorksV1ConfigurationCommandProvider.notifier,
      );
      const payload = <String, Object?>{
        'name': 'Commissioning fixtures',
        'parent_category_id': null,
      };

      expect(
        await controller.stageMasterAction(
          entityKind: 'material_category',
          actionKind: 'create',
          targetId: 'widget-random-id-one',
          payload: payload,
          reason: null,
          expectedRevision: 7,
        ),
        isFalse,
      );
      expect(
        await controller.stageMasterAction(
          entityKind: 'material_category',
          actionKind: 'create',
          targetId: 'widget-random-id-two',
          payload: payload,
          reason: null,
          expectedRevision: 7,
        ),
        isTrue,
      );

      expect(repository.idempotencyKeys, hasLength(2));
      expect(repository.idempotencyKeys.toSet(), hasLength(1));
      expect(repository.targetIds, hasLength(2));
      expect(repository.targetIds.toSet(), hasLength(1));
      expect(
        repository.targetIds.toSet().single,
        isNot(contains('widget-random')),
      );
    },
  );
}

class _LostResponseConfigurationRepository
    implements YorksV1ConfigurationRepository {
  final List<String> idempotencyKeys = [];
  final List<String> targetIds = [];
  var _attempts = 0;

  @override
  Future<void> stageMasterAction({
    required String entityKind,
    required String actionKind,
    required String targetId,
    required Map<String, Object?> payload,
    String? reason,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    targetIds.add(targetId);
    if (_attempts++ == 0) {
      throw TimeoutException('The committed response was lost.');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
