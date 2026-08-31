import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/workforce_repository.dart';
import '../domain/workforce_dashboard_models.dart';

enum YorksWorkforceOverviewStatus {
  idle,
  loading,
  ready,
  stale,
  offline,
  forbidden,
  sessionExpired,
  unavailable,
  failure,
}

final class YorksWorkforceOverviewState {
  const YorksWorkforceOverviewState({
    this.status = YorksWorkforceOverviewStatus.idle,
    this.projection,
    this.error,
    this.isOnline = true,
  });

  final YorksWorkforceOverviewStatus status;
  final YorksWorkforceOverviewProjection? projection;
  final YorksV1DomainException? error;
  final bool isOnline;

  bool get hasLastConfirmed => projection != null;
}

final class YorksWorkforceDashboardController
    extends StateNotifier<YorksWorkforceOverviewState> {
  YorksWorkforceDashboardController({
    required YorksWorkforceDashboardRepository repository,
    required ConnectivityService connectivity,
    required YorksWorkforceOverviewKind kind,
  }) : _repository = repository,
       _connectivity = connectivity,
       _kind = kind,
       super(YorksWorkforceOverviewState(isOnline: connectivity.isOnline)) {
    _subscription = connectivity.onChange.listen(_onConnectivityChanged);
  }

  final YorksWorkforceDashboardRepository _repository;
  final ConnectivityService _connectivity;
  final YorksWorkforceOverviewKind _kind;
  StreamSubscription<bool>? _subscription;
  int _generation = 0;

  Future<bool> load({String? teamId, String? projectId}) async {
    if (!_connectivity.isOnline) {
      state = YorksWorkforceOverviewState(
        status: state.hasLastConfirmed
            ? YorksWorkforceOverviewStatus.stale
            : YorksWorkforceOverviewStatus.offline,
        projection: state.projection,
        isOnline: false,
      );
      return false;
    }
    final generation = ++_generation;
    state = YorksWorkforceOverviewState(
      status: YorksWorkforceOverviewStatus.loading,
      projection: state.projection,
      isOnline: true,
    );
    try {
      final projection = await _repository.getOverview(
        YorksWorkforceOverviewRequest(
          kind: _kind,
          teamId: teamId,
          projectId: projectId,
        ),
      );
      if (generation != _generation) return false;
      state = YorksWorkforceOverviewState(
        status: YorksWorkforceOverviewStatus.ready,
        projection: projection,
        isOnline: true,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation != _generation) return false;
      final status = switch (error.code) {
        YorksV1DomainErrorCode.unauthorized =>
          YorksWorkforceOverviewStatus.forbidden,
        YorksV1DomainErrorCode.unauthenticated =>
          YorksWorkforceOverviewStatus.sessionExpired,
        YorksV1DomainErrorCode.featureDisabled =>
          YorksWorkforceOverviewStatus.unavailable,
        YorksV1DomainErrorCode.offline =>
          state.hasLastConfirmed
              ? YorksWorkforceOverviewStatus.stale
              : YorksWorkforceOverviewStatus.offline,
        _ => YorksWorkforceOverviewStatus.failure,
      };
      state = YorksWorkforceOverviewState(
        status: status,
        projection: status == YorksWorkforceOverviewStatus.stale
            ? state.projection
            : null,
        error: error,
        isOnline: _connectivity.isOnline,
      );
      return false;
    }
  }

  void purgeProtectedState({bool unavailable = false}) {
    _generation += 1;
    state = YorksWorkforceOverviewState(
      status: unavailable
          ? YorksWorkforceOverviewStatus.unavailable
          : YorksWorkforceOverviewStatus.forbidden,
      isOnline: _connectivity.isOnline,
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    state = YorksWorkforceOverviewState(
      status: online
          ? state.status == YorksWorkforceOverviewStatus.offline ||
                    state.status == YorksWorkforceOverviewStatus.stale
                ? YorksWorkforceOverviewStatus.idle
                : state.status
          : state.hasLastConfirmed
          ? YorksWorkforceOverviewStatus.stale
          : YorksWorkforceOverviewStatus.offline,
      projection: state.projection,
      error: state.error,
      isOnline: online,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
