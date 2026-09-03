import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';
import 'package:material_ledger/shared/models/yorks_v1_team_chat.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_team_chat_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_notification_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_team_chat_repository.dart';
import 'package:material_ledger/shared/sync/authorized_refresh_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initial and recovered joins refresh, repeated healthy joins do not',
    () {
      final readiness = AuthorizedRefreshReadiness();
      expect(readiness.markAvailable(), isTrue);
      expect(readiness.markAvailable(), isFalse);
      readiness.markUnavailable();
      readiness.markUnavailable();
      expect(readiness.markAvailable(), isTrue);
      expect(readiness.markAvailable(), isFalse);
    },
  );

  test('a late initial join after unavailability still closes the gap', () {
    final readiness = AuthorizedRefreshReadiness()..markUnavailable();
    expect(readiness.markAvailable(), isTrue);
  });

  test('signals during an in-flight read become one trailing read', () async {
    final first = Completer<void>();
    var calls = 0;
    final queue = AuthorizedRefreshQueue(() async {
      calls += 1;
      if (calls == 1) await first.future;
    });
    final requests = List.generate(20, (_) => queue.request());
    expect(calls, 1);
    first.complete();
    await Future.wait(requests);
    expect(calls, 2);
    await queue.request();
    expect(calls, 3);
  });

  test('an event during the trailing read is not lost', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    var calls = 0;
    final queue = AuthorizedRefreshQueue(() async {
      calls += 1;
      if (calls == 1) await first.future;
      if (calls == 2) await second.future;
    });
    final result = queue.request();
    unawaited(queue.request());
    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);
    unawaited(queue.request());
    second.complete();
    await result;
    expect(calls, 3);
  });

  test(
    'disposal cancels pending reads without cancelling a server command',
    () async {
      final first = Completer<void>();
      var calls = 0;
      final queue = AuthorizedRefreshQueue(() async {
        calls += 1;
        await first.future;
      });
      final result = queue.request();
      unawaited(queue.request());
      queue.dispose();
      first.complete();
      await result;
      await queue.request();
      expect(calls, 1);
    },
  );

  test('a failed read releases the queue for a later retry', () async {
    var calls = 0;
    final queue = AuthorizedRefreshQueue(() async {
      if (++calls == 1) throw StateError('temporary failure');
    });
    await expectLater(queue.request(), throwsStateError);
    await queue.request();
    expect(calls, 2);
  });

  test('chat bursts coalesce both the list and selected thread', () async {
    final repository = _ChatRepository();
    final controller = YorksV1TeamChatController(
      repository: repository,
      client: null,
      authUserId: 'test',
      enabled: true,
    );
    addTearDown(controller.dispose);
    await controller.openConversation('conversation');
    final priorLists = repository.listCalls;
    final priorThreads = repository.threadCalls;
    repository.pendingList = Completer<List<YorksV1ChatConversation>>();
    final results = List.generate(20, (_) => controller.refresh());
    expect(repository.listCalls - priorLists, 1);
    repository.pendingList!.complete([]);
    await Future.wait(results);
    expect(repository.listCalls - priorLists, 2);
    expect(repository.threadCalls - priorThreads, 2);
  });

  test('notification bursts retain a trailing authorized fetch', () async {
    final repository = _NotificationRepository();
    final controller = YorksV1NotificationsNotifier(
      repository: repository,
      client: null,
      authUserId: 'test',
    );
    addTearDown(controller.dispose);
    final results = List.generate(20, (_) => controller.refresh());
    expect(repository.calls, 1);
    repository.first.complete([]);
    await Future.wait(results);
    expect(repository.calls, 2);
    expect(controller.state.hasValue, isTrue);
  });

  test(
    'logout during a list fetch never issues a late delivery write',
    () async {
      final repository = _ChatRepository()
        ..pendingList = Completer<List<YorksV1ChatConversation>>();
      final controller = YorksV1TeamChatController(
        repository: repository,
        client: null,
        authUserId: 'test',
        enabled: true,
      );
      final result = controller.refreshConversations();
      controller.dispose();
      repository.pendingList!.complete([repository.conversation]);
      await result;
      expect(repository.deliveryCalls, 0);
    },
  );
}

class _NotificationRepository extends Fake
    implements YorksV1NotificationRepository {
  final first = Completer<List<YorksV1NotificationRecord>>();
  int calls = 0;
  @override
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100}) async {
    return ++calls == 1 ? await first.future : [];
  }
}

class _ChatRepository extends Fake implements YorksV1TeamChatRepository {
  int listCalls = 0;
  int threadCalls = 0;
  int deliveryCalls = 0;
  Completer<List<YorksV1ChatConversation>>? pendingList;
  YorksV1ChatConversation get conversation => YorksV1ChatConversation(
    id: 'conversation',
    kind: YorksV1ChatKind.group,
    title: 'Test',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    isPinned: false,
    isMuted: false,
    isArchived: false,
    unreadCount: 0,
    participantCount: 1,
  );
  @override
  Future<List<YorksV1ChatConversation>> listConversations() async {
    listCalls += 1;
    final pending = pendingList;
    if (pending != null && !pending.isCompleted) return pending.future;
    return [];
  }

  @override
  Future<YorksV1ChatThread> getConversation(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    threadCalls += 1;
    return YorksV1ChatThread(
      conversation: conversation,
      participants: [],
      messages: [],
    );
  }

  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<void> markDelivered(Iterable<String> conversationIds) async {
    deliveryCalls += 1;
  }
}
