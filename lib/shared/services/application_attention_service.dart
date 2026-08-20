import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application_attention_platform.dart';
import 'application_attention_platform_stub.dart'
    if (dart.library.js_interop) 'application_attention_platform_web.dart'
    if (dart.library.io) 'application_attention_platform_native.dart'
    as platform;

const yorksApplicationBaseTitle = 'Yorks AC. & Ref.';
const _maximumDisplayedUnreadCount = 99;

/// Keeps external badge copy compact and consistent across tab, Dock and
/// taskbar surfaces. The underlying count is never altered or capped.
int yorksDisplayedUnreadCount(int unreadCount) =>
    unreadCount.clamp(0, _maximumDisplayedUnreadCount).toInt();

String yorksUnreadBadgeLabel(int unreadCount) {
  final displayed = yorksDisplayedUnreadCount(unreadCount);
  if (displayed == 0) return '';
  return unreadCount > _maximumDisplayedUnreadCount ? '99+' : '$displayed';
}

String yorksApplicationWindowTitle(int unreadCount) {
  final label = yorksUnreadBadgeLabel(unreadCount);
  return label.isEmpty
      ? yorksApplicationBaseTitle
      : '($label) $yorksApplicationBaseTitle';
}

abstract interface class YorksApplicationAttentionService {
  Future<void> update({
    required int unreadCount,
    required bool attentionRaised,
  });
}

class YorksPlatformApplicationAttentionService
    implements YorksApplicationAttentionService {
  YorksPlatformApplicationAttentionService({
    YorksApplicationAttentionPlatform? platform,
  }) : _platform = platform ?? platformFactory();

  final YorksApplicationAttentionPlatform _platform;

  @override
  Future<void> update({
    required int unreadCount,
    required bool attentionRaised,
  }) => _platform.update(
    unreadCount: yorksDisplayedUnreadCount(unreadCount),
    windowTitle: yorksApplicationWindowTitle(unreadCount),
    attentionRaised: attentionRaised,
  );
}

YorksApplicationAttentionPlatform platformFactory() =>
    platform.createYorksApplicationAttentionPlatform();

final yorksApplicationAttentionServiceProvider =
    Provider<YorksApplicationAttentionService>(
      (_) => YorksPlatformApplicationAttentionService(),
    );
