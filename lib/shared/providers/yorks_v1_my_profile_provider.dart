import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_my_profile.dart';
import '../models/yorks_v1_role.dart';
import '../repositories/yorks_v1_my_profile_repository.dart';
import '../sync/connectivity_service.dart';
import 'session_provider.dart' show authSessionRevisionProvider;
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_permission_provider.dart';

final yorksV1MyProfileRepositoryProvider = Provider<YorksV1MyProfileRepository>(
  (ref) {
    return YorksV1SupabaseMyProfileRepository(
      enabled: ref.watch(yorksV1FeatureFlagsProvider).foundation,
      connectivity: ref.watch(connectivityProvider),
      rpc: ref.watch(yorksV1PermissionRpcClientProvider),
    );
  },
);

/// Canonical account evidence for the My Yorks page and account launcher.
/// Identity, permission revision and connectivity changes discard the old
/// controller and its data.
/// No legacy role, HR cache or local demo identity supplies profile facts.
final yorksV1MyProfileProvider =
    StateNotifierProvider.autoDispose<
      YorksV1MyProfileController,
      AsyncValue<YorksV1MyProfile>
    >((ref) {
      ref.watch(authSessionRevisionProvider);
      ref.watch(isOnlineProvider);
      ref.watch(
        yorksV1CurrentPermissionSnapshotProvider.select(
          (value) => (value.snapshot?.revision, value.isStale),
        ),
      );
      return YorksV1MyProfileController(
        repository: ref.watch(yorksV1MyProfileRepositoryProvider),
        authUserId: ref.watch(yorksV1AuthUserIdProvider),
        exactRole: ref.watch(yorksV1CurrentRoleProvider),
      );
    });

class YorksV1MyProfileController
    extends StateNotifier<AsyncValue<YorksV1MyProfile>> {
  YorksV1MyProfileController({
    required this.repository,
    required this.authUserId,
    required this.exactRole,
    this.refreshInterval = const Duration(seconds: 60),
  }) : super(const AsyncLoading()) {
    unawaited(refresh());
  }
  final YorksV1MyProfileRepository repository;
  final String? authUserId;
  final YorksV1Role? exactRole;
  final Duration refreshInterval;
  Timer? _timer;
  int _generation = 0;

  Future<void> refresh({int projectOffset = 0}) async {
    if (!mounted) return;
    final generation = ++_generation;
    _timer?.cancel();
    state = const AsyncLoading();
    try {
      if (authUserId == null || exactRole == null) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unauthenticated,
        );
      }
      final elapsed = Stopwatch()..start();
      final profile = await repository.load(
        expectedAuthUserId: authUserId!,
        expectedRole: exactRole!,
        projectOffset: projectOffset,
      );
      if (!mounted || generation != _generation) return;
      state = AsyncData(profile);
      // Use server-relative time so device clock skew cannot delay expiry.
      final transitionDelay = profile.nextTransitionAt == null
          ? null
          : profile.nextTransitionAt!.difference(profile.generatedAt) -
                elapsed.elapsed;
      final delay = transitionDelay != null && transitionDelay < refreshInterval
          ? transitionDelay
          : refreshInterval;
      _timer = Timer(
        delay.isNegative ? Duration.zero : delay,
        () => unawaited(refresh(projectOffset: projectOffset)),
      );
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      state = AsyncError(error, stack);
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
