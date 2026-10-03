import 'package:web/web.dart' as web;

// Only the focused visible tab owns foreground interruptions. Hidden tabs
// still refresh durable history and badges without sounding or showing toast.
bool get mayPresentNotification =>
    web.document.visibilityState == 'visible' && web.document.hasFocus();
