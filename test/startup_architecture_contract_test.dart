import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter paints before preferences or Supabase initialization', () {
    final source = File('lib/main.dart').readAsStringSync();
    final firstRunApp = source.indexOf(
      'runApp(_RuntimeBootstrapHost(observability: observability))',
    );
    final preferences = source.indexOf('SharedPreferences.getInstance()');
    final supabase = source.indexOf('await Supabase.initialize(');

    expect(firstRunApp, greaterThanOrEqualTo(0));
    expect(firstRunApp, lessThan(preferences));
    expect(firstRunApp, lessThan(supabase));
  });

  test('global services are staged outside the root application build', () {
    final app = File('lib/app/app.dart').readAsStringSync();

    for (final provider in <String>[
      'syncEngineProvider',
      'realtimeSyncProvider',
      'inventoryReconcilerProvider',
      'idleRequestMonitorProvider',
      'documentExpiryMonitorProvider',
      'pushBridgeProvider',
      'yorksV1NotificationsProvider',
    ]) {
      expect(app, isNot(contains('ref.watch($provider)')), reason: provider);
    }
    expect(app, contains('ref.watch(appStartupCoordinatorProvider)'));
  });

  test('Overview consumes bounded startup projections', () {
    final source = File(
      'lib/features/projects/presentation/screens/'
      'yorks_v1_projects_screen.dart',
    ).readAsStringSync();
    final overviewStart = source.indexOf('class YorksV1OverviewScreen');
    final overviewEnd = source.indexOf('class _R35OverviewPage');
    final overview = source.substring(overviewStart, overviewEnd);

    expect(overview, contains('yorksV1ProjectOverviewProvider'));
    expect(overview, contains('yorksV1MaterialRequestOverviewProvider(6)'));
    expect(overview, isNot(contains('yorksV1MaterialRequestListProvider')));
    expect(overview, isNot(contains('yorksV1ProjectPortfolioProvider.future')));
  });
}
