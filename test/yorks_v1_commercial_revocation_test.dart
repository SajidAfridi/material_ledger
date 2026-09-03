import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/commercial_record.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_commercial_capability.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_permission_management.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/commercial_records_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/permissions_provider.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_current_commercial_capability_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_permission_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_current_commercial_capability_repository.dart';

import 'support/yorks_v1_permission_test_support.dart';

YorksV1CommercialCapabilities _capabilities({
  required bool view,
  required bool manage,
}) => YorksV1CommercialCapabilities.fromApiJson({
  'capabilities': {
    'view_commercials': {
      'role_default': true,
      'effective': view,
      'override': view ? null : false,
    },
    'manage_commercials': {
      'role_default': true,
      'effective': manage,
      'override': manage ? null : false,
    },
  },
});

class _RecordingCurrentCapabilityRepository
    implements YorksV1CurrentCommercialCapabilityRepository {
  _RecordingCurrentCapabilityRepository(this.value, {this.onLoad});

  YorksV1CommercialCapabilities value;
  final void Function()? onLoad;
  var loads = 0;

  @override
  Future<YorksV1CommercialCapabilities> loadCurrent() async {
    loads++;
    onLoad?.call();
    return value;
  }
}

class _DeferredFirstCurrentCapabilityRepository
    implements YorksV1CurrentCommercialCapabilityRepository {
  _DeferredFirstCurrentCapabilityRepository({
    required this.firstResponse,
    required this.nextResponse,
  });

  final YorksV1CommercialCapabilities firstResponse;
  YorksV1CommercialCapabilities nextResponse;
  final firstLoadStarted = Completer<void>();
  final allowFirstResponse = Completer<void>();
  var loads = 0;

  @override
  Future<YorksV1CommercialCapabilities> loadCurrent() async {
    loads++;
    if (loads == 1) {
      firstLoadStarted.complete();
      await allowFirstResponse.future;
      return firstResponse;
    }
    return nextResponse;
  }
}

void main() {
  test('only terminal Realtime statuses revoke the commercial snapshot', () {
    expect(
      yorksV1AuthorizationSignalStatusRequiresFailure(
        RealtimeSubscribeStatus.subscribed,
      ),
      isFalse,
    );
    expect(
      yorksV1AuthorizationSignalStatusRequiresFailure(
        RealtimeSubscribeStatus.closed,
      ),
      isFalse,
    );
    expect(
      yorksV1AuthorizationSignalStatusRequiresFailure(
        RealtimeSubscribeStatus.channelError,
      ),
      isTrue,
    );
    expect(
      yorksV1AuthorizationSignalStatusRequiresFailure(
        RealtimeSubscribeStatus.timedOut,
      ),
      isTrue,
    );
  });

  test('duplicate subscribed acknowledgements do not imitate a reconnect', () {
    final readiness = YorksV1AuthorizationSignalReadiness(const [
      'v1_user_capabilities',
      'v1_profiles',
    ]);

    expect(readiness.markSubscribed('v1_user_capabilities'), isTrue);
    expect(readiness.markSubscribed('v1_user_capabilities'), isFalse);
    expect(readiness.allReady, isFalse);
    expect(readiness.markSubscribed('v1_profiles'), isTrue);
    expect(readiness.allReady, isTrue);
    expect(readiness.markSubscribed('v1_profiles'), isFalse);
    expect(readiness.allReady, isTrue);

    expect(readiness.markUnavailable('v1_profiles'), isTrue);
    expect(readiness.allReady, isFalse);
    expect(readiness.markSubscribed('v1_profiles'), isTrue);
    expect(readiness.allReady, isTrue);
  });

  test(
    'a current-session refresh fails closed and replaces stale access',
    () async {
      final repository = _RecordingCurrentCapabilityRepository(
        _capabilities(view: true, manage: true),
      );
      final notifier = YorksV1CurrentCommercialCapabilitiesNotifier(
        enabled: true,
        authUserId: '10000000-0000-4000-8000-000000000004',
        client: null,
        repository: repository,
        authorizationSignalSubscription:
            ({required onSignal, required onUnavailable}) async => true,
      );
      addTearDown(notifier.dispose);

      await notifier.start();
      expect(
        notifier
            .state
            .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
            .effective,
        isTrue,
      );

      repository.value = _capabilities(view: false, manage: false);
      await notifier.refresh();

      expect(
        notifier
            .state
            .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
            .effective,
        isFalse,
      );
      expect(
        notifier
            .state
            .valueOrNull?[YorksV1CommercialCapability.manageCommercials]
            .effective,
        isFalse,
      );
      expect(repository.loads, 2);
    },
  );

  test(
    'authorization signals are registered before a positive snapshot and recheck it',
    () async {
      final events = <String>[];
      final repository = _RecordingCurrentCapabilityRepository(
        _capabilities(view: true, manage: true),
        onLoad: () => events.add('load'),
      );
      late Future<void> Function() refreshFromLiveSignal;
      final notifier = YorksV1CurrentCommercialCapabilitiesNotifier(
        enabled: true,
        authUserId: '10000000-0000-4000-8000-000000000004',
        client: null,
        repository: repository,
        authorizationSignalSubscription:
            ({required onSignal, required onUnavailable}) async {
              events.add('subscribe');
              refreshFromLiveSignal = onSignal;
              return true;
            },
      );
      addTearDown(notifier.dispose);

      await notifier.start();
      expect(events, ['subscribe', 'load']);

      repository.value = _capabilities(view: false, manage: false);
      await refreshFromLiveSignal();

      expect(events, ['subscribe', 'load', 'load']);
      expect(
        notifier
            .state
            .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
            .effective,
        isFalse,
      );
    },
  );

  test(
    'a post-join recheck is queued while the initial protected RPC is in flight',
    () async {
      final repository = _DeferredFirstCurrentCapabilityRepository(
        firstResponse: _capabilities(view: true, manage: true),
        nextResponse: _capabilities(view: false, manage: false),
      );
      late Future<void> Function() refreshFromLiveSignal;
      final notifier = YorksV1CurrentCommercialCapabilitiesNotifier(
        enabled: true,
        authUserId: '10000000-0000-4000-8000-000000000004',
        client: null,
        repository: repository,
        authorizationSignalSubscription:
            ({required onSignal, required onUnavailable}) async {
              refreshFromLiveSignal = onSignal;
              return true;
            },
      );
      addTearDown(notifier.dispose);
      final stateHistory = <AsyncValue<YorksV1CommercialCapabilities?>>[];
      final removeStateListener = notifier.addListener(stateHistory.add);
      addTearDown(removeStateListener);

      final starting = notifier.start();
      await repository.firstLoadStarted.future;
      // This represents both live channels reaching `subscribed` while the
      // initial server snapshot is still unresolved.
      await refreshFromLiveSignal();
      repository.allowFirstResponse.complete();
      await starting;

      expect(repository.loads, 2);
      expect(
        stateHistory.any(
          (state) =>
              state
                  .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
                  .effective ==
              true,
        ),
        isFalse,
      );
      expect(
        notifier
            .state
            .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
            .effective,
        isFalse,
      );
    },
  );

  test(
    'no protected read occurs until both authorization signals confirm live',
    () async {
      final repository = _RecordingCurrentCapabilityRepository(
        _capabilities(view: true, manage: true),
      );
      final signalsReady = Completer<bool>();
      late void Function(Object? error) markUnavailable;
      final notifier = YorksV1CurrentCommercialCapabilitiesNotifier(
        enabled: true,
        authUserId: '10000000-0000-4000-8000-000000000004',
        client: null,
        repository: repository,
        authorizationSignalSubscription:
            ({required onSignal, required onUnavailable}) {
              markUnavailable = onUnavailable;
              return signalsReady.future;
            },
      );
      addTearDown(notifier.dispose);

      final starting = notifier.start();
      expect(repository.loads, 0);
      expect(notifier.state.valueOrNull, isNull);

      signalsReady.complete(true);
      await starting;

      expect(repository.loads, 1);
      expect(
        notifier
            .state
            .valueOrNull?[YorksV1CommercialCapability.viewCommercials]
            .effective,
        isTrue,
      );

      // A failed future join leaves the state denied and avoids another read.
      markUnavailable(Exception('subscription rejected'));
      expect(notifier.state.hasError, isTrue);
    },
  );

  test(
    'disposing a notifier with an incomplete authorization join finishes denied',
    () async {
      final repository = _RecordingCurrentCapabilityRepository(
        _capabilities(view: true, manage: true),
      );
      final neverReady = Completer<bool>();
      final notifier = YorksV1CurrentCommercialCapabilitiesNotifier(
        enabled: true,
        authUserId: '10000000-0000-4000-8000-000000000004',
        client: null,
        repository: repository,
        authorizationSignalSubscription:
            ({required onSignal, required onUnavailable}) => neverReady.future,
      );

      final starting = notifier.start();
      notifier.dispose();
      await starting;

      expect(repository.loads, 0);
    },
  );

  test(
    'protected commercial notifier purge clears held data and device cache',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final notifier = CommercialRecordsNotifier(
        client: null,
        preferences: preferences,
        allowed: true,
        canWrite: true,
        actorAppUserId: 'usr-admin',
      );
      addTearDown(notifier.dispose);

      await notifier.importLegacyForLocalDevelopment([
        CommercialRecord(
          subjectType: CommercialSubjectType.material,
          subjectId: 'mat-commercial',
          unitCostAED: 125,
          updatedAt: DateTime.utc(2026, 8, 1),
        ),
      ]);
      expect(notifier.state, isNotEmpty);
      expect(
        preferences.containsKey(commercialLocalDevelopmentCacheKey),
        isTrue,
      );

      await notifier.purgeProtectedState();

      expect(notifier.state, isEmpty);
      expect(
        preferences.containsKey(commercialLocalDevelopmentCacheKey),
        isFalse,
      );
    },
  );

  test(
    'exact V1 roles use protected snapshot instead of retained capability',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          yorksV1FeatureFlagsProvider.overrideWithValue(
            const YorksV1FeatureFlags(foundation: true),
          ),
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
          yorksV1CurrentPermissionSnapshotProvider.overrideWith(
            (ref) => YorksV1TestPermissionController(
              yorksV1TrustedFeaturePermissionState(capabilities: const []),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(canViewCommercialsProvider), isFalse);
      expect(container.read(canManageCommercialsProvider), isFalse);
    },
  );

  test(
    'a V1 revoke purges the previously held notifier object before reuse',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
      );
      addTearDown(client.dispose);
      final permissionController = YorksV1TestPermissionController(
        yorksV1TrustedFeaturePermissionState(
          capabilities: const {
            YorksV1CapabilityKeys.commercialsView,
            YorksV1CapabilityKeys.commercialsManage,
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          supabaseClientProvider.overrideWithValue(client),
          currentUserProvider.overrideWithValue(
            AppUser(
              id: 'usr-procurement',
              fullName: 'Procurement',
              email: 'procurement@yorks.test',
              role: UserRole.procurement,
              createdAt: DateTime.utc(2026, 8, 1),
            ),
          ),
          yorksV1FeatureFlagsProvider.overrideWithValue(
            const YorksV1FeatureFlags(foundation: true),
          ),
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.procurement),
          yorksV1CurrentPermissionSnapshotProvider.overrideWith(
            (ref) => permissionController,
          ),
        ],
      );
      addTearDown(container.dispose);

      final oldNotifier = container.read(commercialRecordsProvider.notifier);
      oldNotifier.state = {
        'material:mat-commercial': CommercialRecord(
          subjectType: CommercialSubjectType.material,
          subjectId: 'mat-commercial',
          unitCostAED: 125,
          updatedAt: DateTime.utc(2026, 8, 1),
        ),
      };
      expect(oldNotifier.state, isNotEmpty);

      permissionController.invalidateForAuthorizationFailure(
        const YorksV1DomainException(YorksV1DomainErrorCode.backendUnavailable),
      );
      await Future<void>.delayed(Duration.zero);

      // Riverpod disposes the old notifier before any dependent can read its
      // prior projection; an attempted stale-reference read fails closed.
      expect(() => oldNotifier.state, throwsStateError);
      expect(
        container.read(commercialRecordsProvider.notifier).isAllowed,
        isFalse,
      );
    },
  );
}
