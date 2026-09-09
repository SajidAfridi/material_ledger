import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/providers/posthog_analytics_provider.dart';

void main() {
  group('yorksAnalyticsScreenName', () {
    test('removes project identifiers', () {
      expect(
        yorksAnalyticsScreenName('/yorks/projects/123e4567-e89b-12d3-a456-426614174000'),
        'project_detail',
      );
      expect(
        yorksAnalyticsScreenName(
          '/yorks/projects/123e4567-e89b-12d3-a456-426614174000/edit',
        ),
        'project_edit',
      );
    });

    test('removes material request identifiers', () {
      expect(
        yorksAnalyticsScreenName('/yorks/material-requests/mr-secret-id'),
        'material_request_detail',
      );
      expect(
        yorksAnalyticsScreenName(
          '/yorks/material-requests/mr-secret-id/arrangement',
        ),
        'material_request_arrangement',
      );
    });

    test('removes supplier identifiers', () {
      expect(
        yorksAnalyticsScreenName('/yorks/inventory/suppliers/private-supplier-id'),
        'inventory_supplier_detail',
      );
    });

    test('unknown routes never echo the raw path', () {
      expect(yorksAnalyticsScreenName('/unknown/possibly-sensitive/value'), 'other');
    });
  });
}
