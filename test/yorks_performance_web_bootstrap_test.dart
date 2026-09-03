import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter first paint never awaits push worker installation', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('_flutter.loader.load('));
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, isNot(contains('serviceWorkerVersion')));
  });

  test(
    'FCM does not execute Flutter worker unregistration or client reload',
    () {
      final worker = File('web/firebase-messaging-sw.js').readAsStringSync();
      expect(
        worker,
        isNot(contains("importScripts('flutter_service_worker.js')")),
      );
      expect(worker, isNot(contains('registration.unregister')));
      expect(worker, contains('firebase-messaging-compat.js'));
      expect(worker, contains('messaging.onBackgroundMessage'));
      expect(worker, contains("addEventListener('notificationclick'"));
      final push = File(
        'lib/shared/services/push_service.dart',
      ).readAsStringSync();
      expect(
        push,
        contains("serviceWorkerScriptPath: 'firebase-messaging-sw.js'"),
      );
    },
  );
}
