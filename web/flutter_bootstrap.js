{{flutter_js}}
{{flutter_build_config}}

// Do not block first paint on service-worker installation. PushService retains
// explicit FCM worker registration after sign-in. Flutter's generated worker
// is now a cleanup stub, not an offline cache, and must not own the FCM scope.
_flutter.loader.load();
