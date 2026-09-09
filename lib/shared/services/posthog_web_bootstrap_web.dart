import 'dart:js_interop';

@JS('yorksPostHogBootstrap')
external void _bootstrapPostHogWeb(
  JSString projectToken,
  JSString host,
  JSBoolean debug,
);

Future<void> bootstrapPostHogWeb({
  required String projectToken,
  required String host,
  required bool debug,
}) async {
  _bootstrapPostHogWeb(projectToken.toJS, host.toJS, debug.toJS);
}
