import 'dart:js_interop';

import '../models/analytics_configuration.dart';
import '../models/analytics_event.dart';
import 'analytics_service.dart';
import 'posthog_web_bootstrap.dart';

@JS('posthog.identify')
external JSAny? _identify(JSString userId, JSAny properties);

@JS('posthog.reset')
external JSAny? _reset();

@JS('posthog.capture')
external JSAny? _capture(JSString eventName, JSAny properties);

@JS('yorksPostHogFeatureEnabled')
external JSBoolean _featureEnabled(JSString key);

class PostHogAnalyticsSink implements AnalyticsSink {
  const PostHogAnalyticsSink();

  static final Set<String> _allowedEvents = {
    for (final event in AnalyticsEvent.values) event.wireName,
  };
  static final Set<String> _allowedProperties = {
    for (final property in AnalyticsProperty.values) property.wireName,
  };

  @override
  Future<void> initialize(AnalyticsConfiguration configuration) =>
      bootstrapPostHogWeb(
        projectToken: configuration.projectToken.trim(),
        host: configuration.validatedHost!.toString(),
        debug: configuration.debug,
      );

  @override
  Future<void> identify({required String userId, required String role}) async {
    _identify(userId.toJS, <String, Object>{'role': role}.jsify()!);
  }

  @override
  Future<void> reset() async {
    _reset();
  }

  @override
  Future<void> capture({
    required String eventName,
    required Map<String, Object> properties,
  }) async {
    if (!_allowedEvents.contains(eventName)) return;
    _capture(eventName.toJS, _safeProperties(properties).jsify()!);
  }

  @override
  Future<void> screen({
    required String screenName,
    required Map<String, Object> properties,
  }) async {
    _capture(
      r'$screen'.toJS,
      <String, Object>{
        r'$screen_name': screenName,
        ..._safeProperties(properties),
      }.jsify()!,
    );
  }

  @override
  Future<bool> isFeatureEnabled(String key) async =>
      _featureEnabled(key.toJS).toDart;

  Map<String, Object> _safeProperties(Map<String, Object> properties) => {
    for (final entry in properties.entries)
      if (_allowedProperties.contains(entry.key)) entry.key: entry.value,
  };
}
