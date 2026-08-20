import 'package:flutter/services.dart';

const _nativeAlertChannel = MethodChannel(
  'com.yorks.app/application_attention',
);

/// Native platforms already have a system alert tone. Preparation is a no-op;
/// it exists to match the browser implementation, where audio must be unlocked
/// by a user gesture.
Future<bool> prepareNotificationAlertSound() async => true;

Future<void> playNotificationAlertSound() async {
  await HapticFeedback.lightImpact();
  try {
    // Android and iOS intentionally ignore Flutter's SystemSound alert type.
    // The host bridges below play the operating system's notification tone;
    // desktop hosts use their normal system alert. Device volume, silent mode
    // and Focus/Do Not Disturb remain authoritative.
    await _nativeAlertChannel.invokeMethod<void>('playNotificationAlert');
  } on MissingPluginException {
    await SystemSound.play(SystemSoundType.alert);
  } on PlatformException {
    await SystemSound.play(SystemSoundType.alert);
  }
}
