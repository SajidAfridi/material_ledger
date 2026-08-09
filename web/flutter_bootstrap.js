{{flutter_js}}
{{flutter_build_config}}

// FCM and Flutter's PWA cache both require the origin-wide service-worker
// scope. Register the FCM worker as the one owner; it imports Flutter's
// generated cache worker before adding its push handlers.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerUrl:
      'firebase-messaging-sw.js?v=' + {{flutter_service_worker_version}},
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
