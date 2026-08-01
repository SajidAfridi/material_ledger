import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nexus_feature_flags.dart';

/// Overridable in tests and deployment composition. The production default is
/// deliberately fail-closed: no transformed module appears until enabled.
final nexusFeatureFlagsProvider = Provider<NexusFeatureFlags>(
  (ref) => const NexusFeatureFlags.fromEnvironment(),
);
