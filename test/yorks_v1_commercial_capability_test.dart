import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/yorks_v1_commercial_capability.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/users_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_commercial_capability_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_commercial_capability_repository.dart';

Map<String, dynamic> _capabilityResponse({
  bool viewEffective = true,
  bool manageEffective = true,
  bool? viewOverride,
  bool? manageOverride,
}) => {
  'ok': true,
  'capabilities': {
    'view_commercials': {
      'role_default': true,
      'effective': viewEffective,
      'override': viewOverride,
    },
    'manage_commercials': {
      'role_default': true,
      'effective': manageEffective,
      'override': manageOverride,
    },
  },
};

void main() {
  test('parses only a complete typed non-commercial capability projection', () {
    final capabilities = YorksV1CommercialCapabilities.fromApiJson(
      _capabilityResponse(viewEffective: false, viewOverride: false),
    );

    expect(
      capabilities[YorksV1CommercialCapability.viewCommercials].effective,
      false,
    );
    expect(
      capabilities[YorksV1CommercialCapability.viewCommercials].overrideGranted,
      false,
    );
    expect(
      capabilities[YorksV1CommercialCapability.manageCommercials]
          .usesRoleDefault,
      true,
    );
  });

  test('fails closed when a protected capability response is incomplete', () {
    expect(
      () => YorksV1CommercialCapabilities.fromApiJson({
        'capabilities': {
          'view_commercials': {
            'role_default': true,
            'effective': true,
            'override': null,
          },
        },
      }),
      throwsFormatException,
    );
  });

  test('uses the privileged Edge gateway with app user ID only', () async {
    final commands = <Map<String, dynamic>>[];
    final repository = YorksV1EdgeCommercialCapabilityRepository((body) async {
      commands.add(Map<String, dynamic>.from(body));
      return _capabilityResponse(viewEffective: false, viewOverride: false);
    });

    final result = await repository.setForAppUser(
      appUserId: 'usr-procurement',
      capability: YorksV1CommercialCapability.viewCommercials,
      granted: false,
      reason: 'Pilot access withdrawn',
      idempotencyKey: '20000000-0000-4000-8000-000000000001',
    );

    expect(commands, [
      {
        'action': 'setV1CommercialCapability',
        'appUserId': 'usr-procurement',
        'capability': 'view_commercials',
        'granted': false,
        'reason': 'Pilot access withdrawn',
        'idempotencyKey': '20000000-0000-4000-8000-000000000001',
      },
    ]);
    expect(
      result[YorksV1CommercialCapability.viewCommercials].effective,
      false,
    );
  });

  test(
    'the read provider is Admin-only and never derives access locally',
    () async {
      final commands = <Map<String, dynamic>>[];
      final container = ProviderContainer(
        overrides: [
          yorksV1FeatureFlagsProvider.overrideWithValue(
            const YorksV1FeatureFlags(foundation: true),
          ),
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
          adminUsersInvocationProvider.overrideWithValue((body) async {
            commands.add(Map<String, dynamic>.from(body));
            return _capabilityResponse();
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        yorksV1CommercialCapabilitiesProvider('usr-admin').future,
      );

      expect(
        result[YorksV1CommercialCapability.manageCommercials].effective,
        true,
      );
      expect(commands.single, {
        'action': 'getV1CommercialCapabilities',
        'appUserId': 'usr-admin',
      });
    },
  );
}
