import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_audit_workspace.dart';
import '../repositories/yorks_v1_audit_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';

final yorksV1AuditRpcClientProvider = Provider<YorksV1AuditRpcClient?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseYorksV1AuditRpcClient(client);
});

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
  });

  final YorksV1AuditFilter filter;
  final YorksV1AuditWorkspace? workspace;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;
  final StackTrace? stackTrace;

  YorksV1AuditViewState copyWith({
    YorksV1AuditFilter? filter,
    YorksV1AuditWorkspace? workspace,
    bool? isLoading,
    bool? isRefreshing,
    Object? error,
    StackTrace? stackTrace,
    bool clearError = false,
  }) => YorksV1AuditViewState(
    filter: filter ?? this.filter,
    workspace: workspace ?? this.workspace,
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
      return YorksV1AuditController(ref.watch(yorksV1AuditRepositoryProvider));
    });

class YorksV1AuditController extends StateNotifier<YorksV1AuditViewState> {
  YorksV1AuditController(this._repository)
    : super(const YorksV1AuditViewState()) {
    scheduleMicrotask(load);
  }

  final YorksV1AuditRepository _repository;
  int _requestSerial = 0;

  Future<void> load() async {
    final serial = ++_requestSerial;
    final retaining = state.workspace != null;
    state = state.copyWith(
      isLoading: !retaining,
      isRefreshing: retaining,
      clearError: true,
    );
    try {
      final workspace = await _repository.getWorkspace(state.filter);
      if (!mounted || serial != _requestSerial) return;
      state = state.copyWith(
        workspace: workspace,
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
    return _setFilter(state.filter.copyWith(page: next));
  }

  Future<void> _setFilter(YorksV1AuditFilter filter) {
    state = state.copyWith(filter: filter, clearError: true);
    return load();
  }

  @override
  void dispose() {
    _requestSerial++;
    super.dispose();
  }
}
