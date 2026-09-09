import 'package:flutter/foundation.dart';

enum AnalyticsEnvironment {
  local,
  staging,
  production,
  ci,
  unknown;

  static AnalyticsEnvironment parse(String value) => switch (value.trim()) {
    'local' || 'development' => local,
    'staging' => staging,
    'production' => production,
    'ci' => ci,
    _ => unknown,
  };
}

enum AnalyticsPlatform {
  web,
  android,
  ios,
  macos,
  windows,
  linux,
  unknown;

  static AnalyticsPlatform current() {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      TargetPlatform.fuchsia => unknown,
    };
  }

  bool get supportsPostHog =>
      this == web || this == android || this == ios || this == macos;
}

/// Build-time configuration for product telemetry. This is intentionally
/// separate from `YORKS_V1_ANALYTICS`, which controls Yorks' server-authorized
/// operational reporting product rather than external product analytics.
class AnalyticsConfiguration {
  const AnalyticsConfiguration({
    required this.requestedEnabled,
    required this.projectToken,
    required this.host,
    required this.environment,
    required this.platform,
    required this.appVersion,
    required this.appBuild,
    this.debugRequested = false,
  });

  factory AnalyticsConfiguration.fromEnvironment({
    required String appVersion,
    required String appBuild,
  }) => AnalyticsConfiguration(
    requestedEnabled: const bool.fromEnvironment('POSTHOG_ENABLED'),
    projectToken: const String.fromEnvironment('POSTHOG_PROJECT_TOKEN'),
    host: const String.fromEnvironment(
      'POSTHOG_HOST',
      defaultValue: 'https://us.i.posthog.com',
    ),
    environment: resolveEnvironment(
      postHogValue: const String.fromEnvironment('POSTHOG_ENV'),
      r35Value: const String.fromEnvironment('R35_ENVIRONMENT'),
    ),
    platform: AnalyticsPlatform.current(),
    appVersion: appVersion,
    appBuild: appBuild,
    debugRequested: const bool.fromEnvironment('POSTHOG_DEBUG'),
  );

  final bool requestedEnabled;
  final String projectToken;
  final String host;
  final AnalyticsEnvironment environment;
  final AnalyticsPlatform platform;
  final String appVersion;
  final String appBuild;
  final bool debugRequested;

  static final RegExp _projectToken = RegExp(r'^[A-Za-z0-9._-]+$');

  /// Repeats the launcher's environment boundary inside the Dart artifact so
  /// a direct `flutter build` cannot accidentally send one Yorks environment
  /// to another environment's PostHog project.
  static AnalyticsEnvironment resolveEnvironment({
    required String postHogValue,
    required String r35Value,
  }) {
    final appEnvironment = AnalyticsEnvironment.parse(r35Value);
    final analyticsEnvironment = AnalyticsEnvironment.parse(
      postHogValue.trim().isEmpty ? r35Value : postHogValue,
    );
    return analyticsEnvironment == appEnvironment
        ? analyticsEnvironment
        : AnalyticsEnvironment.unknown;
  }

  bool get debug =>
      debugRequested && kDebugMode && environment == AnalyticsEnvironment.local;

  Uri? get validatedHost {
    final uri = Uri.tryParse(host.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  bool get isValid =>
      _projectToken.hasMatch(projectToken.trim()) && validatedHost != null;

  /// CI is always silent, and unsupported desktop targets are safe no-ops.
  bool get enabled =>
      requestedEnabled &&
      environment != AnalyticsEnvironment.ci &&
      environment != AnalyticsEnvironment.unknown &&
      platform.supportsPostHog &&
      isValid;
}
