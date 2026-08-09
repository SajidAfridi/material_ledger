import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/screens/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final evidence in <({String name, Size size})>[
    (name: 'notification_center_desktop.png', size: const Size(1366, 768)),
    (name: 'notification_center_mobile.png', size: const Size(360, 800)),
  ]) {
    testWidgets('authoritative notification centre — ${evidence.size}', (
      tester,
    ) async {
      tester.view.physicalSize = evidence.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final notification = AppNotification(
        id: '21000000-0000-4000-8000-000000000001',
        type: NotificationType.request,
        title: 'New material request',
        titleSecondary: '',
        body: 'A material request is ready for Procurement arrangement.',
        timestamp: DateTime.now(),
        refId: '22000000-0000-4000-8000-000000000001',
        route: '/yorks/material-requests/22000000-0000-4000-8000-000000000001',
        origin: NotificationOrigin.yorksV1,
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
        ],
      );
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            visibleNotificationsProvider.overrideWithValue([notification]),
            unreadNotificationCountProvider.overrideWithValue(1),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New material request'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.byType(Dismissible), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(NotificationsScreen),
        matchesGoldenFile('goldens/r35/${evidence.name}'),
      );
    });
  }
}
