import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/posthog_analytics.dart';
import 'yorks_v1_identity_provider.dart';

// Match Yorks' existing environment contract. External product telemetry is an
// explicit opt-in and remains a no-op unless POSTHOG_ENABLED=true and a project
// token is supplied. POSTHOG_API_KEY is retained only as a temporary backwards-
// compatible alias for builds created from the first analytics branch revision.
const _posthogEnabled = bool.fromEnvironment('POSTHOG_ENABLED');
const _posthogProjectToken = String.fromEnvironment('POSTHOG_PROJECT_TOKEN');
const _legacyPosthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');
const _posthogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://us.i.posthog.com',
);
const _posthogEnvironment = String.fromEnvironment(
  'POSTHOG_ENV',
  defaultValue: 'production',
);
const _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);
const _appBuild = String.fromEnvironment('APP_BUILD', defaultValue: '1');
const _posthogDebug = bool.fromEnvironment('POSTHOG_DEBUG');

/// Starts PostHog without putting analytics on Yorks' startup critical path.
/// With telemetry disabled or no project token the entire layer is a safe no-op.
final posthogAnalyticsBootstrapProvider = Provider<void>((ref) {
  if (!_posthogEnabled) return;

  final token = _posthogProjectToken.trim().isNotEmpty
      ? _posthogProjectToken
      : _legacyPosthogApiKey;
  if (token.trim().isEmpty) return;

  unawaited(
    YorksAnalytics.instance.initialize(
      apiKey: token,
      host: _posthogHost,
      environment: _posthogEnvironment,
      appVersion: _appVersion,
      appBuild: _appBuild,
      debug: _posthogDebug && kDebugMode,
    ),
  );
});

/// Keeps PostHog identity aligned with the authoritative Yorks authentication
/// lifecycle. Only the stable Auth UUID and role claim are shared.
final posthogAnalyticsIdentityProvider = Provider<void>((ref) {
  ref.watch(posthogAnalyticsBootstrapProvider);
  if (!_posthogEnabled) return;

  final userId = ref.watch(yorksV1AuthUserIdProvider);
  final role = ref.watch(yorksV1CurrentRoleProvider);

  if (userId == null || userId.trim().isEmpty) {
    unawaited(YorksAnalytics.instance.reset());
    return;
  }

  unawaited(
    YorksAnalytics.instance.identify(
      userId: userId,
      role: role?.claimValue ?? 'unknown',
    ),
  );
});

/// Converts live URLs to stable, privacy-safe analytics screen names. Dynamic
/// entity UUIDs are deliberately never sent to PostHog.
String yorksAnalyticsScreenName(String path) {
  final normalized = path.isEmpty ? '/' : path;

  if (normalized == '/') return 'home';
  if (normalized == '/login') return 'login';
  if (normalized == '/splash') return 'splash';
  if (normalized == '/language-selection') return 'language_selection';
  if (normalized == '/change-password') return 'change_password';
  if (normalized == '/materials') return 'materials';
  if (normalized == '/projects' || normalized == '/my-projects') {
    return 'projects';
  }
  if (normalized == '/projects/new') return 'project_create';
  if (RegExp(r'^/projects/[^/]+$').hasMatch(normalized)) {
    return 'project_detail';
  }

  if (normalized == '/yorks/projects') return 'projects';
  if (RegExp(r'^/yorks/projects/[^/]+/edit$').hasMatch(normalized)) {
    return 'project_edit';
  }
  if (RegExp(r'^/yorks/projects/[^/]+/boq/[^/]+$').hasMatch(normalized)) {
    return 'boq_worksheet';
  }
  if (RegExp(r'^/yorks/projects/[^/]+/boq$').hasMatch(normalized)) {
    return 'boq_groups';
  }
  if (RegExp(r'^/yorks/projects/[^/]+/documents$').hasMatch(normalized)) {
    return 'project_documents';
  }
  if (RegExp(r'^/yorks/projects/[^/]+/accounts').hasMatch(normalized)) {
    return 'project_accounts';
  }
  if (RegExp(r'^/yorks/projects/[^/]+$').hasMatch(normalized)) {
    return 'project_detail';
  }

  if (normalized == '/yorks/material-requests') return 'material_requests';
  if (RegExp(r'^/yorks/material-requests/draft/[^/]+$').hasMatch(normalized)) {
    return 'material_request_create';
  }
  if (RegExp(r'^/yorks/material-requests/[^/]+/arrangement$').hasMatch(normalized)) {
    return 'material_request_arrangement';
  }
  if (RegExp(r'^/yorks/material-requests/[^/]+/logistics$').hasMatch(normalized)) {
    return 'material_request_logistics';
  }
  if (RegExp(r'^/yorks/material-requests/[^/]+/returns$').hasMatch(normalized)) {
    return 'material_request_returns';
  }
  if (RegExp(r'^/yorks/material-requests/[^/]+$').hasMatch(normalized)) {
    return 'material_request_detail';
  }

  if (normalized == '/yorks/inventory') return 'inventory';
  if (normalized == '/yorks/inventory/import') return 'inventory_import';
  if (normalized == '/yorks/inventory/suppliers') return 'inventory_suppliers';
  if (RegExp(r'^/yorks/inventory/suppliers/[^/]+$').hasMatch(normalized)) {
    return 'inventory_supplier_detail';
  }
  if (normalized == '/yorks/dispatches') return 'dispatches';
  if (normalized == '/yorks/returns') return 'material_returns';
  if (normalized == '/yorks/returns/new') return 'material_return_create';
  if (RegExp(r'^/yorks/returns/[^/]+$').hasMatch(normalized)) {
    return 'material_return_detail';
  }

  if (normalized == '/yorks/accounts') return 'accounts';
  if (normalized.startsWith('/yorks/accounts/')) return 'accounts_workspace';
  if (normalized == '/yorks/configuration') return 'configuration';
  if (normalized.startsWith('/yorks/workforce')) return 'workforce';
  if (normalized.startsWith('/yorks/team-chat/')) return 'team_chat_conversation';
  if (normalized == '/yorks/team-chat') return 'team_chat';
  if (normalized == '/yorks/analytics') return 'company_analytics';

  if (normalized == '/browse') return 'material_browse';
  if (normalized == '/new-request') return 'material_request_create_legacy';
  if (normalized == '/pick-materials') return 'material_picker';
  if (normalized == '/requests') return 'requests';
  if (RegExp(r'^/request/[^/]+$').hasMatch(normalized)) return 'request_detail';
  if (normalized == '/people') return 'people';
  if (normalized == '/rentals') return 'rentals';
  if (normalized == '/more') return 'more';
  if (normalized == '/profile') return 'profile';
  if (normalized == '/notifications') return 'notifications';

  // Unknown routes remain useful without leaking path parameters.
  return 'other';
}
