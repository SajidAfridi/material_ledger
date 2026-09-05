import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web boot starts Flutter immediately and owns no blocking worker wait',
    () {
      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      final messagingWorker = File(
        'web/firebase-messaging-sw.js',
      ).readAsStringSync();

      expect(bootstrap, contains('_flutter.loader.load'));
      expect(bootstrap, contains('onEntrypointLoaded'));
      expect(bootstrap, isNot(contains('serviceWorkerSettings')));
      expect(
        messagingWorker,
        isNot(contains("importScripts('flutter_service_worker.js')")),
      );
    },
  );

  test('web has an immediate accessible loader and a recoverable timeout', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('data-yorks-boot-status'));
    expect(html, contains('flutter-first-frame'));
    expect(html, contains('yorks-boot-retry'));
    expect(html, contains('prefers-reduced-motion'));
    expect(html, contains('role="status"'));
  });

  test('startup documents are never pinned behind stale edge caches', () {
    final vercel = File('web/vercel.json').readAsStringSync();
    final manifest = File('web/manifest.json').readAsStringSync();
    final verifier = File(
      'tool/verify-yorks-web-release.mjs',
    ).readAsStringSync();

    expect(vercel, contains('index.html|flutter_bootstrap.js|main.dart.js'));
    expect(verifier, contains("file.endsWith('.part.js')"));
    expect(vercel, contains('max-age=0, must-revalidate'));
    expect(manifest, contains('#041E42'));
  });
}
