import 'application_attention_platform.dart';

YorksApplicationAttentionPlatform createYorksApplicationAttentionPlatform() =>
    const _NoopYorksApplicationAttentionPlatform();

class _NoopYorksApplicationAttentionPlatform
    implements YorksApplicationAttentionPlatform {
  const _NoopYorksApplicationAttentionPlatform();

  @override
  Future<void> update({
    required int unreadCount,
    required String windowTitle,
    required bool attentionRaised,
  }) async {}
}
