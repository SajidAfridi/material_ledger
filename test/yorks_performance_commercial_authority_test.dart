import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/permissions_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_current_commercial_capability_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/yorks_v1_permission_test_support.dart';

void main() {
  test('commercial authority denies absent, stale and untrusted snapshots', () {
    final trusted = yorksV1TrustedFeaturePermissionState(
      capabilities: const [YorksV1CapabilityKeys.commercialsView],
    );
    for (final state in [
      const YorksV1CurrentPermissionSnapshotState(),
      trusted.copyWith(isInitialLoading: true),
      trusted.copyWith(isStale: true),
      trusted.copyWith(isRevisionSignalHealthy: false),
      for (final failure in [
        YorksV1DomainErrorCode.unauthorized,
        YorksV1DomainErrorCode.unauthenticated,
        YorksV1DomainErrorCode.unexpectedResponse,
        YorksV1DomainErrorCode.backendUnavailable,
      ])
        trusted.copyWith(error: YorksV1DomainException(failure)),
    ]) {
      expect(
        yorksV1TrustedCommercialAccess(
          state,
          YorksV1CapabilityKeys.commercialsView,
        ),
        isFalse,
      );
    }
  });

  test('ordinary in-flight refresh retains a confirmed commercial grant', () {
    final refreshing = yorksV1TrustedFeaturePermissionState(
      capabilities: const [YorksV1CapabilityKeys.commercialsView],
    ).copyWith(isRefreshing: true);
    expect(
      yorksV1TrustedCommercialAccess(
        refreshing,
        YorksV1CapabilityKeys.commercialsView,
      ),
      isTrue,
    );
    expect(
      yorksV1TrustedCommercialAccess(
        refreshing,
        YorksV1CapabilityKeys.commercialsManage,
      ),
      isFalse,
    );
  });

  for (final role in [
    YorksV1Role.projectEngineer,
    YorksV1Role.siteEngineer,
    YorksV1Role.procurement,
    YorksV1Role.admin,
  ]) {
    test(
      '${role.claimValue} uses the server grant without a duplicate RPC',
      () {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-publishable-key',
        );
        addTearDown(client.dispose);
        final container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(client),
            yorksV1FeatureFlagsProvider.overrideWithValue(
              const YorksV1FeatureFlags(foundation: true),
            ),
            yorksV1CurrentRoleProvider.overrideWithValue(role),
            yorksV1CurrentPermissionSnapshotProvider.overrideWith(
              (ref) => YorksV1TestPermissionController(
                yorksV1TrustedFeaturePermissionState(
                  role: role,
                  capabilities: const [YorksV1CapabilityKeys.commercialsView],
                ),
              ),
            ),
            yorksV1CurrentCommercialCapabilityRepositoryProvider.overrideWith(
              (_) => throw StateError('Duplicate capability RPC mounted'),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(canViewCommercialsProvider), isTrue);
        expect(container.read(canManageCommercialsProvider), isFalse);
      },
    );
  }
}
