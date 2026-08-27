import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_team_chat.dart';
import '../repositories/yorks_v1_team_chat_repository.dart';
import '../services/yorks_v1_chat_file_service.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';

final yorksV1ChatFileServiceProvider = Provider<YorksV1ChatFileService>(
  (_) => const YorksV1PlatformChatFileService(),
);

enum YorksV1ChatOutgoingStatus { sending, failed }

final yorksV1TeamChatRepositoryProvider = Provider<YorksV1TeamChatRepository?>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return YorksV1SupabaseTeamChatRepository(
    client: client,
    connectivity: ref.watch(connectivityProvider),
  );
});

class YorksV1TeamChatState {
  const YorksV1TeamChatState({
    this.conversations = const [],
    this.directory = const [],
    this.contextTargets = const [],
    this.selectedConversationId,
    this.thread,
    this.loadingList = true,
    this.loadingThread = false,
    this.loadingOlder = false,
    this.hasOlderMessages = true,
    this.loadingDirectory = false,
    this.loadingContextTargets = false,
    this.sending = false,
    this.outgoingInput,
    this.outgoingStatus,
    this.error,
  });

  final List<YorksV1ChatConversation> conversations;
  final List<YorksV1ChatParticipant> directory;
  final List<YorksV1ChatContextTarget> contextTargets;
  final String? selectedConversationId;
  final YorksV1ChatThread? thread;
  final bool loadingList;
  final bool loadingThread;
  final bool loadingOlder;
  final bool hasOlderMessages;
  final bool loadingDirectory;
  final bool loadingContextTargets;
  final bool sending;
  final YorksV1ChatSendInput? outgoingInput;
  final YorksV1ChatOutgoingStatus? outgoingStatus;
  final YorksV1DomainErrorCode? error;

  int get unreadCount => conversations
      .where((item) => !item.isMuted)
      .fold(0, (total, conversation) => total + conversation.unreadCount);

  YorksV1TeamChatState copyWith({
    List<YorksV1ChatConversation>? conversations,
    List<YorksV1ChatParticipant>? directory,
    List<YorksV1ChatContextTarget>? contextTargets,
    String? selectedConversationId,
    bool clearSelection = false,
    YorksV1ChatThread? thread,
    bool clearThread = false,
    bool? loadingList,
    bool? loadingThread,
    bool? loadingOlder,
    bool? hasOlderMessages,
    bool? loadingDirectory,
    bool? loadingContextTargets,
    bool? sending,
    YorksV1ChatSendInput? outgoingInput,
    YorksV1ChatOutgoingStatus? outgoingStatus,
    bool clearOutgoing = false,
    YorksV1DomainErrorCode? error,
    bool clearError = false,
  }) => YorksV1TeamChatState(
    conversations: conversations ?? this.conversations,
    directory: directory ?? this.directory,
    contextTargets: contextTargets ?? this.contextTargets,
    selectedConversationId: clearSelection
        ? null
        : selectedConversationId ?? this.selectedConversationId,
    thread: clearThread ? null : thread ?? this.thread,
    loadingList: loadingList ?? this.loadingList,
    loadingThread: loadingThread ?? this.loadingThread,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasOlderMessages: hasOlderMessages ?? this.hasOlderMessages,
    loadingDirectory: loadingDirectory ?? this.loadingDirectory,
    loadingContextTargets: loadingContextTargets ?? this.loadingContextTargets,
    sending: sending ?? this.sending,
    outgoingInput: clearOutgoing ? null : outgoingInput ?? this.outgoingInput,
    outgoingStatus: clearOutgoing
        ? null
        : outgoingStatus ?? this.outgoingStatus,
    error: clearError ? null : error ?? this.error,
  );
}

final yorksV1TeamChatProvider =
    StateNotifierProvider.autoDispose<
      YorksV1TeamChatController,
      YorksV1TeamChatState
    >((ref) {
      final controller = YorksV1TeamChatController(
        repository: ref.watch(yorksV1TeamChatRepositoryProvider),
        client: ref.watch(supabaseClientProvider),
        authUserId: ref.watch(yorksV1AuthUserIdProvider),
        enabled: ref.watch(yorksV1FeatureFlagsProvider).teamChat,
      );
      unawaited(controller.start());
      return controller;
    });

final yorksV1TeamChatUnreadProvider = Provider<int>(
  (ref) => ref.watch(yorksV1TeamChatProvider).unreadCount,
);

final yorksV1ChatAttachmentBytesProvider = FutureProvider.autoDispose
    .family<({Uint8List bytes, String fileName, String mimeType}), String>((
      ref,
      attachmentId,
    ) {
      final repository = ref.watch(yorksV1TeamChatRepositoryProvider);
      if (repository == null) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
        );
      }
      return repository.downloadAttachment(attachmentId);
    });

class YorksV1TeamChatController extends StateNotifier<YorksV1TeamChatState>
    with WidgetsBindingObserver {
  YorksV1TeamChatController({
    required YorksV1TeamChatRepository? repository,
    required SupabaseClient? client,
    required String? authUserId,
    required bool enabled,
  }) : _repository = repository,
       _client = client,
       _authUserId = authUserId,
       _enabled = enabled,
       super(const YorksV1TeamChatState());

  final YorksV1TeamChatRepository? _repository;
  final SupabaseClient? _client;
  final String? _authUserId;
  final bool _enabled;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _fallback;
  bool _disposed = false;
  bool _refreshing = false;
  bool _observingLifecycle = false;
  bool _leftForeground = false;
  bool _hasRealtimeSubscription = false;
  String _activeSearchQuery = '';

  Future<void> start() async {
    if (!_enabled) {
      state = state.copyWith(
        loadingList: false,
        error: YorksV1DomainErrorCode.featureDisabled,
      );
      return;
    }
    if (_repository == null || _client == null || _authUserId == null) {
      state = state.copyWith(
        loadingList: false,
        error: YorksV1DomainErrorCode.backendUnavailable,
      );
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    await refreshConversations();
    final subscribed = await _subscribe();
    if (!subscribed) _startFallback();
  }

  Future<void> refresh({bool includeThread = true}) async {
    await refreshConversations();
    if (includeThread && state.selectedConversationId != null) {
      await _refreshThread(state.selectedConversationId!, markRead: false);
    }
  }

  Future<void> refreshConversations() async {
    if (_refreshing || _disposed || _repository == null) return;
    _refreshing = true;
    try {
      final conversations = _activeSearchQuery.length >= 2
          ? await _repository.search(_activeSearchQuery)
          : await _repository.listConversations();
      state = state.copyWith(
        conversations: conversations,
        loadingList: false,
        clearError: true,
      );
      try {
        await _repository.markDelivered(
          conversations.map((conversation) => conversation.id),
        );
      } on YorksV1DomainException {
        // Delivery acknowledgement must never clear a usable authorized list.
        // The next foreground, Realtime or safety refresh retries it.
      }
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(loadingList: false, error: error.code);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> search(String query) async {
    _activeSearchQuery = query.trim();
    await refreshConversations();
  }

  Future<void> openConversation(String conversationId) async {
    if (conversationId.trim().isEmpty || _repository == null) return;
    state = state.copyWith(
      selectedConversationId: conversationId,
      clearThread: true,
      loadingThread: true,
      clearError: true,
    );
    await _refreshThread(conversationId, markRead: true);
  }

  void closeConversation() {
    state = state.copyWith(clearSelection: true, clearThread: true);
  }

  Future<void> _refreshThread(
    String conversationId, {
    required bool markRead,
  }) async {
    final repository = _repository;
    if (repository == null || _disposed) return;
    try {
      final fetched = await repository.getConversation(conversationId);
      if (state.selectedConversationId != conversationId) return;
      var thread = fetched;
      final current = state.thread;
      if (!markRead &&
          current != null &&
          current.conversation.id == conversationId &&
          current.messages.length > fetched.messages.length) {
        final merged =
            <String, YorksV1ChatMessage>{
              for (final message in current.messages) message.id: message,
              for (final message in fetched.messages) message.id: message,
            }.values.toList()..sort((a, b) {
              final byTime = a.createdAt.compareTo(b.createdAt);
              return byTime != 0 ? byTime : a.id.compareTo(b.id);
            });
        thread = YorksV1ChatThread(
          conversation: fetched.conversation,
          participants: fetched.participants,
          messages: List.unmodifiable(merged),
        );
      }
      state = state.copyWith(
        thread: thread,
        loadingThread: false,
        hasOlderMessages: thread.messages.length >= 50,
        clearError: true,
      );
      if (markRead || thread.conversation.hasUnread) {
        await repository.markRead(conversationId);
        await refreshConversations();
      }
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(loadingThread: false, error: error.code);
    }
  }

  Future<int> loadOlderMessages() async {
    final repository = _repository;
    final current = state.thread;
    if (repository == null ||
        current == null ||
        state.loadingOlder ||
        !state.hasOlderMessages ||
        current.messages.isEmpty) {
      return 0;
    }
    state = state.copyWith(loadingOlder: true);
    try {
      final older = await repository.getConversation(
        current.conversation.id,
        before: current.messages.first.createdAt,
        limit: 50,
      );
      final existingIds = current.messages.map((item) => item.id).toSet();
      final additions = older.messages
          .where((message) => !existingIds.contains(message.id))
          .toList(growable: false);
      state = state.copyWith(
        thread: YorksV1ChatThread(
          conversation: current.conversation,
          participants: older.participants,
          messages: [...additions, ...current.messages],
        ),
        loadingOlder: false,
        hasOlderMessages: older.messages.length >= 50,
      );
      return additions.length;
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(loadingOlder: false, error: error.code);
      return 0;
    }
  }

  Future<void> loadDirectory() async {
    if (_repository == null || state.loadingDirectory) return;
    state = state.copyWith(loadingDirectory: true, clearError: true);
    try {
      state = state.copyWith(
        directory: await _repository.listDirectory(),
        loadingDirectory: false,
      );
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(loadingDirectory: false, error: error.code);
    }
  }

  Future<void> loadContextTargets(YorksV1ChatKind kind) async {
    if (_repository == null || state.loadingContextTargets) return;
    state = state.copyWith(loadingContextTargets: true, clearError: true);
    try {
      state = state.copyWith(
        contextTargets: await _repository.listContextTargets(kind),
        loadingContextTargets: false,
      );
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(loadingContextTargets: false, error: error.code);
    }
  }

  Future<void> loadAllContextTargets() async {
    if (_repository == null || state.loadingContextTargets) return;
    state = state.copyWith(loadingContextTargets: true, clearError: true);
    try {
      final projects = await _repository.listContextTargets(
        YorksV1ChatKind.project,
      );
      final requests = await _repository.listContextTargets(
        YorksV1ChatKind.materialRequest,
      );
      state = state.copyWith(
        contextTargets: [...projects, ...requests],
        loadingContextTargets: false,
      );
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(loadingContextTargets: false, error: error.code);
    }
  }

  Future<YorksV1ChatConversation?> createConversation(
    YorksV1ChatCreateInput input,
  ) async {
    final repository = _repository;
    if (repository == null) return null;
    try {
      final conversation = await repository.createConversation(input);
      await refreshConversations();
      await openConversation(conversation.id);
      return conversation;
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(error: error.code);
      return null;
    }
  }

  Future<bool> updateGroup(YorksV1ChatGroupUpdateInput input) async {
    final repository = _repository;
    if (repository == null) return false;
    try {
      await repository.updateGroup(input);
      await refreshConversations();
      await _refreshThread(input.conversationId, markRead: false);
      return true;
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(error: error.code);
      return false;
    }
  }

  Future<List<YorksV1PendingChatAttachment>> uploadFiles(
    String conversationId,
    List<YorksV1SelectedChatFile> files,
  ) async {
    final repository = _repository;
    if (repository == null) return const [];
    final uploaded = <YorksV1PendingChatAttachment>[];
    try {
      for (final file in files) {
        uploaded.add(
          await repository.uploadAttachment(
            conversationId: conversationId,
            file: file,
          ),
        );
      }
      return List.unmodifiable(uploaded);
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(error: error.code);
      rethrow;
    }
  }

  Future<bool> sendMessage(YorksV1ChatSendInput input) async {
    final repository = _repository;
    if (repository == null || state.sending) return false;
    state = state.copyWith(
      sending: true,
      outgoingInput: input,
      outgoingStatus: YorksV1ChatOutgoingStatus.sending,
      clearError: true,
    );
    try {
      await repository.sendMessage(input);
      state = state.copyWith(sending: false, clearOutgoing: true);
      await _refreshThread(input.conversationId, markRead: true);
      await refreshConversations();
      return true;
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(
        sending: false,
        outgoingInput: input,
        outgoingStatus: YorksV1ChatOutgoingStatus.failed,
        error: error.code,
      );
      return false;
    }
  }

  Future<void> markUnread(String conversationId) async {
    await _repository?.markUnread(conversationId);
    await refreshConversations();
  }

  Future<void> setPreference({
    required String conversationId,
    required String preference,
    required bool enabled,
  }) async {
    await _repository?.setPreference(
      conversationId: conversationId,
      preference: preference,
      enabled: enabled,
    );
    await refreshConversations();
  }

  Future<void> toggleAcknowledgement(String messageId) async {
    await _repository?.toggleAcknowledgement(messageId);
    final selected = state.selectedConversationId;
    if (selected != null) await _refreshThread(selected, markRead: false);
  }

  Future<void> toggleMessagePin(String messageId) async {
    await _repository?.toggleMessagePin(messageId);
    final selected = state.selectedConversationId;
    if (selected != null) await _refreshThread(selected, markRead: false);
  }

  Future<bool> editMessage(YorksV1ChatEditInput input) async {
    final repository = _repository;
    if (repository == null) return false;
    try {
      final message = await repository.editMessage(input);
      _replaceMessage(message);
      await refreshConversations();
      if (state.selectedConversationId == message.conversationId) {
        await _refreshThread(message.conversationId, markRead: false);
      }
      return true;
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(error: error.code);
      return false;
    }
  }

  Future<bool> deleteMessage(YorksV1ChatDeleteInput input) async {
    final repository = _repository;
    if (repository == null) return false;
    try {
      final message = await repository.deleteMessage(input);
      _replaceMessage(message);
      await refreshConversations();
      if (state.selectedConversationId == message.conversationId) {
        await _refreshThread(message.conversationId, markRead: false);
      }
      return true;
    } on YorksV1DomainException catch (error) {
      state = state.copyWith(error: error.code);
      return false;
    }
  }

  void _replaceMessage(YorksV1ChatMessage replacement) {
    final thread = state.thread;
    if (thread == null ||
        thread.conversation.id != replacement.conversationId) {
      return;
    }
    state = state.copyWith(
      thread: YorksV1ChatThread(
        conversation: thread.conversation,
        participants: thread.participants,
        messages: [
          for (final message in thread.messages)
            if (message.id == replacement.id) replacement else message,
        ],
      ),
    );
  }

  Future<({Uint8List bytes, String fileName, String mimeType})>
  downloadAttachment(String attachmentId) {
    final repository = _repository;
    if (repository == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    return repository.downloadAttachment(attachmentId);
  }

  Future<bool> _subscribe() async {
    final client = _client;
    final authUserId = _authUserId;
    if (client == null || authUserId == null) return false;
    try {
      final token = client.auth.currentSession?.accessToken;
      if (token == null) return false;
      await client.realtime.setAuth(token);
      _authSubscription = client.auth.onAuthStateChange.listen((event) {
        final refreshed = event.session?.accessToken;
        if (refreshed != null) unawaited(client.realtime.setAuth(refreshed));
      });
      final joined = Completer<bool>();
      void signal(PostgresChangePayload _) => unawaited(refresh());
      _channel = client
          .channel('yorks-v1-team-chat:$authUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'v1_chat_messages',
            callback: signal,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'v1_chat_conversations',
            callback: signal,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'v1_chat_members',
            callback: signal,
          )
          .subscribe((status, _) {
            if (_disposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              final reconnected = _hasRealtimeSubscription;
              _hasRealtimeSubscription = true;
              _stopFallback();
              if (!joined.isCompleted) {
                joined.complete(true);
              } else if (reconnected) {
                unawaited(refresh());
              }
              return;
            }
            if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut ||
                status == RealtimeSubscribeStatus.closed) {
              _hasRealtimeSubscription = false;
              _startFallback();
              if (!joined.isCompleted) joined.complete(false);
            }
          });
      return await joined.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  void _startFallback() {
    if (_fallback != null || _disposed) return;
    _fallback = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(refresh()),
    );
  }

  void _stopFallback() {
    _fallback?.cancel();
    _fallback = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (_leftForeground) unawaited(refresh());
      _leftForeground = false;
      return;
    }
    _leftForeground = true;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _stopFallback();
    _authSubscription?.cancel();
    final channel = _channel;
    final client = _client;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    super.dispose();
  }
}
