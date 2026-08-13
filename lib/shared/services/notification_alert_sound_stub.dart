import 'package:flutter/services.dart';

/// Native platforms already have a system alert tone. Preparation is a no-op;
/// it exists to match the browser implementation, where audio must be unlocked
/// by a user gesture.
Future<void> prepareNotificationAlertSound() async {}

Future<void> playNotificationAlertSound() async {
  await HapticFeedback.lightImpact();
  await SystemSound.play(SystemSoundType.alert);
}
