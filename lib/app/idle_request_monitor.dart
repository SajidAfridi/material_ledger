import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/app_notification.dart';
import '../shared/models/app_strings.dart';
import '../shared/models/material_request.dart';
import '../shared/models/user_role.dart';
import '../shared/providers/language_provider.dart';
import '../shared/providers/material_request_provider.dart';
import '../shared/providers/notification_provider.dart';
import 'router.dart';

/// A request sitting with no procurement action for this long alerts admin
/// (SRS FR-066).
const idleRequestThreshold = Duration(hours: 24);

/// Open requests that have had no action for [idleRequestThreshold] and haven't
/// already been flagged to admin. Pure (no I/O) so it's unit-testable; [now] is
/// injected rather than read from the clock.
///
/// "No action" = still [RequestStatus.pending] (procurement hasn't sourced,
/// dispatched, or held it). Dedup is by an existing admin-audience notification
/// carrying the request id, so re-running on every launch never duplicates.
List<MaterialRequest> staleRequests(
  List<MaterialRequest> requests,
  List<AppNotification> existing,
  DateTime now,
) {
  final alreadyFlagged = existing
      .where((n) => n.audience == UserRole.admin.name && n.refId.isNotEmpty)
      .map((n) => n.refId)
      .toSet();
  return requests
      .where(
        (r) =>
            r.status == RequestStatus.pending &&
            now.difference(r.requestDate) >= idleRequestThreshold &&
            !alreadyFlagged.contains(r.id),
      )
      .toList();
}

/// Client-side stand-in for the server scheduler (FR-066): on app start, flag
/// any request idle 24h+ to admin, deep-linked to the dispatch screen so they
/// can act in one tap. In production a Firestore scheduled Cloud Function emits
/// the same notification shape — only this trigger is swapped, nothing else.
///
/// Watched once in the app root. The scan is deferred to a microtask so it never
/// mutates [notificationsProvider] during another provider's build.
final idleRequestMonitorProvider = Provider<void>((ref) {
  Future.microtask(() async {
    final stale = staleRequests(
      ref.read(materialRequestsProvider),
      ref.read(notificationsProvider),
      DateTime.now(),
    );
    if (stale.isEmpty) return;
    final lang = ref.read(languageProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    for (final r in stale) {
      await notifier.add(
        type: NotificationType.request,
        title: AppStrings.notifIdleRequestTitle.primary,
        titleSecondary: AppStrings.notifIdleRequestTitle.secondary(lang),
        body: '${r.projectName} · ${r.itemCount} item(s)',
        refId: r.id,
        route: RoutePaths.dispatchPath(r.id),
        audience: UserRole.admin.name,
      );
    }
  });
});
