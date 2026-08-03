import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_feature_flags.dart';

/// The independent Yorks V1 rollout seam.
///
/// Yorks V1 is the active product experience. Defines remain available as an
/// explicit escape hatch for CI, staging or rollback, but ordinary builds use
/// the approved Yorks defaults without requiring command-line flags.
final yorksV1FeatureFlagsProvider = Provider<YorksV1FeatureFlags>(
  (ref) => const YorksV1FeatureFlags.fromEnvironment(),
);
