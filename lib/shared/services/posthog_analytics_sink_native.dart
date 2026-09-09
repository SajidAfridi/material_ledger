import 'package:posthog_flutter/posthog_flutter.dart';

import '../models/analytics_configuration.dart';
import '../models/analytics_event.dart';
import 'analytics_service.dart';

class PostHogAnalyticsSink implements AnalyticsSink {
  const PostHogAnalyticsSink();

  static final Set<String> _allowedEvents = {
    for (final event in AnalyticsEvent.values) event.wireName,
    r'$screen',
  };
  static final Set<String> _allowedProperties = {
    for (final property in AnalyticsProperty.values) property.wireName,
    r'$screen_name',
  };

  @override
  Future<void> initialize(AnalyticsConfiguration configuration) async {
    final config =
        PostHogConfig(
            configuration.projectToken.trim(),
            beforeSend: [
              (event) {
                if (!_allowedEvents.contains(event.event)) return null;
                final properties = event.properties;
                if (properties != null) {
                  properties.removeWhere(
                    (key, _) => !_allowedProperties.contains(key),
                  );
                }
                // Person properties are accepted only through the explicit
                // identify call, where role is the sole allowlisted dimension.
                event.userProperties = null;
                event.userPropertiesSetOnce = null;
                return event;
              },
            ],
          )
          ..host = configuration.validatedHost!.toString()
          ..debug = configuration.debug
          ..captureApplicationLifecycleEvents = false
          ..capturePushNotificationSubscriptions = false
          ..capturePushNotificationOpened = false
          ..surveys = false
          ..sessionReplay = false
          ..sendFeatureFlagEvents = false
          ..personProfiles = PostHogPersonProfiles.identifiedOnly
          ..rageClickConfig.enabled = false;
    config.errorTrackingConfig
      ..captureFlutterErrors = false
      ..captureSilentFlutterErrors = false
      ..capturePlatformDispatcherErrors = false
      ..captureNativeExceptions = false
      ..captureIsolateErrors = false;
    await Posthog().setup(config);
  }

  @override
  Future<void> identify({required String userId, required String role}) =>
      Posthog().identify(userId: userId, userProperties: {'role': role});

  @override
  Future<void> reset() => Posthog().reset();

  @override
  Future<void> capture({
    required String eventName,
    required Map<String, Object> properties,
  }) => Posthog().capture(eventName: eventName, properties: properties);

  @override
  Future<void> screen({
    required String screenName,
    required Map<String, Object> properties,
  }) => Posthog().screen(screenName: screenName, properties: properties);

  @override
  Future<bool> isFeatureEnabled(String key) async {
    final result = await Posthog().getFeatureFlagResult(key, sendEvent: false);
    return result?.enabled ?? false;
  }
}
