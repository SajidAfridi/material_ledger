import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/app_config.dart';

void main() {
  group('resolveGate (force-update / maintenance)', () {
    test('installed below minimum → hard update gate', () {
      const config = AppConfig(minSupportedBuild: 5, latestBuild: 5);
      expect(resolveGate(config, 4), AppGate.updateRequired);
      expect(resolveGate(config, 5), AppGate.none);
      expect(resolveGate(config, 6), AppGate.none);
    });

    test('maintenance flag shows the maintenance gate', () {
      const config = AppConfig(maintenanceMode: true);
      expect(resolveGate(config, 1), AppGate.maintenance);
    });

    test('a hard version block takes precedence over maintenance', () {
      const config =
          AppConfig(minSupportedBuild: 10, maintenanceMode: true);
      expect(resolveGate(config, 3), AppGate.updateRequired);
    });

    test('default config never gates the current build', () {
      expect(resolveGate(const AppConfig(), 1), AppGate.none);
    });
  });

  group('updateAvailable (soft nudge)', () {
    test('true only when at/above minimum but behind latest', () {
      const config = AppConfig(minSupportedBuild: 2, latestBuild: 5);
      expect(updateAvailable(config, 1), false); // below min → hard gate, not soft
      expect(updateAvailable(config, 3), true);
      expect(updateAvailable(config, 5), false);
    });
  });
}
