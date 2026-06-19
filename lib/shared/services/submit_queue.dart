import 'dart:async';

/// Connection-resilient submit seam.
///
/// On site, the engineer's network is often patchy. Today every mutation runs
/// against local storage and always succeeds, so this queue simply runs the
/// action immediately. It exists as the single, documented place where offline
/// behaviour will live: when Firebase lands, this becomes the wrapper around
/// Firestore writes with offline persistence — failed writes are enqueued and
/// auto-flushed on reconnect, and [pending] drives a "syncing…" indicator.
///
/// Keeping all mutating call sites funnelling through `submit(...)` means that
/// upgrade is a change in one file, not across the app.
class SubmitQueue {
  SubmitQueue._();
  static final SubmitQueue instance = SubmitQueue._();

  final List<Future<void> Function()> _queued = [];

  /// Number of actions waiting to sync (always 0 in the local prototype).
  int get pending => _queued.length;

  /// Run [action] now. In the local prototype this is a pass-through; the
  /// signature is the seam that gains retry/queue semantics under Firebase.
  Future<T> submit<T>(Future<T> Function() action) async {
    return action();
  }
}
