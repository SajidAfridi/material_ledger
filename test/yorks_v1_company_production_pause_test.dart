import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';

void main() {
  test('Company Use remains hidden in a production build', () {
    expect(const String.fromEnvironment('R35_ENVIRONMENT'), 'production');
    expect(
      const bool.fromEnvironment('YORKS_V1_COMPANY_MATERIAL_REQUESTS'),
      true,
    );
    expect(
      const YorksV1FeatureFlags.fromEnvironment().companyMaterialRequests,
      false,
    );
  });
}
