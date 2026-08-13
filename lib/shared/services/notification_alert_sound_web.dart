import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.AudioContext? _audioContext;

/// Browsers suspend Web Audio until the user interacts with the page. The app
/// calls this from the first pointer event and from the explicit Enable alerts
/// action so later foreground workflow alerts can make a short, professional
/// chime without bundling or downloading an audio file.
Future<void> prepareNotificationAlertSound() async {
  try {
    final context = _audioContext ??= web.AudioContext();
    if (context.state != 'running') await context.resume().toDart;
  } catch (_) {
    // Browser/OS policy remains authoritative. Visual alerts still work.
  }
}

Future<void> playNotificationAlertSound() async {
  try {
    final context = _audioContext;
    if (context == null || context.state != 'running') return;
    final start = context.currentTime;
    final oscillator = context.createOscillator();
    final gain = context.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(660, start);
    oscillator.frequency.exponentialRampToValueAtTime(880, start + .12);
    gain.gain.setValueAtTime(.0001, start);
    gain.gain.exponentialRampToValueAtTime(.18, start + .025);
    gain.gain.exponentialRampToValueAtTime(.0001, start + .22);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(start);
    oscillator.stop(start + .24);
  } catch (_) {
    // Muted tabs, autoplay policy and OS focus modes may suppress audio.
  }
}
