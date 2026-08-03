import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nexus_feature_flags.dart';

/// Legacy V7 seam retained only for compatibility tests and migration evidence.
/// It is permanently disabled in the application; Yorks V1 is the sole
/// production workflow. Tests may override this provider to exercise preserved
/// legacy decoders/screens without exposing them in a real build.
final nexusFeatureFlagsProvider = Provider<NexusFeatureFlags>(
  (ref) => const NexusFeatureFlags(),
);
