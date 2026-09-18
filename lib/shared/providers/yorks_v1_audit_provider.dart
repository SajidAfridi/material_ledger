import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_audit_workspace.dart';
import '../models/yorks_v1_domain_error.dart';
import 'yorks_v1_identity_provider.dart';
import '../repositories/yorks_v1_audit_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';

final yorksV1AuditRpcClientProvider = Provider<YorksV1AuditRpcClient?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseYorksV1AuditRpcClient(client);
});

final yorksV1AuditNowProvider = Provider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

final yorksV1AuditRepositoryProvider = Provider<YorksV1AuditRepository>((ref) {
  return YorksV1SupabaseAuditRepository(
    featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
    connectivity: ref.watch(connectivityProvider),
    rpcClient: ref.watch(yorksV1AuditRpcClientProvider),
  );
});

class YorksV1AuditViewState {
  const YorksV1AuditViewState({
    this.filter = const YorksV1AuditFilter(),
    this.workspace,
    this.isLoading = true,
    this.isRefreshing = false,
    this.error,
    this.stackTrace,
    this.loadedFilter,
  });

  final YorksV1AuditFilter filter;
  final YorksV1AuditWorkspace? workspace;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;
  final StackTrace? stackTrace;
  final YorksV1AuditFilter? loadedFilter;
  bool get canExport =>
      workspace != null && !isLoading && !isRefreshing && error == null;

  YorksV1AuditViewState copyWith({
    YorksV1AuditFilter? filter,
    YorksV1AuditWorkspace? workspace,
    bool? isLoading,
    bool? isRefreshing,
    Object? error,
    StackTrace? stackTrace,
    bool clearError = false,
    bool clearWorkspace = false,
    YorksV1AuditFilter? loadedFilter,
  }) => YorksV1AuditViewState(
    filter: filter ?? this.filter,
    workspace: clearWorkspace ? null : workspace ?? this.workspace,
    loadedFilter: clearWorkspace ? null : loadedFilter ?? this.loadedFilter,
    isLoading: isLoading ?? this.isLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : error ?? this.error,
    stackTrace: clearError ? null : stackTrace ?? this.stackTrace,
  );
}

final yorksV1AuditControllerProvider =
    StateNotifierProvider.autoDispose<
      YorksV1AuditController,
      YorksV1AuditViewState
    >((ref) {
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksV1CurrentRoleProvider);
      return YorksV1AuditController(
        ref.watch(yorksV1AuditRepositoryProvider),
        now: ref.watch(yorksV1AuditNowProvider),
      );
    });

class YorksV1AuditController extends StateNotifier<YorksV1AuditViewState> {
  YorksV1AuditController(this._repository, {DateTime? now})
    : super(YorksV1AuditViewState(filter: recentFilter(now))) {
    scheduleMicrotask(load);
  }

  final YorksV1AuditRepository _repository;
  static YorksV1AuditFilter recentFilter([DateTime? anchor]) {
    final now = anchor ?? DateTime.now();
    return YorksV1AuditFilter(
      from: DateTime(now.year, now.month, now.day - 29),
      to: DateTime(now.year, now.month, now.day + 1),
    );
  }

  int _requestSerial = 0;
  final _pageCursors = <int, (DateTime, String)>{};

  Future<void> load() async {
    final filter = state.filter;
    final serial = ++_requestSerial;
    final retaining = state.workspace != null;
    state = state.copyWith(
      isLoading: !retaining,
      isRefreshing: retaining,
      clearError: true,
    );
    try {
      final workspace = await _repository.getWorkspace(filter);
      if (!mounted || serial != _requestSerial) return;
      if (workspace.events.isNotEmpty) {
        final last = workspace.events.last;
        _pageCursors[filter.page + 1] = (last.occurredAt, last.id);
      }
      state = state.copyWith(
        workspace: workspace,
        loadedFilter: filter.copyWith(asOf: workspace.asOf),
        filter: filter.copyWith(asOf: workspace.asOf),
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (error, stackTrace) {
      if (!mounted || serial != _requestSerial) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: error,
        stackTrace: stackTrace,
        clearWorkspace:
            error is YorksV1DomainException &&
            {
              YorksV1DomainErrorCode.unauthorized,
              YorksV1DomainErrorCode.unauthenticated,
              YorksV1DomainErrorCode.featureDisabled,
            }.contains(error.code),
      );
    }
  }

  Future<void> setSearch(String value) =>
      _setFilter(state.filter.copyWith(search: value, page: 0));

  Future<void> setModule(YorksV1AuditModule? module) => _setFilter(
    state.filter.copyWith(module: module, clearModule: module == null, page: 0),
  );

  Future<void> setQuickFilter(YorksV1AuditQuickFilter? filter) => _setFilter(
    state.filter.copyWith(
      quickFilter: filter,
      clearQuickFilter: filter == null,
      page: 0,
    ),
  );

  Future<void> setDateRange(DateTime? from, DateTime? to) => _setFilter(
    state.filter.copyWith(
      from: from,
      to: to,
      clearDates: from == null && to == null,
      page: 0,
    ),
  );

  Future<void> goToPage(int page) {
    final workspace = state.workspace;
    final maximum = (workspace?.pageCount ?? 1) - 1;
    final next = page.clamp(0, maximum);
    if (next == state.filter.page) return Future.value();
    state = state.copyWith(
      filter: state.filter
          .copyWith(page: next, clearCursor: true)
          .copyWith(
            cursorAt: _pageCursors[next]?.$1,
            cursorId: _pageCursors[next]?.$2,
          ),
      clearError: true,
    );
    return load();
  }

  Future<void> _setFilter(YorksV1AuditFilter filter) {
    _pageCursors.clear();
    state = state.copyWith(
      filter: filter.copyWith(clearSnapshot: true, clearCursor: true),
      clearError: true,
    );
    return load();
  }

  Future<void> refresh() {
    _pageCursors.clear();
    state = state.copyWith(
      filter: state.filter.copyWith(
        clearSnapshot: true,
        clearCursor: true,
        page: 0,
      ),
    );
    return load();
  }

  Future<void> applyFilter(YorksV1AuditFilter filter) =>
      _setFilter(filter.copyWith(page: 0));
  Future<void> clearFilters() => _setFilter(const YorksV1AuditFilter());

  Future<YorksV1AuditWorkspace> history(
    YorksV1AuditEvent event, {
    int page = 0,
    DateTime? asOf,
    YorksV1AuditEvent? after,
  }) async {
    try {
      return await _repository.getWorkspace(
        YorksV1AuditFilter(
          entityId: event.entityId,
          entityType: event.entityType,
          page: page,
          asOf: asOf,
          cursorAt: after?.occurredAt,
          cursorId: after?.id,
        ),
      );
    } on YorksV1DomainException catch (error) {
      if (error.code == YorksV1DomainErrorCode.unauthorized && mounted) {
        state = state.copyWith(clearWorkspace: true, error: error);
      }
      rethrow;
    }
  }

  Future<YorksV1AuditWorkspace> export(String id) async {
    if (!state.canExport) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    try {
      return await _repository.exportWorkspace(state.loadedFilter!, id);
    } on YorksV1DomainException catch (error) {
      if (error.code == YorksV1DomainErrorCode.unauthorized && mounted) {
        state = state.copyWith(clearWorkspace: true, error: error);
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _requestSerial++;
    super.dispose();
  }
}
