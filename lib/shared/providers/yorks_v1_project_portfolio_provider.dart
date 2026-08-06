import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_project_portfolio.dart';
import '../repositories/yorks_v1_project_portfolio_repository.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_material_request_provider.dart';

final yorksV1ProjectPortfolioDataClientProvider =
    Provider<YorksV1ProjectPortfolioDataClient?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1ProjectPortfolioDataClient(client);
    });

final yorksV1ProjectPortfolioRepositoryProvider =
    Provider<YorksV1ProjectPortfolioRepository>((ref) {
      return YorksV1SupabaseProjectPortfolioRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        dataClient: ref.watch(yorksV1ProjectPortfolioDataClientProvider),
      );
    });

/// Authorized project-only rows for the R35 portfolio. Invalidating this
/// provider re-runs the same RLS-protected read; it never falls back to a
/// legacy local project register.
final yorksV1ProjectPortfolioProvider =
    FutureProvider.autoDispose<List<YorksV1ProjectPortfolioItem>>((ref) {
      // Recent-request counts and action cues are server projections. Refresh
      // them when the recipient receives a V1 workflow notification rather
      // than attempting to patch portfolio state in the browser.
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1ProjectPortfolioRepositoryProvider)
          .listPortfolio();
    });
