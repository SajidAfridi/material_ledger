import '../models/yorks_v1_commercial_capability.dart';
import '../models/yorks_v1_domain_error.dart';
import '../providers/users_provider.dart' show AdminUsersInvocation;

/// Narrow Flutter seam for protected V1 commercial-capability administration.
///
/// The service accepts the retained app-user key only as a stable lookup key;
/// it resolves the Auth UUID, target role and all effective values on the
/// server. The client never writes `v1_user_capabilities` directly.
abstract interface class YorksV1CommercialCapabilityRepository {
  Future<YorksV1CommercialCapabilities> loadForAppUser(String appUserId);

  Future<YorksV1CommercialCapabilities> setForAppUser({
    required String appUserId,
    required YorksV1CommercialCapability capability,
    required bool granted,
    required String reason,
    required String idempotencyKey,
  });
}

class YorksV1EdgeCommercialCapabilityRepository
    implements YorksV1CommercialCapabilityRepository {
  const YorksV1EdgeCommercialCapabilityRepository(this._invokeAdminUsers);

  final AdminUsersInvocation _invokeAdminUsers;

  @override
  Future<YorksV1CommercialCapabilities> loadForAppUser(String appUserId) async {
    final response = await _invoke({
      'action': 'getV1CommercialCapabilities',
      'appUserId': appUserId.trim(),
    });
    return _parse(response);
  }

  @override
  Future<YorksV1CommercialCapabilities> setForAppUser({
    required String appUserId,
    required YorksV1CommercialCapability capability,
    required bool granted,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _invoke({
      'action': 'setV1CommercialCapability',
      'appUserId': appUserId.trim(),
      'capability': capability.databaseValue,
      'granted': granted,
      'reason': reason.trim(),
      'idempotencyKey': idempotencyKey.trim(),
    });
    return _parse(response);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if ((body['appUserId'] as String).isEmpty) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final response = await _invokeAdminUsers(body);
    if (response == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    return response;
  }

  YorksV1CommercialCapabilities _parse(Map<String, dynamic> response) {
    try {
      return YorksV1CommercialCapabilities.fromApiJson(response);
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }
}
