import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/widgets/notification_alert_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a new visible notification raises a foreground alert', (
    tester,
  ) async {
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
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
