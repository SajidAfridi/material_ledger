import 'dart:async';

/// Reconciles a locale changed during serialized device registration. The
/// latest choice is read again after the server responds, while account and
/// installation fences stop work immediately after retirement.
Future<bool> syncCurrentPushLanguage({
  required String Function() readLanguage,
  required bool Function() isCurrent,
  required Future<bool> Function(String) update,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final budget = Stopwatch()..start();
  // Continuous toggling cannot hold enrollment open indefinitely. A later
  // resume or explicit retry reconciles an installation that did not settle.
  for (var attempt = 0; attempt < 3; attempt++) {
    if (!isCurrent()) return false;
    final language = readLanguage();
    final remaining = timeout - budget.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('PUSH_LANGUAGE_UPDATE_TIMEOUT', timeout);
    }
    final saved = await update(language).timeout(remaining);
    if (!saved || !isCurrent()) return false;
    if (language == readLanguage()) return true;
  }
  return false;
}
