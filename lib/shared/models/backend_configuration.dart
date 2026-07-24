import 'dart:convert';

enum BackendStartupMode { supabase, localDevelopment, blocked }

/// Pure startup decision for the app's data backend.
///
/// A production build may only start with a complete HTTPS Supabase
/// configuration. Local storage is an explicit development mode, never an
/// automatic fallback.
class BackendConfiguration {
  const BackendConfiguration._({
    required this.mode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.failureReason,
  });

  final BackendStartupMode mode;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String failureReason;

  bool get usesSupabase => mode == BackendStartupMode.supabase;

  static BackendConfiguration resolve({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required bool isRelease,
    required bool allowLocalDevelopment,
    required String localDemoPassword,
  }) {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    final hasUrl = url.isNotEmpty;
    final hasKey = key.isNotEmpty;

    if (hasUrl != hasKey) {
      return const BackendConfiguration._(
        mode: BackendStartupMode.blocked,
        supabaseUrl: '',
        supabaseAnonKey: '',
        failureReason:
            'SUPABASE_URL and SUPABASE_ANON_KEY must be supplied together.',
      );
    }

    if (hasUrl && hasKey) {
      if (_isPrivilegedKey(key)) {
        return const BackendConfiguration._(
          mode: BackendStartupMode.blocked,
          supabaseUrl: '',
          supabaseAnonKey: '',
          failureReason:
              'A Supabase service-role or secret key must never be embedded in '
              'the client application.',
        );
      }
      final parsed = Uri.tryParse(url);
      final validScheme =
          parsed != null &&
          parsed.host.isNotEmpty &&
          (parsed.scheme == 'https' || (!isRelease && parsed.scheme == 'http'));
      if (!validScheme) {
        return BackendConfiguration._(
          mode: BackendStartupMode.blocked,
          supabaseUrl: '',
          supabaseAnonKey: '',
          failureReason: isRelease
              ? 'Production SUPABASE_URL must be a valid HTTPS URL.'
              : 'SUPABASE_URL must be a valid HTTP or HTTPS URL.',
        );
      }
      return BackendConfiguration._(
        mode: BackendStartupMode.supabase,
        supabaseUrl: url,
        supabaseAnonKey: key,
        failureReason: '',
      );
    }

    if (!isRelease &&
        allowLocalDevelopment &&
        localDemoPassword.trim().isNotEmpty) {
      return const BackendConfiguration._(
        mode: BackendStartupMode.localDevelopment,
        supabaseUrl: '',
        supabaseAnonKey: '',
        failureReason: '',
      );
    }

    if (!isRelease && allowLocalDevelopment) {
      return const BackendConfiguration._(
        mode: BackendStartupMode.blocked,
        supabaseUrl: '',
        supabaseAnonKey: '',
        failureReason:
            'LOCAL_DEMO_PASSWORD is required when local development is enabled.',
      );
    }

    return const BackendConfiguration._(
      mode: BackendStartupMode.blocked,
      supabaseUrl: '',
      supabaseAnonKey: '',
      failureReason:
          'No backend configured. Supply Supabase settings, or explicitly '
          'enable local development in a non-release build.',
    );
  }

  static bool _isPrivilegedKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
