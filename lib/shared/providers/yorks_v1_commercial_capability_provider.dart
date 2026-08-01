import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_commercial_capability.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_role.dart';
import '../repositories/yorks_v1_commercial_capability_repository.dart';
import 'users_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';

/// The only connected V1 commercial-capability administration implementation.
/// It is intentionally separate from retained local permission overrides.
final yorksV1CommercialCapabilityRepositoryProvider =
    Provider<YorksV1CommercialCapabilityRepository>((ref) {
      return YorksV1EdgeCommercialCapabilityRepository(
        ref.watch(adminUsersInvocationProvider),
      );
    });

/// An Admin-only, non-persistent capability projection for one managed user.
///
/// It is not requested for a non-Admin or while the V1 identity foundation is
/// disabled. This keeps protected authorization data out of retained-role
/// routes and device storage.
final yorksV1CommercialCapabilitiesProvider = FutureProvider.autoDispose
    .family<YorksV1CommercialCapabilities, String>((ref, appUserId) async {
      final flags = ref.watch(yorksV1FeatureFlagsProvider);
      final currentRole = ref.watch(yorksV1CurrentRoleProvider);
      if (!flags.foundation) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.featureDisabled,
        );
      }
      if (currentRole != YorksV1Role.admin) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized);
      }
      return ref
          .watch(yorksV1CommercialCapabilityRepositoryProvider)
          .loadForAppUser(appUserId);
    });
