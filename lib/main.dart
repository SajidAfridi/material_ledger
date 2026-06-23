import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'shared/providers/language_provider.dart';
import 'shared/services/app_config_service.dart';
import 'shared/services/observability_service.dart';

void main() {
  // Single observability instance wired into every error path. Swap this for a
  // Crashlytics / Sentry implementation in production — nothing else changes.
  const observability = NoopObservability();

  runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();

      // Framework + platform errors → crash reporting.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        observability.recordError(details.exception, details.stack, fatal: true);
      };
      binding.platformDispatcher.onError = (error, stack) {
        observability.recordError(error, stack, fatal: true);
        return true;
      };

      final prefs = await SharedPreferences.getInstance();

      // Installed version/build — drives the force-update gate + version footers.
      final pkg = await PackageInfo.fromPlatform();
      final versionInfo = AppVersionInfo(
        version: pkg.version,
        build: int.tryParse(pkg.buildNumber) ?? 1,
      );

      // Set system UI style to match the light, open aesthetic
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appVersionProvider.overrideWithValue(versionInfo),
            observabilityProvider.overrideWithValue(observability),
          ],
          child: const MaterialLedgerApp(),
        ),
      );
    },
    // Uncaught async errors.
    (error, stack) => observability.recordError(error, stack, fatal: true),
  );
}
