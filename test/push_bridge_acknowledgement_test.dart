import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/app.dart' show appRouterProvider;
import 'package:material_ledger/app/push_bridge.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_request.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_return_workflow.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';
import 'package:material_ledger/shared/providers/session_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_company_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_logistics_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_preferences_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_notification_repository.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/screens/notifications_screen.dart';
import 'package:material_ledger/shared/widgets/notification_alert_host.dart';
import 'package:material_ledger/shared/widgets/notification_bell.dart';
import 'package:material_ledger/core/widgets/yorks_app_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _notificationId = '21000000-0000-4000-8000-000000000001';
const _entityId = '22000000-0000-4000-8000-000000000001';
final _testUserProvider = StateProvider<AppUser?>((_) => _user('owner'));

enum _Destination {
  project('/yorks/material-requests/$_entityId'),
  company('/yorks/material-requests/company/$_entityId'),
  materialReturn('/yorks/returns/$_entityId');

  const _Destination(this.path);
  final String path;
  String get location => '$path?notificationId=$_notificationId';
}

enum _Source { bell, inbox, toast }

void main() {
  tearDown(YorksAppToast.dismiss);
  for (final route in [
    '',
    'https://example.invalid/private',
    '//example.invalid/private',
    'relative-record',
    'javascript:alert(1)',
  ]) {
    testWidgets('authoritative unsafe target "$route" stays unread', (
      tester,
    ) async {
      final harness = await _Harness.start(
        tester,
        _Destination.project,
        initialLocation: '/elsewhere',
      );
      final locations = <String>[];
      await harness.container
          .read(notificationActionsProvider)
          .open(_appNotification(route), navigate: locations.add);
      await tester.pumpAndSettle();
      expect(locations, isEmpty);
      expect(harness.repository.markedIds, isEmpty);
      expect(harness.unread, isTrue);
      await harness.close(tester);
    });
  }
  testWidgets('unsupported protected target does not acknowledge on push', (
    tester,
  ) async {
    final harness = await _Harness.start(
      tester,
      _Destination.project,
      initialLocation: '/',
    );
    await harness.container
        .read(notificationActionsProvider)
        .open(
          _appNotification('/elsewhere'),
          navigate: (location) => harness.router.push(location),
        );
    await tester.pumpAndSettle();
    expect(
      harness.router.state.uri.queryParameters['notificationId'],
      _notificationId,
    );
    expect(harness.repository.markedIds, isEmpty);
    expect(harness.unread, isTrue);
    await harness.close(tester);
  });
  testWidgets('in-app metadata preserves exact target and replaces stale id', (
    tester,
  ) async {
    final harness = await _Harness.start(
      tester,
      _Destination.project,
      initialLocation: '/',
    );
    final locations = <String>[];
    await harness.container
        .read(notificationActionsProvider)
        .open(
          _appNotification(
            '${_Destination.project.path}?comment=comment-123&notificationId=stale',
          ),
          navigate: locations.add,
        );
    expect(locations, hasLength(1));
    final uri = Uri.parse(locations.single);
    expect(uri.path, _Destination.project.path);
    expect(uri.queryParameters['comment'], 'comment-123');
    expect(uri.queryParameters['notificationId'], _notificationId);
    expect(harness.repository.markedIds, isEmpty);
    await harness.close(tester);
  });
  testWidgets('invalid row id cannot propagate another acknowledgement id', (
    tester,
  ) async {
    final harness = await _Harness.start(
      tester,
      _Destination.project,
      initialLocation: '/',
    );
    final locations = <String>[];
    await harness.container
        .read(notificationActionsProvider)
        .open(
          _appNotification(
            '${_Destination.project.path}?comment=comment-123&notificationId=$_notificationId',
            id: 'synthetic-id',
          ),
          navigate: locations.add,
        );
    expect(locations, hasLength(1));
    final uri = Uri.parse(locations.single);
    expect(uri.path, _Destination.project.path);
    expect(uri.queryParameters['comment'], 'comment-123');
    expect(uri.queryParameters.containsKey('notificationId'), isFalse);
    expect(harness.repository.markedIds, isEmpty);
    await harness.close(tester);
  });
  for (final source in _Source.values) {
    for (final destination in _Destination.values) {
      testWidgets(
        '${source.name} ${destination.name} waits for protected loaded data and preserves Back',
        (tester) async {
          final harness = await _Harness.start(
            tester,
            destination,
            source: source,
          );
          await harness.open(tester, source);
          expect(harness.router.state.uri, Uri.parse(destination.location));
          expect(harness.router.canPop(), isTrue);
          expect(harness.repository.markedIds, isEmpty);
          await tester.pump(const Duration(seconds: 1));
          expect(harness.repository.markedIds, isEmpty);
          expect(harness.unread, isTrue);
          harness.complete(destination);
          await tester.pump();
          await tester.pump();
          expect(harness.repository.markedIds, [_notificationId]);
          expect(harness.unread, isFalse);
          harness.router.pop();
          await tester.pumpAndSettle();
          expect(
            harness.router.state.uri.path,
            source == _Source.inbox ? '/notifications' : '/',
          );
          expect(harness.repository.markedIds, [_notificationId]);
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
      testWidgets('${source.name} ${destination.name} denial stays unread', (
        tester,
      ) async {
        final harness = await _Harness.start(
          tester,
          destination,
          source: source,
        );
        await harness.open(tester, source);
        harness.deny(destination);
        await tester.pump();
        await tester.pump();
        expect(harness.repository.markedIds, isEmpty);
        expect(harness.unread, isTrue);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
    for (final nextUser in <String?>['another-owner', null]) {
      testWidgets(
        '${source.name} ${nextUser ?? 'logout'} during load keeps old owner unread',
        (tester) async {
          final harness = await _Harness.start(
            tester,
            _Destination.project,
            source: source,
          );
          await harness.open(tester, source);
          harness.container.read(_testUserProvider.notifier).state =
              nextUser == null ? null : _user(nextUser);
          await tester.pump();
          harness.complete(_Destination.project);
          await tester.pump();
          await tester.pump();
          expect(harness.repository.markedIds, isEmpty);
          expect(harness.unread, isTrue);
          await harness.close(tester);
        },
      );
    }
    testWidgets('${source.name} Back during protected load keeps it unread', (
      tester,
    ) async {
      final harness = await _Harness.start(
        tester,
        _Destination.project,
        source: source,
      );
      await harness.open(tester, source);
      harness.router.pop();
      await tester.pumpAndSettle();
      harness.complete(_Destination.project);
      await tester.pump();
      await tester.pump();
      expect(harness.repository.markedIds, isEmpty);
      expect(harness.unread, isTrue);
      await harness.close(tester);
    });
  }

  for (final destination in _Destination.values) {
    testWidgets(
      '${destination.name} OS tap waits for protected data before marking read',
      (tester) async {
        final harness = await _Harness.start(tester, destination);
        expect(harness.repository.markedIds, isEmpty);
        expect(harness.unread, isTrue);

        // The browser has reached the exact URL, but authorized data is pending.
        await tester.pump(const Duration(seconds: 1));
        expect(harness.repository.markedIds, isEmpty);
        expect(harness.unread, isTrue);

        harness.complete(destination);
        await tester.pump();
        await tester.pump();
        expect(harness.repository.markedIds, [_notificationId]);
        expect(harness.unread, isFalse);

        // Returning to this same notification does not duplicate its write.
        harness.router.go('/elsewhere');
        await tester.pumpAndSettle();
        harness.router.go(destination.location);
        await tester.pumpAndSettle();
        expect(harness.repository.markedIds, [_notificationId]);
        await harness.close(tester);
      },
    );

    testWidgets(
      '${destination.name} denied protected load preserves unread state',
      (tester) async {
        final harness = await _Harness.start(tester, destination);
        harness.deny(destination);
        await tester.pump();
        await tester.pump();

        expect(harness.repository.markedIds, isEmpty);
        expect(harness.unread, isTrue);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  testWidgets('leaving the target while it loads preserves unread state', (
    tester,
  ) async {
    final harness = await _Harness.start(tester, _Destination.project);
    harness.router.go('/elsewhere');
    await tester.pumpAndSettle();
    harness.complete(_Destination.project);
    await tester.pump();
    await tester.pump();

    expect(harness.repository.markedIds, isEmpty);
    expect(harness.unread, isTrue);
    await harness.close(tester);
  });

  for (final nextUser in <String?>['another-owner', null]) {
    testWidgets(
      '${nextUser == null ? 'logout' : 'account change'} during a load cannot acknowledge the old owner',
      (tester) async {
        final harness = await _Harness.start(tester, _Destination.project);
        harness.container.read(_testUserProvider.notifier).state =
            nextUser == null ? null : _user(nextUser);
        await tester.pump();
        harness.complete(_Destination.project);
        await tester.pump();
        await tester.pump();

        expect(harness.repository.markedIds, isEmpty);
        expect(harness.unread, isTrue);
        await harness.close(tester);
      },
    );
  }

  testWidgets('disposing the bridge during a load cannot acknowledge it', (
    tester,
  ) async {
    final harness = await _Harness.start(tester, _Destination.project);
    harness.container.invalidate(pushBridgeProvider);
    await tester.pumpWidget(const SizedBox.shrink());
    harness.complete(_Destination.project);
    await tester.pump();
    await tester.pump();

    expect(harness.repository.markedIds, isEmpty);
    expect(harness.unread, isTrue);
    await harness.close(tester);
  });

  for (final path in ['/elsewhere', '/login', '/change-password']) {
    testWidgets('$path does not acknowledge from its query string alone', (
      tester,
    ) async {
      final harness = await _Harness.start(
        tester,
        _Destination.project,
        initialLocation: '$path?notificationId=$_notificationId',
      );
      await tester.pumpAndSettle();
      expect(harness.repository.markedIds, isEmpty);
      expect(harness.unread, isTrue);
      await harness.close(tester);
    });
  }
}

AppNotification _appNotification(String route, {String id = _notificationId}) =>
    AppNotification(
      id: id,
      type: NotificationType.request,
      title: 'Material request approval required',
      titleSecondary: '',
      timestamp: DateTime.now(),
      route: route,
      origin: NotificationOrigin.yorksV1,
    );

class _Harness {
  _Harness(this.router, this.container, this.notifier, this.repository);

  final GoRouter router;
  final ProviderContainer container;
  final YorksV1NotificationsNotifier notifier;
  final _NotificationRepository repository;
  final project = Completer<YorksV1MaterialRequest>();
  final company = Completer<YorksV1CompanyMaterialRequest>();
  final materialReturn = Completer<YorksV1ProjectMaterialReturn>();

  bool get unread => notifier.state.requireValue.single.seenAt == null;

  static Future<_Harness> start(
    WidgetTester tester,
    _Destination destination, {
    String? initialLocation,
    _Source? source,
  }) async {
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation:
          initialLocation ??
          (source == null
              ? destination.location
              : source == _Source.inbox
              ? '/notifications'
              : '/'),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            appBar: AppBar(actions: const [NotificationBell()]),
            body: const Text('Launch workspace'),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        for (final path in [
          '/elsewhere',
          '/login',
          '/change-password',
          for (final entry in _Destination.values) entry.path,
        ])
          GoRoute(path: path, builder: (_, _) => const Scaffold()),
      ],
    );
    final repository = _NotificationRepository();
    repository.record = YorksV1NotificationRecord(
      id: _notificationId,
      eventCode: 'material_request_approval_required',
      entityType: switch (destination) {
        _Destination.project => 'material_request',
        _Destination.company => 'company_material_request',
        _Destination.materialReturn => 'material_return',
      },
      entityId: _entityId,
      requestId: destination == _Destination.project ? _entityId : null,
      createdAt: DateTime.now(),
    );
    final notifier = YorksV1NotificationsNotifier(
      client: null,
      repository: repository,
      authUserId: 'owner',
    );
    await notifier.refresh();
    if (source == _Source.toast) notifier.state = const AsyncData([]);
    late _Harness harness;
    final container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushServiceProvider.overrideWithValue(const NoopPushService()),
        visibleNotificationsProvider.overrideWith(
          (ref) => [
            ...?ref
                .watch(yorksV1NotificationsProvider)
                .valueOrNull
                ?.map(
                  (record) => record.toAppNotification(AppLanguage.english),
                ),
          ],
        ),
        notificationPresentationAllowedProvider.overrideWithValue(() => true),
        notificationAlertSoundDriverProvider.overrideWithValue((
          prepare: () async => false,
          play: () async {},
        )),
        currentUserProvider.overrideWith((ref) => ref.watch(_testUserProvider)),
        yorksV1NotificationPreferencesProvider.overrideWith(
          (_) => YorksV1NotificationPreferencesNotifier(repository: null),
        ),
        yorksV1NotificationsProvider.overrideWith((_) => notifier),
        yorksV1MaterialRequestDetailProvider(_entityId).overrideWith((ref) {
          // Retain a pending response to exercise the completion race after
          // navigation/disposal, as a shared cached loader can do in the app.
          ref.keepAlive();
          return harness.project.future;
        }),
        yorksV1CompanyMaterialRequestProvider(_entityId).overrideWith((ref) {
          ref.keepAlive();
          return harness.company.future;
        }),
        yorksV1ProjectMaterialReturnProvider(_entityId).overrideWith((ref) {
          ref.keepAlive();
          return harness.materialReturn.future;
        }),
      ],
    );
    harness = _Harness(router, container, notifier, repository);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            ref.watch(pushBridgeProvider);
            return MaterialApp.router(
              routerConfig: router,
              builder: (_, child) => source == _Source.toast
                  ? NotificationAlertHost(child: child!)
                  : child!,
            );
          },
        ),
      ),
    );
    await tester.pump();
    return harness;
  }

  Future<void> open(WidgetTester tester, _Source source) async {
    if (source == _Source.bell) {
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
    } else if (source == _Source.toast) {
      notifier.state = AsyncData([repository.record]);
      await tester.pump();
      await tester.pump();
    }
    await tester.tap(
      find.text(
        source == _Source.toast
            ? 'VIEW DETAILS'
            : 'Material request approval required',
      ),
    );
    await tester.pumpAndSettle();
  }

  void complete(_Destination destination) {
    switch (destination) {
      case _Destination.project:
        project.complete(_project);
      case _Destination.company:
        company.complete(_company);
      case _Destination.materialReturn:
        materialReturn.complete(_materialReturn);
    }
  }

  void deny(_Destination destination) {
    final error = StateError('PROTECTED_RECORD_ACCESS_DENIED');
    switch (destination) {
      case _Destination.project:
        project.completeError(error);
      case _Destination.company:
        company.completeError(error);
      case _Destination.materialReturn:
        materialReturn.completeError(error);
    }
  }

  Future<void> close(WidgetTester tester) async {
    YorksAppToast.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    router.dispose();
  }
}

class _NotificationRepository implements YorksV1NotificationRepository {
  final markedIds = <String>[];
  var record = YorksV1NotificationRecord(
    id: _notificationId,
    eventCode: 'material_request_approval_required',
    entityType: 'material_request',
    entityId: _entityId,
    createdAt: DateTime(2026, 9, 30),
  );

  @override
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100}) async => [
    record,
  ];

  @override
  Future<void> markSeen(String notificationId) async {
    markedIds.add(notificationId);
    record = record.acknowledgedAt(DateTime(2026, 10, 1));
  }

  @override
  Future<int> markAllSeen() async => throw UnimplementedError();
}

AppUser _user(String id) => AppUser(
  id: id,
  fullName: 'Owner',
  email: '$id@example.invalid',
  role: UserRole.admin,
  createdAt: DateTime(2026, 9, 30),
);

final _project = YorksV1MaterialRequest(
  id: _entityId,
  projectId: 'project',
  projectReference: 'YRA-001',
  projectName: 'Protected project',
  scopeId: 'scope',
  scopeName: 'Common',
  state: YorksV1MaterialRequestState.awaitingRequestApproval,
  recordVersion: 1,
  createdAt: DateTime(2026, 9, 30),
  updatedAt: DateTime(2026, 9, 30),
  lines: [],
  timing: YorksV1MaterialRequestTiming.normal,
);

const _company = YorksV1CompanyMaterialRequest(
  id: _entityId,
  recordVersion: 1,
  state: 'submitted',
  categoryName: 'Office',
  responsibleUnitName: 'Company',
  purpose: 'Supplies',
  timing: YorksV1MaterialRequestTiming.normal,
  deliveryCollectionPoint: 'Office',
  beneficiary: YorksV1CompanyMaterialRequestPerson(
    authUserId: 'owner',
    displayName: 'Owner',
  ),
  authorizedReceiver: YorksV1CompanyMaterialRequestPerson(
    authUserId: 'receiver',
    displayName: 'Receiver',
  ),
  requesterDisplayName: 'Owner',
  requesterExactRole: 'Admin',
  lines: [],
);

final _materialReturn = YorksV1ProjectMaterialReturn(
  id: _entityId,
  state: YorksV1ProjectMaterialReturnState.awaitingApproval,
  recordVersion: 1,
  projectId: 'project',
  projectReference: 'YRA-001',
  projectName: 'Protected project',
  scopeId: 'scope',
  scopeName: 'Common',
  draftedAt: DateTime(2026, 9, 30),
  draftedByAuthUserId: 'owner',
  draftedByDisplayName: 'Owner',
  draftedByRole: 'Admin',
  canEdit: false,
  canSubmit: false,
  canApprove: true,
  canReturnForChanges: true,
  canDispatch: false,
  canConfirm: false,
  canCancel: false,
  lines: [],
  inventoryItems: [],
);
