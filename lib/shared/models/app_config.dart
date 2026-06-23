/// Remote-controlled app configuration that drives the global gates. Today this
/// is a bundled local default (see app_config_service.dart); on Firebase day it
/// is fetched from Remote Config / a Firestore `config/app` document with the
/// same shape — only the source swaps, the gate logic below is unchanged.
class AppConfig {
  const AppConfig({
    this.minSupportedBuild = 1,
    this.latestBuild = 1,
    this.storeUrl =
        'https://play.google.com/store/apps/details?id=com.yorks.godownpro',
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
  });

  /// Builds below this are hard-blocked (must update to keep using the app).
  final int minSupportedBuild;

  /// Latest build available — a soft "update available" nudge when ahead of the
  /// installed build but still ≥ [minSupportedBuild].
  final int latestBuild;

  /// Where the update button sends users (the Play Store listing).
  final String storeUrl;

  /// When true, everyone sees the maintenance screen (remote kill-switch).
  final bool maintenanceMode;
  final String maintenanceMessage;

  AppConfig copyWith({
    int? minSupportedBuild,
    int? latestBuild,
    String? storeUrl,
    bool? maintenanceMode,
    String? maintenanceMessage,
  }) => AppConfig(
    minSupportedBuild: minSupportedBuild ?? this.minSupportedBuild,
    latestBuild: latestBuild ?? this.latestBuild,
    storeUrl: storeUrl ?? this.storeUrl,
    maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
  );

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt() ?? 1,
    latestBuild: (json['latestBuild'] as num?)?.toInt() ?? 1,
    storeUrl: json['storeUrl'] as String? ?? const AppConfig().storeUrl,
    maintenanceMode: json['maintenanceMode'] as bool? ?? false,
    maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
  );
}

/// The blocking state the app should show, if any.
enum AppGate { none, updateRequired, maintenance }

/// Pure gate resolver (no I/O) — unit-testable. A hard version block takes
/// precedence over maintenance: an incompatible client must update first.
AppGate resolveGate(AppConfig config, int installedBuild) {
  if (installedBuild < config.minSupportedBuild) return AppGate.updateRequired;
  if (config.maintenanceMode) return AppGate.maintenance;
  return AppGate.none;
}

/// Whether a non-blocking "update available" nudge should show.
bool updateAvailable(AppConfig config, int installedBuild) =>
    installedBuild >= config.minSupportedBuild &&
    installedBuild < config.latestBuild;
