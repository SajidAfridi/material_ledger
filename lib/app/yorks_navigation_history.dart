import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/providers/language_provider.dart';

class YorksNavigationHistory {
  const YorksNavigationHistory(this.locations);

  const YorksNavigationHistory.empty() : locations = const [];

  final List<String> locations;

  bool canGoBack(String currentLocation) {
    final normalized = _normalize(currentLocation);
    if (locations.isEmpty) return false;
    if (locations.last == normalized) return locations.length > 1;
    return locations.isNotEmpty;
  }
}

class YorksNavigationHistoryNotifier
    extends StateNotifier<YorksNavigationHistory> {
  YorksNavigationHistoryNotifier()
    : super(const YorksNavigationHistory.empty());

  static const _limit = 30;

  void record(String location) {
    final normalized = _normalize(location);
    if (normalized.isEmpty ||
        (state.locations.isNotEmpty && state.locations.last == normalized)) {
      return;
    }
    final next = [...state.locations, normalized];
    state = YorksNavigationHistory(
      List.unmodifiable(
        next.length <= _limit ? next : next.sublist(next.length - _limit),
      ),
    );
  }

  /// Consumes the current entry and returns the previous workspace location.
  /// This mirrors a real pop for root destinations whose StatefulShell branch
  /// switch has no Navigator page to pop.
  String? takePrevious(String currentLocation) {
    final normalized = _normalize(currentLocation);
    final next = [...state.locations];
    if (next.isEmpty) return null;
    if (next.last != normalized) next.add(normalized);
    if (next.length < 2) return null;
    next.removeLast();
    final previous = next.last;
    state = YorksNavigationHistory(List.unmodifiable(next));
    return previous;
  }

  void discardCurrent(String currentLocation) {
    final normalized = _normalize(currentLocation);
    final next = [...state.locations];
    if (next.isNotEmpty && next.last == normalized) {
      next.removeLast();
      state = YorksNavigationHistory(List.unmodifiable(next));
    }
  }
}

String _normalize(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return '';
  // A notification acknowledgement is transient transport metadata, not part
  // of a place the person should return to.
  final query = {...uri.queryParameters}..remove('notificationId');
  return uri.replace(queryParameters: query.isEmpty ? null : query).toString();
}

final yorksNavigationHistoryProvider =
    StateNotifierProvider<
      YorksNavigationHistoryNotifier,
      YorksNavigationHistory
    >((ref) {
      // Recreate history for each authenticated session so one person's route
      // cannot become another person's Back destination on a shared device.
      ref.watch(authSessionProvider);
      return YorksNavigationHistoryNotifier();
    });

bool yorksCanNavigateBack(
  BuildContext context,
  WidgetRef ref,
  String currentLocation,
) =>
    (Navigator.maybeOf(context)?.canPop() ?? false) ||
    ref.watch(yorksNavigationHistoryProvider).canGoBack(currentLocation);

void yorksNavigateBack(
  BuildContext context,
  WidgetRef ref,
  String currentLocation, {
  String? fallback,
}) {
  final history = ref.read(yorksNavigationHistoryProvider.notifier);
  if (Navigator.maybeOf(context)?.canPop() ?? false) {
    history.discardCurrent(currentLocation);
    Navigator.of(context).pop();
    return;
  }
  final previous = history.takePrevious(currentLocation);
  if (previous != null && previous != currentLocation) {
    context.go(previous);
    return;
  }
  if (fallback != null && fallback != currentLocation) context.go(fallback);
}
