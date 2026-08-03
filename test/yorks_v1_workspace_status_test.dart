import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_workspace_status.dart';
import 'package:material_ledger/shared/providers/yorks_v1_workspace_status_provider.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:material_ledger/shared/sync/sync_engine.dart';

void main() {
  group('Yorks V1 workspace status', () {
    test(
      'reports a clean connected workspace without claiming a record save',
      () {
        final container = ProviderContainer(
          overrides: [
            syncStatusProvider.overrideWithValue(SyncState.synced),
            pendingSyncCountProvider.overrideWithValue(0),
          ],
        );
        addTearDown(container.dispose);

        final status = container.read(yorksV1WorkspaceStatusProvider);

        expect(status.state, YorksV1WorkspaceConnectionState.connected);
        expect(status.hasUncommittedWork, isFalse);
        expect(status.lastAuthoritativeRefresh, isNull);
      },
    );

    test('reports durable sync work and its pending count', () {
      final container = ProviderContainer(
        overrides: [
          syncStatusProvider.overrideWithValue(SyncState.syncing),
          pendingSyncCountProvider.overrideWithValue(3),
        ],
      );
      addTearDown(container.dispose);

      final status = container.read(yorksV1WorkspaceStatusProvider);

      expect(status.state, YorksV1WorkspaceConnectionState.syncing);
      expect(status.pendingChangeCount, 3);
      expect(status.hasUncommittedWork, isTrue);
    });

    test(
      'does not hide offline or failed durable work behind a success state',
      () {
        for (final expectation in [
          (SyncState.offlineQueued, YorksV1WorkspaceConnectionState.offline),
          (SyncState.error, YorksV1WorkspaceConnectionState.failed),
        ]) {
          final container = ProviderContainer(
            overrides: [
              syncStatusProvider.overrideWithValue(expectation.$1),
              pendingSyncCountProvider.overrideWithValue(1),
            ],
          );
          addTearDown(container.dispose);

          final status = container.read(yorksV1WorkspaceStatusProvider);

          expect(status.state, expectation.$2);
          expect(status.hasUncommittedWork, isTrue);
        }
      },
    );

    test('retains every explicit record-level state for truthful editors', () {
      for (final state in YorksV1WorkspaceConnectionState.values) {
        final status = YorksV1WorkspaceStatus(state: state);
        expect(status.state, state);
      }
    });

    test('reports an idle disconnected shell as offline, not saved', () {
      final connectivity = DefaultConnectivity(online: false);
      final container = ProviderContainer(
        overrides: [
          syncStatusProvider.overrideWithValue(SyncState.synced),
          pendingSyncCountProvider.overrideWithValue(0),
          connectivityProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(() {
        container.dispose();
        connectivity.dispose();
      });

      final status = container.read(yorksV1WorkspaceStatusProvider);

      expect(status.state, YorksV1WorkspaceConnectionState.offline);
      expect(status.hasUncommittedWork, isFalse);
    });
  });
}
