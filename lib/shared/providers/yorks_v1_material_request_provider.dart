import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../controllers/yorks_v1_material_request_draft_controller.dart';
import '../models/yorks_v1_material_request.dart';
import '../models/yorks_v1_material_request_document.dart';
import '../models/yorks_v1_role.dart';
import '../repositories/storage.dart';
import 'yorks_v1_material_request_repository_provider.dart';
import 'language_provider.dart';

const _yorksV1MaterialRequestDraftKeyPrefix =
    'yorks_v1_material_request_drafts_v1';

/// Invalidates the device-local draft index when a single editor persists or
/// removes one of its private recovery records.  This is deliberately local
/// state: incomplete drafts are not exposed through server request lists.
final yorksV1MaterialRequestLocalDraftRevisionProvider =
    StateProvider.family<int, String>((ref, ownerAuthUserId) => 0);

class YorksV1MaterialRequestDraftKey {
  const YorksV1MaterialRequestDraftKey({
    required this.ownerAuthUserId,
    required this.draftId,
  });

  final String ownerAuthUserId;
  final String draftId;

  @override
  bool operator ==(Object other) =>
      other is YorksV1MaterialRequestDraftKey &&
      other.ownerAuthUserId == ownerAuthUserId &&
      other.draftId == draftId;

  @override
  int get hashCode => Object.hash(ownerAuthUserId, draftId);
}

final yorksV1MaterialRequestDraftControllerProvider =
    StateNotifierProvider.family<
      YorksV1MaterialRequestDraftController,
      YorksV1MaterialRequestDraftState,
      YorksV1MaterialRequestDraftKey
    >((ref, key) {
      final store = ref
          .watch(storageProvider)
          .collection<YorksV1MaterialRequestDraft>(
            '${_yorksV1MaterialRequestDraftKeyPrefix}_${key.ownerAuthUserId}',
            toJson: (draft) => draft.toJson(),
            fromJson: YorksV1MaterialRequestDraft.fromJson,
          );
      const uuid = Uuid();
      return YorksV1MaterialRequestDraftController(
        ownerAuthUserId: key.ownerAuthUserId,
        draftId: key.draftId,
        store: store,
        repository: ref.watch(yorksV1MaterialRequestRepositoryProvider),
        uuidFactory: uuid.v4,
        onLocalDraftsChanged: () {
          final revision = ref.read(
            yorksV1MaterialRequestLocalDraftRevisionProvider(
              key.ownerAuthUserId,
            ).notifier,
          );
          revision.state++;
        },
      );
    });

/// The owner-scoped index of recoverable, not-yet-server-saved Material
/// Request input.  It is read only by the authenticated owner's register and
/// never substituted for the authoritative server request projection.
final yorksV1MaterialRequestLocalDraftsProvider =
    Provider.family<List<YorksV1MaterialRequestDraft>, String>((
      ref,
      ownerAuthUserId,
    ) {
      ref.watch(
        yorksV1MaterialRequestLocalDraftRevisionProvider(ownerAuthUserId),
      );
      final store = ref
          .watch(storageProvider)
          .collection<YorksV1MaterialRequestDraft>(
            '${_yorksV1MaterialRequestDraftKeyPrefix}_$ownerAuthUserId',
            toJson: (draft) => draft.toJson(),
            fromJson: YorksV1MaterialRequestDraft.fromJson,
          );
      final drafts = store
          .readAll()
          .where(
            (draft) =>
                draft.ownerAuthUserId == ownerAuthUserId &&
                draft.serverRecordVersion == 0 &&
                draft.hasRecoverableContent,
          )
          .toList(growable: false);
      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return List.unmodifiable(drafts);
    });

final yorksV1MaterialRequestListProvider = FutureProvider.autoDispose
    .family<List<YorksV1MaterialRequest>, String?>((ref, projectId) {
      // Realtime never provides a request projection. Keep the current
      // authorized result on screen while a signal asks this provider to
      // refresh in place. Watching the revision as a normal dependency makes
      // Riverpod report a reload and briefly replaces the page with a spinner.
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listRequests(projectId: projectId);
    });

/// The kind of server event that asks current Material Request projections to
/// refresh. These are deliberately metadata-only reasons: no workflow record,
/// quantity or commercial value travels through Realtime state.
enum YorksV1MaterialRequestRefreshReason {
  materialRequest,
  arrangement,
  dispatch,
  receiptReview,
  deliveryOrder,
  materialReturn,
  subscriptionReconnected,
}

/// Test seam for the recipient-scoped database-change subscription.
///
/// Production subscribes to `v1_notifications`, whose rows contain only an
/// event code and entity identifier. Tests can inject deterministic signals
/// without needing a real WebSocket or treating a locally supplied payload as
/// workflow authority.
typedef YorksV1MaterialRequestRefreshSignalSubscription =
    Future<bool> Function({
      required Future<void> Function(YorksV1MaterialRequestRefreshReason reason)
      onSignal,
      required void Function(Object? error) onUnavailable,
    });

/// A small revision counter, not a Material Request cache.
///
/// Every active Material Request list/detail/document/logistics provider reads
/// this counter and therefore re-runs its existing authorized RPC when a
/// recipient-scoped Realtime event arrives. This is intentionally the only
/// client-side effect of Realtime: trusted RPCs remain the transaction
/// authority and their projections remain the source of record state.
final yorksV1MaterialRequestRealtimeRevisionProvider =
    StateNotifierProvider.autoDispose<
      YorksV1MaterialRequestRealtimeNotifier,
      int
    >((ref) {
      // Watch the app session solely as an invalidation trigger. The channel
      // uses the current Supabase Auth identity below, never the legacy app
      // user ID, to keep its recipient filter aligned with RLS.
      final appSessionId = ref.watch(authSessionProvider);
      final client = ref.watch(supabaseClientProvider);
      final authUserId = client?.auth.currentUser?.id;
      final notifier = YorksV1MaterialRequestRealtimeNotifier(
        enabled:
            appSessionId != null &&
            authUserId != null &&
            authUserId.trim().isNotEmpty &&
            client != null,
        authUserId: authUserId,
        client: client,
      );
      unawaited(notifier.start());
      return notifier;
    });

/// Backwards-compatible mount point for screens that already request a live
/// action queue. Detail/document providers also watch the revision directly,
/// so the subscription remains active on every Material Request route rather
/// than only on the overview screen.
final yorksV1MaterialRequestLiveRefreshProvider = Provider.autoDispose<void>((
  ref,
) {
  ref.watch(yorksV1MaterialRequestRealtimeRevisionProvider);
});

class YorksV1MaterialRequestRealtimeNotifier extends StateNotifier<int>
    with WidgetsBindingObserver {
  YorksV1MaterialRequestRealtimeNotifier({
    required bool enabled,
    required String? authUserId,
    required SupabaseClient? client,
    YorksV1MaterialRequestRefreshSignalSubscription? signalSubscription,
    Duration fallbackInterval = const Duration(seconds: 20),
  }) : _enabled = enabled,
       _authUserId = authUserId,
       _client = client,
       _signalSubscription = signalSubscription,
       _fallbackInterval = fallbackInterval,
       super(0);

  final bool _enabled;
  final String? _authUserId;
  final SupabaseClient? _client;
  final YorksV1MaterialRequestRefreshSignalSubscription? _signalSubscription;
  final Duration _fallbackInterval;

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _fallbackTimer;
  bool _started = false;
  bool _disposed = false;
  bool _observingLifecycle = false;
  bool _leftForeground = false;

  /// Starts the safe notification signal and a low-frequency authorized read.
  /// The latter closes mobile/browser suspension gaps without replacing the
  /// current projection or treating Realtime as workflow authority.
  Future<void> start() async {
    if (!_enabled || _disposed || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    final subscription = _signalSubscription ?? _subscribeToNotificationSignals;
    final subscribed = await subscription(
      onSignal: _refreshAuthorizedProjections,
      onUnavailable: _onSignalUnavailable,
    );
    if (_disposed) return;
    // Re-fetch once a channel has joined. That closes the gap between the
    // initial list/detail RPC and a successful subscription registration.
    if (subscribed) {
      await _refreshAuthorizedProjections(
        YorksV1MaterialRequestRefreshReason.subscriptionReconnected,
      );
    }
    // Mobile operating systems and browser tabs can suspend a healthy socket
    // without immediately reporting a channel error. Keep a low-frequency
    // authorized re-fetch as a safety net on every platform. Dependants retain
    // their current data while refreshing, so this does not flash a loading
    // screen or make Realtime a transaction authority.
    _ensureFallbackTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || _disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (_leftForeground) {
        unawaited(
          _refreshAuthorizedProjections(
            YorksV1MaterialRequestRefreshReason.subscriptionReconnected,
          ),
        );
      }
      _leftForeground = false;
      return;
    }
    _leftForeground = true;
  }

  /// Maps an already RLS-filtered notification envelope to a refresh only.
  /// Unknown operational events are intentionally ignored so unrelated legacy
  /// notifications cannot cause the Material Request workspace to churn.
  static YorksV1MaterialRequestRefreshReason? reasonFromNotification(
    Map<String, dynamic> notification,
  ) {
    final entityType = notification['entity_type']?.toString().trim();
    return switch (entityType) {
      'material_request' => YorksV1MaterialRequestRefreshReason.materialRequest,
      'procurement_arrangement' =>
        YorksV1MaterialRequestRefreshReason.arrangement,
      'material_dispatch' => YorksV1MaterialRequestRefreshReason.dispatch,
      'receipt_review' => YorksV1MaterialRequestRefreshReason.receiptReview,
      'delivery_order' => YorksV1MaterialRequestRefreshReason.deliveryOrder,
      'material_return' => YorksV1MaterialRequestRefreshReason.materialReturn,
      _ => null,
    };
  }

  Future<bool> _subscribeToNotificationSignals({
    required Future<void> Function(YorksV1MaterialRequestRefreshReason reason)
    onSignal,
    required void Function(Object? error) onUnavailable,
  }) async {
    final client = _client;
    final authUserId = _authUserId?.trim();
    if (client == null || authUserId == null || authUserId.isEmpty) {
      return false;
    }
    try {
      // Postgres Changes authorizes against the channel JWT. Reset it after a
      // token refresh too, so a channel never relies on an expired identity.
      final token = client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) return false;
      await client.realtime.setAuth(token);
      _authSubscription = client.auth.onAuthStateChange.listen((event) {
        final refreshedToken = event.session?.accessToken;
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          unawaited(client.realtime.setAuth(refreshedToken));
        }
      });

      final joined = Completer<bool>();
      final channel = client
          .channel('yorks-v1-material-request-refresh:$authUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'v1_notifications',
            // RLS is the security boundary. The filter narrows the received
            // envelope even further so an Admin browser never consumes other
            // users' notification rows merely to refresh its own projection.
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_auth_user_id',
              value: authUserId,
            ),
            callback: (payload) {
              final reason = reasonFromNotification(payload.newRecord);
              if (reason != null) unawaited(onSignal(reason));
            },
          )
          .subscribe((status, error) {
            if (_disposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              if (!joined.isCompleted) {
                joined.complete(true);
              } else {
                // A reconnect may have missed a notification; re-fetch the
                // projection instead of trying to replay any local state.
                unawaited(
                  onSignal(
                    YorksV1MaterialRequestRefreshReason.subscriptionReconnected,
                  ),
                );
              }
              return;
            }
            onUnavailable(error);
            if (!joined.isCompleted) joined.complete(false);
          });
      _channel = channel;
      return await joined.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          onUnavailable(
            TimeoutException(
              'Material Request Realtime subscription timed out',
            ),
          );
          return false;
        },
      );
    } catch (error) {
      onUnavailable(error);
      return false;
    }
  }

  Future<void> _refreshAuthorizedProjections(
    YorksV1MaterialRequestRefreshReason _,
  ) async {
    if (!_enabled || _disposed) return;
    // This revision contains no server domain data. Every dependant uses it
    // only to issue its normal RLS-protected repository read.
    state += 1;
  }

  void _onSignalUnavailable(Object? _) {
    if (_disposed) return;
    _ensureFallbackTimer();
    // Deliberately do not synthesize a workflow error or stale transition
    // from a dropped socket. The fallback issues the same authorized read.
  }

  void _ensureFallbackTimer() {
    if (_disposed || _fallbackTimer != null) return;
    _fallbackTimer = Timer.periodic(
      _fallbackInterval,
      (_) => unawaited(
        _refreshAuthorizedProjections(
          YorksV1MaterialRequestRefreshReason.subscriptionReconnected,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    unawaited(_authSubscription?.cancel() ?? Future<void>.value());
    final channel = _channel;
    final client = _client;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    _channel = null;
    super.dispose();
  }
}

/// Whether a request belongs in the signed-in role's action queue.
///
/// The owner role comes from the server projection, never from an editable
/// client field. Admin sees the active workflow queue for oversight; ordinary
/// roles see only requests currently owned by their exact V1 role.
bool yorksV1MaterialRequestNeedsAction(
  YorksV1MaterialRequest request,
  YorksV1Role? role,
) {
  if (role == null || request.state.isDraft) return false;
  if (request.state == YorksV1MaterialRequestState.closed ||
      request.state == YorksV1MaterialRequestState.cancelled) {
    return false;
  }
  if (role == YorksV1Role.admin) return true;
  if (request.currentActionOwnerRole == 'project_engineer' &&
      role.isGlobalProjectEngineer) {
    return true;
  }
  return request.currentActionOwnerRole == role.claimValue;
}

final yorksV1MaterialRequestDraftProjectsProvider =
    FutureProvider.autoDispose<List<YorksV1MaterialRequestProjectOption>>((
      ref,
    ) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listDraftProjects();
    });

final yorksV1MaterialRequestScopesProvider = FutureProvider.autoDispose
    .family<List<YorksV1MaterialRequestScopeOption>, String>((ref, projectId) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listScopes(projectId);
    });

final yorksV1MaterialRequestMentionCandidatesProvider = FutureProvider
    .autoDispose
    .family<List<YorksV1MaterialRequestMention>, String>((ref, requestId) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .listMentionCandidates(requestId);
    });

class YorksV1MaterialRequestInventorySearchKey {
  const YorksV1MaterialRequestInventorySearchKey({
    required this.projectId,
    required this.query,
  });

  final String projectId;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is YorksV1MaterialRequestInventorySearchKey &&
      other.projectId == projectId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(projectId, query);
}

final yorksV1MaterialRequestInventorySearchProvider = FutureProvider.autoDispose
    .family<
      List<YorksV1MaterialRequestInventorySuggestion>,
      YorksV1MaterialRequestInventorySearchKey
    >((ref, key) {
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .searchInventory(projectId: key.projectId, query: key.query);
    });

final yorksV1MaterialRequestDetailProvider = FutureProvider.autoDispose
    .family<YorksV1MaterialRequest, String>((ref, requestId) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .getRequest(requestId);
    });

final yorksV1MaterialRequestDocumentProvider = FutureProvider.autoDispose
    .family<YorksV1MaterialRequestDocumentModel, String>((ref, requestId) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1MaterialRequestRepositoryProvider)
          .getDocumentModel(requestId);
    });
