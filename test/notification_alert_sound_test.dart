import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/services/notification_alert_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native foreground alert requests the host notification tone', () async {
    const channel = MethodChannel('com.yorks.app/application_attention');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    expect(await prepareNotificationAlertSound(), isTrue);
    await playNotificationAlertSound();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'playNotificationAlert');
  });
}
