import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../data/accounts_office_repository.dart';
import '../domain/accounts_office_models.dart';
import 'accounts_controller.dart';

final class YorksAccountsOfficeState {
  const YorksAccountsOfficeState({
    this.status = YorksAccountsViewStatus.idle,
    this.filters = const YorksAccountsOfficeFilters(),
    this.projection,
    this.error,
    this.isLoadingMore = false,
  });

  final YorksAccountsViewStatus status;
  final YorksAccountsOfficeFilters filters;
  final YorksAccountsOfficeProjection? projection;
  final YorksV1DomainException? error;
  final bool isLoadingMore;
}

final class YorksAccountsOfficeController
    extends StateNotifier<YorksAccountsOfficeState> {
  YorksAccountsOfficeController({
    required YorksAccountsOfficeSection section,
    required YorksAccountsOfficeRepository repository,
  }) : _section = section,
       _repository = repository,
       super(const YorksAccountsOfficeState());

  final YorksAccountsOfficeSection _section;
  final YorksAccountsOfficeRepository _repository;
  int _loadGeneration = 0;

  Future<bool> load([YorksAccountsOfficeFilters? filters]) async {
    final generation = ++_loadGeneration;
    final source = filters ?? state.filters;
    final next = YorksAccountsOfficeFilters(
      search: source.search,
      status: source.status,
      limit: source.limit,
    );
    state = YorksAccountsOfficeState(
      status: YorksAccountsViewStatus.loading,
      filters: next,
      projection: state.projection,
    );
    try {
      final projection = await _repository.getRegister(_section, next);
      if (generation != _loadGeneration) return false;
      state = YorksAccountsOfficeState(
        status: YorksAccountsViewStatus.success,
        filters: next,
        projection: projection,
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation != _loadGeneration) return false;
      final status = _statusFor(error.code);
      state = YorksAccountsOfficeState(
        status: status,
        filters: next,
        projection: _mustPurge(status) ? null : state.projection,
        error: error,
      );
      return false;
    }
  }

  Future<bool> loadMore() async {
    final current = state.projection;
    if (current == null || !current.hasMore || state.isLoadingMore) {
      return false;
    }
    final generation = ++_loadGeneration;
    final filters = state.filters;
    state = YorksAccountsOfficeState(
      status: YorksAccountsViewStatus.success,
      filters: state.filters,
      projection: current,
      isLoadingMore: true,
    );
    try {
      final next = await _repository.getRegister(
        _section,
        filters.nextPage(current.offset + current.items.length),
      );
      if (generation != _loadGeneration) return false;
      state = YorksAccountsOfficeState(
        status: YorksAccountsViewStatus.success,
        filters: filters,
        projection: current.append(next),
      );
      return true;
    } on YorksV1DomainException catch (error) {
      if (generation != _loadGeneration) return false;
      final status = _statusFor(error.code);
      state = YorksAccountsOfficeState(
        status: _mustPurge(status) ? status : YorksAccountsViewStatus.success,
        filters: filters,
        projection: _mustPurge(status) ? null : current,
        error: error,
      );
      return false;
    } on FormatException catch (error) {
      if (generation != _loadGeneration) return false;
      state = YorksAccountsOfficeState(
        status: YorksAccountsViewStatus.success,
        filters: filters,
        projection: current,
        error: YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
          cause: error,
        ),
      );
      return false;
    }
  }
}

bool _mustPurge(YorksAccountsViewStatus status) =>
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
