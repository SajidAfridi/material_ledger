import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/app/app.dart' show appRouterProvider;
import 'package:material_ledger/core/widgets/yorks_app_toast.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/widgets/notification_alert_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(YorksAppToast.dismiss);

  testWidgets('foreground alert is compact, dismissible, and expires', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushServiceProvider.overrideWithValue(const NoopPushService()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NotificationAlertHost(child: Scaffold(body: Text('Workspace'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.request,
          title: 'Arrangement ready for review',
          titleSecondary: '',
          body:
              'Procurement submitted an arrangement for Engineering approval.',
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Arrangement ready for review'), findsOneWidget);
    expect(
      find.text(
        'Procurement submitted an arrangement for Engineering approval.',
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(Dismissible), findsOneWidget);
    expect(
      tester.getSize(find.byType(Dismissible)).width,
      lessThanOrEqualTo(560),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Arrangement ready for review'), findsNothing);

    await container
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.info,
          title: 'Delivery ready',
          titleSecondary: '',
          body: 'Materials are ready for receipt review.',
        );
    await tester.pump();
    await tester.pump();
    expect(find.text('Delivery ready'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text('Delivery ready'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Delivery ready'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('foreground alert detail action marks read and navigates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Workspace')),
        ),
        GoRoute(
          path: '/details',
          builder: (_, _) => const Scaffold(body: Text('Request details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushServiceProvider.overrideWithValue(const NoopPushService()),
        appRouterProvider.overrideWithValue(router),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => NotificationAlertHost(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await container
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.info,
          title: 'You were mentioned',
          titleSecondary: '',
          body: 'A teammate mentioned you in a comment.',
          route: '/details',
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('VIEW DETAILS'));
    await tester.pumpAndSettle();

    expect(find.text('Request details'), findsOneWidget);
    expect(find.text('You were mentioned'), findsNothing);
    expect(container.read(notificationsProvider).first.isRead, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('the open exact Team Chat thread suppresses duplicate alerts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/yorks/team-chat/conversation-1',
      routes: [
        GoRoute(
          path: '/yorks/team-chat/:conversationId',
          builder: (_, state) => Scaffold(
            body: Text('Chat ${state.pathParameters['conversationId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushServiceProvider.overrideWithValue(const NoopPushService()),
        appRouterProvider.overrideWithValue(router),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => NotificationAlertHost(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await container
        .read(notificationsProvider.notifier)
        .add(
          type: NotificationType.info,
          title: 'New chat message',
          titleSecondary: '',
          body: 'A teammate sent a message.',
          route: '/yorks/team-chat/conversation-1',
        );
    await tester.pumpAndSettle();

    expect(find.text('Chat conversation-1'), findsOneWidget);
    expect(find.text('New chat message'), findsNothing);
    expect(container.read(notificationsProvider).first.isRead, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
