import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_feature_flags.dart';

/// The independent Yorks V1 rollout seam.
///
/// No production screen consumes this provider until its owning batch passes.
/// With no matching `--dart-define`, every feature remains disabled.
final yorksV1FeatureFlagsProvider = Provider<YorksV1FeatureFlags>(
  (ref) => const YorksV1FeatureFlags.fromEnvironment(),
);
