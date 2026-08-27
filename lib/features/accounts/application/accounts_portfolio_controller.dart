import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../data/accounts_portfolio_repository.dart';
import '../domain/accounts_portfolio_models.dart';
import 'accounts_controller.dart';

final class YorksAccountsPortfolioState {
  const YorksAccountsPortfolioState({
    this.status = YorksAccountsViewStatus.idle,
    this.filters = const YorksAccountsPortfolioFilters(),
    this.projection,
    this.error,
    this.isLoadingMore = false,
  });

  final YorksAccountsViewStatus status;
  final YorksAccountsPortfolioFilters filters;
  final YorksAccountsPortfolioProjection? projection;
  final YorksV1DomainException? error;
  final bool isLoadingMore;
}

final class YorksAccountsPortfolioController
    extends StateNotifier<YorksAccountsPortfolioState> {
  YorksAccountsPortfolioController(this._repository)
    : super(const YorksAccountsPortfolioState());

  final YorksAccountsPortfolioRepository _repository;

  Future<bool> load([YorksAccountsPortfolioFilters? filters]) async {
    final nextFilters = (filters ?? state.filters).copyWith(clearCursor: true);
    state = YorksAccountsPortfolioState(
      status: YorksAccountsViewStatus.loading,
      filters: nextFilters,
      projection: state.projection,
    );
    try {
      final projection = await _repository.getPortfolio(nextFilters);
      state = YorksAccountsPortfolioState(
        status: YorksAccountsViewStatus.success,
        filters: nextFilters,
        projection: projection,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      final status = _statusFor(error.code);
      state = YorksAccountsPortfolioState(
        status: status,
        filters: nextFilters,
        projection: _mustPurgeProtectedProjection(status)
            ? null
            : state.projection,
        error: error,
      );
      return false;
    }
  }

  Future<bool> loadMore() async {
    final current = state.projection;
    if (current == null ||
        state.isLoadingMore ||
        current.nextActivityAt == null ||
        current.nextProjectId == null) {
      return false;
    }
    state = YorksAccountsPortfolioState(
      status: YorksAccountsViewStatus.success,
      filters: state.filters,
      projection: current,
      isLoadingMore: true,
    );
    try {
      final next = await _repository.getPortfolio(
        state.filters.copyWith(
          beforeActivityAt: current.nextActivityAt,
          beforeProjectId: current.nextProjectId,
        ),
      );
      final merged = current.append(next);
      state = YorksAccountsPortfolioState(
        status: YorksAccountsViewStatus.success,
        filters: state.filters,
        projection: merged,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      final status = _statusFor(error.code);
      if (status == YorksAccountsViewStatus.forbidden ||
          status == YorksAccountsViewStatus.sessionExpired ||
          status == YorksAccountsViewStatus.unavailable) {
        state = YorksAccountsPortfolioState(
          status: status,
          filters: state.filters,
          error: error,
        );
      } else {
        state = YorksAccountsPortfolioState(
          status: YorksAccountsViewStatus.success,
          filters: state.filters,
          projection: current,
          error: error,
        );
      }
      return false;
    } on FormatException catch (error) {
      state = YorksAccountsPortfolioState(
        status: YorksAccountsViewStatus.success,
        filters: state.filters,
        projection: current,
        error: YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
          cause: error,
        ),
      );
      return false;
    }
  }

  void purge() => state = const YorksAccountsPortfolioState();
}

final class YorksAccountsProjectOverviewState {
  const YorksAccountsProjectOverviewState({
    this.status = YorksAccountsViewStatus.idle,
    this.projection,
    this.error,
  });

  final YorksAccountsViewStatus status;
  final YorksAccountsProjectOverviewProjection? projection;
  final YorksV1DomainException? error;
}

final class YorksAccountsProjectOverviewController
    extends StateNotifier<YorksAccountsProjectOverviewState> {
  YorksAccountsProjectOverviewController({
    required String projectId,
    required YorksAccountsPortfolioRepository repository,
  }) : _projectId = projectId.trim(),
       _repository = repository,
       super(const YorksAccountsProjectOverviewState());

  final String _projectId;
  final YorksAccountsPortfolioRepository _repository;

  Future<bool> load() async {
    state = YorksAccountsProjectOverviewState(
      status: YorksAccountsViewStatus.loading,
      projection: state.projection,
    );
    try {
      final projection = await _repository.getProjectOverview(_projectId);
      state = YorksAccountsProjectOverviewState(
        status: YorksAccountsViewStatus.success,
        projection: projection,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      final status = _statusFor(error.code);
      state = YorksAccountsProjectOverviewState(
        status: status,
        projection: _mustPurgeProtectedProjection(status)
            ? null
            : state.projection,
        error: error,
      );
      return false;
    }
  }

  void purge() => state = const YorksAccountsProjectOverviewState();
}

bool _mustPurgeProtectedProjection(YorksAccountsViewStatus status) =>
    status == YorksAccountsViewStatus.forbidden ||
    status == YorksAccountsViewStatus.sessionExpired ||
    status == YorksAccountsViewStatus.unavailable;

YorksAccountsViewStatus _statusFor(YorksV1DomainErrorCode code) =>
    switch (code) {
      YorksV1DomainErrorCode.featureDisabled =>
        YorksAccountsViewStatus.unavailable,
      YorksV1DomainErrorCode.offline => YorksAccountsViewStatus.offline,
      YorksV1DomainErrorCode.unauthenticated =>
        YorksAccountsViewStatus.sessionExpired,
      YorksV1DomainErrorCode.unauthorized => YorksAccountsViewStatus.forbidden,
      YorksV1DomainErrorCode.conflict => YorksAccountsViewStatus.conflict,
      _ => YorksAccountsViewStatus.failure,
    };
