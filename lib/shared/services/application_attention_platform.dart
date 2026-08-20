/// Platform bridge for the Yorks app-level unread indication.
///
/// The platform surface is deliberately presentation-only. The authoritative
/// unread state remains in the recipient notification rows and Team Chat
/// member cursor; this bridge only mirrors that resolved count where the user
/// can notice it outside the open application.
abstract interface class YorksApplicationAttentionPlatform {
  Future<void> update({
    required int unreadCount,
    required String windowTitle,
    required bool attentionRaised,
  });
}
