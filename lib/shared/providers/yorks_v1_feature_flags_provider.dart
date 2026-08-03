import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_feature_flags.dart';

/// The independent Yorks V1 rollout seam.
///
/// Yorks V1 is the production experience. Defines remain available to override
/// a stage for controlled CI/staging rollback, but ordinary builds use the
/// complete R35 chain without requiring command-line arguments.
final yorksV1FeatureFlagsProvider = Provider<YorksV1FeatureFlags>(
  (ref) => const YorksV1FeatureFlags.fromEnvironment(),
);
