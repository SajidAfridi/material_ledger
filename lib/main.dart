import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'shared/providers/language_provider.dart';
import 'shared/services/app_config_service.dart';
import 'shared/services/observability_service.dart';
import 'shared/services/sentry_observability.dart';
import 'shared/sync/supabase_bootstrap.dart';
import 'shared/sync/supabase_sync_backend.dart';
import 'shared/sync/sync_backend.dart';

/// Sentry DSN, injected at build time:
///   flutter run/build --dart-define=SENTRY_DSN=https://…@…ingest…/…
/// Empty (the default) → crash reporting is OFF and the app uses the no-op
/// reporter, so local/dev builds and anyone without a DSN run unchanged.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
const _appBuild = String.fromEnvironment('APP_BUILD', defaultValue: '1');

/// Backend connection. Production builds MUST be pointed at the real (UAE
/// self-hosted) instance explicitly:
///   --dart-define=SUPABASE_URL=https://your-uae-instance
///   --dart-define=SUPABASE_ANON_KEY=…
const _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _envSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Debug-only convenience: the shared Frankfurt DEMO project (permissive RLS,
/// not UAE-resident). A RELEASE build NEVER falls back to this — so production
/// credentials, RLS, and data-residency can never silently be the demo's. Point
/// a release build at the real backend with the --dart-defines above.
const _demoSupabaseUrl = 'https://czykuksmlwswjsgotrpo.supabase.co';
const _demoSupabaseKey = 'sb_publishable_10ZCSxRXuNhS6x-hYOudpg_hMK3VtY6';

final _supabaseUrl = _envSupabaseUrl.isNotEmpty
    ? _envSupabaseUrl
    : (kReleaseMode ? '' : _demoSupabaseUrl);
final _supabaseAnonKey = _envSupabaseKey.isNotEmpty
    ? _envSupabaseKey
    : (kReleaseMode ? '' : _demoSupabaseKey);

void main() {
  // No DSN configured → boot with the no-op reporter (unchanged behaviour).
  if (_sentryDsn.isEmpty) {
    _bootstrap(const NoopObservability());
    return;
  }
  // DSN present → initialise Sentry, then boot with the Sentry-backed reporter.
  SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const String.fromEnvironment(
        'SENTRY_ENV',
        defaultValue: 'production',
      );
      // Privacy first — this app holds salaries, financials and HR data.
      options.sendDefaultPii = false; // no IP, device name, etc.
      options.beforeBreadcrumb = SentryObservability.scrubBreadcrumb;
      options.beforeSend = SentryObservability.scrubEvent;
      options.attachStacktrace = true;
      // Internal tool, tiny user base → skip performance-tracing overhead.
      options.tracesSampleRate = 0.0;
    },
    appRunner: () => _bootstrap(const SentryObservability()),
  );
}

/// Boots the app with [observability] wired into every error path. Identical
/// whether or not Sentry is active — the seam is the single source of truth, so
/// no call site ever branches on the backend.
void _bootstrap(ObservabilityService observability) {
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

      // Never show the raw red/grey crash box to a (non-technical) user: when a
      // widget fails to build, swap in a calm, self-contained fallback so one bad
      // screen can't take the whole app down. Debug still surfaces the details.
      ErrorWidget.builder = (details) => _CrashFallback(details: details);

      final prefs = await SharedPreferences.getInstance();

      // Installed version/build — drives the force-update gate + version footers.
      final versionInfo = AppVersionInfo(
        version: _appVersion,
        build: int.tryParse(_appBuild) ?? 1,
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

      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        appVersionProvider.overrideWithValue(versionInfo),
        observabilityProvider.overrideWithValue(observability),
      ];

      // Point the sync seam at Supabase when configured; otherwise the local
      // backend keeps the app fully offline-capable.
      if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
        await Supabase.initialize(
          url: _supabaseUrl,
          // Public client key (anon-equivalent). A self-hosted instance supplies
          // its own here.
          publishableKey: _supabaseAnonKey,
        );
        final client = Supabase.instance.client;
        // Expose the client so the auth layer signs in against Supabase Auth,
        // and route data writes through the authenticated sync backend.
        overrides.add(supabaseClientProvider.overrideWithValue(client));
        overrides.add(
          syncBackendProvider.overrideWithValue(SupabaseSyncBackend(client)),
        );
        // Launch hydrate ONLY when a real session was restored: strict RLS
        // denies anonymous reads, so pre-login hydration would fetch nothing.
        // A returning user's session is recovered by initialize() above, so the
        // request carries their JWT and returns exactly their permitted rows.
        // Best-effort — never blocks launch.
        if (client.auth.currentSession != null) {
          await SupabaseBootstrap(client, prefs).run();
        } else {
          // No live Supabase session → clear any stale app session so the app
          // opens at login rather than a "ghost" signed-in state whose writes
          // RLS would silently deny.
          await prefs.remove(kAuthUserIdPrefKey);
        }
      }

      runApp(
        ProviderScope(
          overrides: overrides,
          child: const MaterialLedgerApp(),
        ),
      );
    },
    // Uncaught async errors.
    (error, stack) => observability.recordError(error, stack, fatal: true),
  );
}

/// Calm replacement for Flutter's red/grey error box. Fully self-contained (no
/// theme, Material, or Directionality ancestor required) so it renders wherever
/// a widget failed — the rest of the app keeps working around it.
class _CrashFallback extends StatelessWidget {
  const _CrashFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFF7F9FB),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFF9AA0A6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please go back and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                '${details.exception}',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFFB00020)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
