import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Yorks product analytics facade.
///
/// Business code should depend on this service rather than calling PostHog
/// directly. Analytics is always best-effort: failures never affect the user's
/// workflow.
class YorksAnalytics {
  YorksAnalytics._();

  static final YorksAnalytics instance = YorksAnalytics._();

  bool _enabled = false;
  bool _initialized = false;
  String? _identifiedUserId;
  ({String userId, String role})? _pendingIdentity;

  bool get isEnabled => _enabled && _initialized;
  bool get hasIdentifiedUser => _identifiedUserId != null;

  Future<void> initialize({
    required String apiKey,
    required String host,
    required String environment,
    required String appVersion,
    required String appBuild,
    bool debug = false,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty || _initialized) return;

    final config = PostHogConfig(key)
      ..host = host.trim().isEmpty ? 'https://us.i.posthog.com' : host.trim()
      ..debug = debug
      ..captureApplicationLifecycleEvents = true
      ..personProfiles = PostHogPersonProfiles.identifiedOnly
      ..surveys = false
      // Session replay stays OFF by default for Yorks. The product contains
      // project, finance, HR, supplier and document data. Replay may only be
      // enabled after masked recordings are explicitly validated in staging.
      ..sessionReplay = false
      ..sessionReplayConfig.maskAllTexts = true
      ..sessionReplayConfig.maskAllImages = true;

    // Do not duplicate Sentry. PostHog is product/UX analytics here, while
    // Sentry remains the crash/error authority.
    config.errorTrackingConfig.captureFlutterErrors = false;
    config.errorTrackingConfig.capturePlatformDispatcherErrors = false;

    // Every event carries low-risk build context. Never attach PII, free text,
    // business document contents or commercial values here.
    config.beforeSend = [
      (event) {
        event.properties ??= <String, Object>{};
        event.properties!['yorks_environment'] = environment;
        event.properties!['yorks_app_version'] = appVersion;
        event.properties!['yorks_app_build'] = appBuild;
        event.properties!['analytics_schema_version'] = 1;
        return event;
      },
    ];

    try {
      await Posthog().setup(config);
      _enabled = true;
      _initialized = true;
      unawaited(capture('analytics initialized'));
      final pending = _pendingIdentity;
      _pendingIdentity = null;
      if (pending != null) {
        unawaited(identify(userId: pending.userId, role: pending.role));
      }
    } catch (error, stack) {
      _enabled = false;
      _initialized = false;
      if (kDebugMode) {
        debugPrint('[analytics] PostHog setup failed: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  Future<void> identify({
    required String userId,
    required String role,
  }) async {
    final normalizedId = userId.trim();
    final normalizedRole = role.trim();
    if (normalizedId.isEmpty) return;
    if (!isEnabled) {
      _pendingIdentity = (userId: normalizedId, role: normalizedRole);
      return;
    }
    if (_identifiedUserId == normalizedId) return;
    try {
      await Posthog().identify(
        userId: normalizedId,
        userProperties: <String, Object>{
          if (normalizedRole.isNotEmpty) 'role': normalizedRole,
        },
      );
      _identifiedUserId = normalizedId;
      await capture(
        'user identified',
        properties: <String, Object?>{
          if (normalizedRole.isNotEmpty) 'role': normalizedRole,
        },
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[analytics] identify failed: $error');
    }
  }

  Future<void> reset() async {
    _pendingIdentity = null;
    if (!isEnabled || _identifiedUserId == null) return;
    try {
      await Posthog().reset();
      _identifiedUserId = null;
    } catch (error) {
      if (kDebugMode) debugPrint('[analytics] reset failed: $error');
    }
  }

  Future<void> capture(
    String eventName, {
    Map<String, Object?> properties = const {},
  }) async {
    if (!isEnabled) return;
    final sanitized = _sanitize(properties);
    try {
      await Posthog().capture(
        eventName: eventName,
        properties: sanitized.isEmpty ? null : sanitized,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[analytics] capture failed: $error');
    }
  }

  Future<void> screen(
    String screenName, {
    Map<String, Object?> properties = const {},
  }) async {
    if (!isEnabled) return;
    final sanitized = _sanitize(properties);
    try {
      await Posthog().screen(
        screenName: screenName,
        properties: sanitized.isEmpty ? null : sanitized,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[analytics] screen failed: $error');
    }
  }

  Future<T> timed<T>(
    String operation,
    Future<T> Function() action, {
    Map<String, Object?> properties = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      unawaited(
        capture(
          '$operation completed',
          properties: <String, Object?>{
            ...properties,
            'duration_ms': stopwatch.elapsedMilliseconds,
            'success': true,
          },
        ),
      );
      return result;
    } catch (_) {
      stopwatch.stop();
      unawaited(
        capture(
          '$operation failed',
          properties: <String, Object?>{
            ...properties,
            'duration_ms': stopwatch.elapsedMilliseconds,
            'success': false,
          },
        ),
      );
      rethrow;
    }
  }

  Map<String, Object> _sanitize(Map<String, Object?> source) {
    final result = <String, Object>{};
    for (final entry in source.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || _isSensitiveKey(key)) continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is String) {
        // Only structured labels should be sent. Long text is likely user or
        // business content, so reject it at the central boundary.
        final cleaned = value.trim();
        if (cleaned.isEmpty || cleaned.length > 120) continue;
        result[key] = cleaned;
      } else if (value is num || value is bool) {
        result[key] = value;
      } else if (value is List) {
        final safe = value
            .where((item) => item is String || item is num || item is bool)
            .take(20)
            .toList(growable: false);
        if (safe.isNotEmpty) result[key] = safe;
      }
    }
    return result;
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    final words = normalized.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);
    const blockedWords = <String>{
      'name',
      'email',
      'phone',
      'password',
      'token',
      'otp',
      'comment',
      'note',
      'description',
      'filename',
      'supplier',
      'client',
      'consultant',
      'contractor',
      'invoice',
      'bank',
      'salary',
      'amount',
      'price',
      'cost',
    };
    return words.any(blockedWords.contains) ||
        normalized.contains('search_query') ||
        normalized.contains('query_text') ||
        normalized.contains('file_name') ||
        normalized.contains('access_token') ||
        normalized.contains('refresh_token');
  }
}
