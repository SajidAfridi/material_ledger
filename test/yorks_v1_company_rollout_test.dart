import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';

void main() {
  test(
    'Company Use honors the explicit deployment flag in every environment',
    () {
      const flags = YorksV1FeatureFlags.fromEnvironment();
      const requested = bool.fromEnvironment(
        'YORKS_V1_COMPANY_MATERIAL_REQUESTS',
        defaultValue: false,
      );
      expect(flags.companyMaterialRequests, flags.requests && requested);
    },
  );
}
