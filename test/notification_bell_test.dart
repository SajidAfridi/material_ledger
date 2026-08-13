import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/widgets/notification_bell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('desktop bell opens the recent notification panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notification = AppNotification(
      id: 'notification-1',
      type: NotificationType.request,
      title: 'Material request approval required',
      titleSecondary: '',
      body: 'A material request is ready for Engineering approval.',
      timestamp: DateTime.now(),
      origin: NotificationOrigin.yorksV1,
    );
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          pushServiceProvider.overrideWithValue(const NoopPushService()),
          visibleNotificationsProvider.overrideWithValue([notification]),
          unreadNotificationCountProvider.overrideWithValue(1),
        ],
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(actions: [NotificationBell()])),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Recent notifications'), findsOneWidget);
    expect(find.text('Material request approval required'), findsOneWidget);
    expect(find.text('View all notifications'), findsOneWidget);
    expect(find.text('System alerts are unavailable here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
