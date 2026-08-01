import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_commercial_capability.dart';
import '../models/yorks_v1_domain_error.dart';

/// Read-only client seam for the current session's protected commercial access.
///
/// The RPC derives the actor exclusively from `auth.uid()` and returns only
/// effective authorization booleans. It deliberately has no target parameter,
/// role input or commercial business payload.
abstract interface class YorksV1CurrentCommercialCapabilityRepository {
  Future<YorksV1CommercialCapabilities> loadCurrent();
}

class SupabaseYorksV1CurrentCommercialCapabilityRepository
    implements YorksV1CurrentCommercialCapabilityRepository {
  const SupabaseYorksV1CurrentCommercialCapabilityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<YorksV1CommercialCapabilities> loadCurrent() async {
    try {
      final response = await _client.rpc(
        'v1_get_current_commercial_capabilities',
      );
      if (response is! Map) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      return YorksV1CommercialCapabilities.fromApiJson(
        Map<String, dynamic>.from(response),
      );
    } on YorksV1DomainException {
      rethrow;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    } on PostgrestException catch (error) {
      final code = error.code;
      throw YorksV1DomainException(
        switch (code) {
          '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
          _ => YorksV1DomainErrorCode.backendUnavailable,
        },
        serverCode: code,
        cause: error,
      );
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }
}
