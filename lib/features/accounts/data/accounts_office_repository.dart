import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../domain/accounts_office_models.dart';
import 'accounts_repository.dart';

abstract interface class YorksAccountsOfficeRepository {
  Future<YorksAccountsOfficeProjection> getRegister(
    YorksAccountsOfficeSection section,
    YorksAccountsOfficeFilters filters,
  );
}

final class YorksSupabaseAccountsOfficeRepository
    implements YorksAccountsOfficeRepository {
  const YorksSupabaseAccountsOfficeRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksAccountsRpcClient? rpcClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksAccountsRpcClient? _rpcClient;

  @override
  Future<YorksAccountsOfficeProjection> getRegister(
    YorksAccountsOfficeSection section,
    YorksAccountsOfficeFilters filters,
  ) async {
    if (!filters.isValid) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    if (!_featureFlags.accounts) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    if (!_connectivity.isOnline) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.offline);
    }
    final rpc = _rpcClient;
    if (rpc == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    final response = await rpc.invoke(
      functionName: 'v1_get_accounts_office_register',
      parameters: filters.toRpcParameters(section),
    );
    try {
      final projection = YorksAccountsOfficeProjection.fromRpcJson(response);
      if (projection.section != section ||
          projection.limit != filters.limit ||
          projection.offset != filters.offset) {
        throw const FormatException('Account Office response mismatch.');
      }
      return projection;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }
}
