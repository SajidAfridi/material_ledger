import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/app/push_bridge.dart';
import 'package:material_ledger/core/theme/app_theme.dart';
import 'package:material_ledger/features/chat/presentation/screens/yorks_v1_team_chat_screen.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/models/yorks_v1_team_chat.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_team_chat_provider.dart';
import 'package:material_ledger/shared/services/push_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_chat_file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('chat projection decodes protected thread data and nested messages', () {
    final thread = YorksV1ChatThread.fromRpcJson(_threadRpcFixture());

    expect(thread.conversation.kind, YorksV1ChatKind.group);
    expect(thread.conversation.unreadCount, 2);
    expect(thread.participants, hasLength(3));
    expect(thread.participants.first.isOwner, isTrue);
    expect(thread.messages, hasLength(4));
    expect(thread.messages.first.isSystem, isTrue);
    expect(thread.messages.last.attachments.single.fileName, 'schedule.pdf');
    expect(thread.messages.last.replyPreview?.body, 'Site handover at 3 PM.');
  });

  test('chat command payloads trim text and retain server identifiers', () {
    const create = YorksV1ChatCreateInput(
      kind: YorksV1ChatKind.group,
      idempotencyKey: 'create-chat-1',
      title: '  Project Coordination  ',
      description: '  Daily site coordination  ',
      participantAuthUserIds: ['user-procurement', 'user-engineer'],
    );
    const send = YorksV1ChatSendInput(
      conversationId: 'conversation-1',
      idempotencyKey: 'send-chat-1',
      body: '  Please confirm receipt.  ',
      replyToMessageId: 'message-1',
      attachmentIds: ['attachment-1'],
      mentionedAuthUserIds: ['user-engineer'],
    );

    expect(create.toRpcPayload()['title'], 'Project Coordination');
    expect(create.toRpcPayload()['description'], 'Daily site coordination');
    expect(send.toRpcPayload()['body'], 'Please confirm receipt.');
    expect(send.toRpcPayload()['reply_to_message_id'], 'message-1');
    expect(send.toRpcPayload()['attachment_ids'], ['attachment-1']);
  });

  test(
    'attachment selection accepts the allowlist and rejects unsafe files',
    () {
      final file = YorksV1SelectedChatFile.checked(
        fileName: r'C:\handover\schedule.XLSX',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(file.fileName, 'schedule.XLSX');
      expect(
        file.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(
        () => YorksV1SelectedChatFile.checked(
          fileName: 'script.exe',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => YorksV1SelectedChatFile.checked(
          fileName: 'empty.pdf',
          bytes: Uint8List(0),
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('global unread badge excludes muted conversations', () {
    final conversations = _conversationFixtures();
    final state = YorksV1TeamChatState(
      conversations: [
        ...conversations,
        _conversation(
          id: 'muted-chat',
          kind: YorksV1ChatKind.direct,
          title: 'Muted conversation',
          description: 'Muted test fixture',
          unreadCount: 9,
          isMuted: true,
        ),
      ],
      loadingList: false,
    );

    expect(state.unreadCount, 5);
  });

  testWidgets('desktop renders the full three-pane Team Chat workspace', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    await _pumpChat(tester, preferences, selected: true);

    expect(find.text('Team Chat'), findsOneWidget);
    expect(find.text('Procurement Coordination'), findsWidgets);
    expect(find.text('Conversation info'), findsOneWidget);
    expect(find.text('Participants'), findsOneWidget);
    expect(
      find.textContaining('Chat supports coordination only'),
      findsWidgets,
    );
    expect(find.byTooltip('Attach files'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('chat-pinned-message-message-3')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile list remains focused and opens a full-width thread', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pumpChat(tester, preferences, selected: false);

    expect(find.text('Team Chat'), findsOneWidget);
    expect(find.text('Procurement Coordination'), findsOneWidget);
    expect(find.text('Conversation info'), findsNothing);
    expect(tester.takeException(), isNull);

    await _pumpChat(tester, preferences, selected: true);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(
      find.textContaining('Chat supports coordination only'),
      findsOneWidget,
    );
    expect(find.byTooltip('Attach files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile Chat exposes device-alert recovery without overflow', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    await _pumpChat(
      tester,
      preferences,
      selected: false,
      pushStatus: const PushDeliveryStatus(
        authorization: PushAuthorizationState.denied,
      ),
    );

    expect(find.byTooltip('Enable device alerts'), findsOneWidget);
    await tester.tap(find.byTooltip('Enable device alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Device alerts are blocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final evidence in <({String name, Size size, bool selected})>[
    (name: 'desktop_1366x768', size: const Size(1366, 768), selected: true),
    (name: 'tablet_900x1024', size: const Size(900, 1024), selected: true),
    (name: 'mobile_list_390x844', size: const Size(390, 844), selected: false),
    (name: 'mobile_thread_360x800', size: const Size(360, 800), selected: true),
  ]) {
    testWidgets('R38.5 Team Chat visual evidence — ${evidence.name}', (
      tester,
    ) async {
      await _setViewport(tester, evidence.size);
      await _pumpChat(tester, preferences, selected: evidence.selected);

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(YorksV1TeamChatScreen),
        matchesGoldenFile('goldens/r38_5/team_chat_${evidence.name}.png'),
      );
    });
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpChat(
  WidgetTester tester,
  SharedPreferences preferences, {
  required bool selected,
  PushDeliveryStatus? pushStatus,
}) async {
  final state = _chatState(selected: selected);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1AuthUserIdProvider.overrideWithValue('user-admin'),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.admin),
        yorksV1TeamChatProvider.overrideWith(
          (ref) => _FixtureTeamChatController(state),
        ),
        if (pushStatus != null)
          pushDeliveryStatusProvider.overrideWith(
            (ref) => Stream<PushDeliveryStatus>.value(pushStatus),
          ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(body: YorksV1TeamChatScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixtureTeamChatController extends YorksV1TeamChatController {
  _FixtureTeamChatController(YorksV1TeamChatState fixture)
    : super(repository: null, client: null, authUserId: null, enabled: false) {
    state = fixture;
  }

  @override
  Future<void> openConversation(String conversationId) async {
    state = _chatState(selected: true);
  }
}

YorksV1TeamChatState _chatState({required bool selected}) {
  final conversations = _conversationFixtures();
  final conversation = conversations.first;
  return YorksV1TeamChatState(
    conversations: conversations,
    selectedConversationId: selected ? conversation.id : null,
    thread: selected
        ? YorksV1ChatThread(
            conversation: conversation,
            participants: _participants(),
            messages: _messages(),
          )
        : null,
    loadingList: false,
    loadingThread: false,
    hasOlderMessages: false,
  );
}

List<YorksV1ChatConversation> _conversationFixtures() => [
  _conversation(
    id: 'conversation-group',
    kind: YorksV1ChatKind.group,
    title: 'Procurement Coordination',
    description: 'Daily coordination between Engineering and Procurement',
    unreadCount: 2,
    isPinned: true,
    lastMessage: _messages().last,
  ),
  _conversation(
    id: 'conversation-project',
    kind: YorksV1ChatKind.project,
    title: 'YRA-313 · Project Team',
    description: 'Yorks Regional Administration Building',
    unreadCount: 1,
    projectId: 'project-313',
    lastMessage: _message(
      id: 'project-message',
      conversationId: 'conversation-project',
      sender: 'Sher Zaman',
      body: 'The site measurements are now attached.',
    ),
  ),
  _conversation(
    id: 'conversation-request',
    kind: YorksV1ChatKind.materialRequest,
    title: 'YRA313-MR012 · Common',
    description: 'Material Request coordination',
    unreadCount: 2,
    materialRequestId: 'request-12',
    lastMessage: _message(
      id: 'request-message',
      conversationId: 'conversation-request',
      sender: 'Masaud Khan',
      body: 'Arrangement returned with one clarification.',
    ),
  ),
  _conversation(
    id: 'conversation-direct',
    kind: YorksV1ChatKind.direct,
    title: 'Silvin Pailo',
    description: 'Procurement',
    unreadCount: 0,
    lastMessage: _message(
      id: 'direct-message',
      conversationId: 'conversation-direct',
      sender: 'Silvin Pailo',
      body: 'Delivery is planned for tomorrow morning.',
    ),
  ),
  _conversation(
    id: 'conversation-announcement',
    kind: YorksV1ChatKind.announcement,
    title: 'Company Announcements',
    description: 'Official Yorks updates',
    unreadCount: 0,
    lastMessage: _message(
      id: 'announcement-message',
      conversationId: 'conversation-announcement',
      sender: 'Owner',
      body: 'Updated holiday working hours are now available.',
    ),
  ),
];

YorksV1ChatConversation _conversation({
  required String id,
  required YorksV1ChatKind kind,
  required String title,
  required String description,
  required int unreadCount,
  YorksV1ChatMessage? lastMessage,
  String? projectId,
  String? materialRequestId,
  bool isPinned = false,
  bool isMuted = false,
}) => YorksV1ChatConversation(
  id: id,
  kind: kind,
  title: title,
  description: description,
  projectId: projectId,
  materialRequestId: materialRequestId,
  createdAt: DateTime(2026, 8, 14, 9),
  updatedAt: DateTime(2026, 8, 14, 11, 42),
  lastMessageAt: DateTime(2026, 8, 14, 11, 42),
  isPinned: isPinned,
  isMuted: isMuted,
  isArchived: false,
  unreadCount: unreadCount,
  participantCount: kind == YorksV1ChatKind.direct ? 2 : 3,
  lastMessage: lastMessage,
);

List<YorksV1ChatParticipant> _participants() => const [
  YorksV1ChatParticipant(
    authUserId: 'user-admin',
    displayName: 'Owner',
    exactRole: YorksV1Role.admin,
    isOwner: true,
  ),
  YorksV1ChatParticipant(
    authUserId: 'user-procurement',
    displayName: 'Silvin Pailo',
    exactRole: YorksV1Role.procurement,
  ),
  YorksV1ChatParticipant(
    authUserId: 'user-engineer',
    displayName: 'Masaud Khan',
    exactRole: YorksV1Role.projectEngineer,
  ),
];

List<YorksV1ChatMessage> _messages() => [
  YorksV1ChatMessage(
    id: 'system-message',
    conversationId: 'conversation-group',
    kind: 'system',
    systemEventCode: 'conversation_created',
    body: 'Owner created this group.',
    createdAt: DateTime(2026, 8, 14, 9),
    isMine: false,
    isPinned: false,
    acknowledgementCount: 0,
    acknowledgedByMe: false,
    attachments: const [],
    mentionedAuthUserIds: const [],
  ),
  _message(
    id: 'message-1',
    conversationId: 'conversation-group',
    sender: 'Silvin Pailo',
    body: 'Site handover at 3 PM.',
  ),
  _message(
    id: 'message-2',
    conversationId: 'conversation-group',
    sender: 'Owner',
    body: '@MasaudKhan please confirm the unloading team.',
    isMine: true,
  ),
  YorksV1ChatMessage(
    id: 'message-3',
    conversationId: 'conversation-group',
    kind: 'message',
    senderAuthUserId: 'user-engineer',
    senderDisplayName: 'Masaud Khan',
    senderExactRole: YorksV1Role.projectEngineer,
    body: 'Confirmed. The signed schedule is attached.',
    replyToMessageId: 'message-1',
    replyPreview: const YorksV1ChatReplyPreview(
      id: 'message-1',
      senderDisplayName: 'Silvin Pailo',
      body: 'Site handover at 3 PM.',
    ),
    createdAt: DateTime(2026, 8, 14, 11, 42),
    isMine: false,
    isPinned: true,
    acknowledgementCount: 2,
    acknowledgedByMe: true,
    attachments: const [
      YorksV1ChatAttachment(
        id: 'attachment-1',
        fileName: 'schedule.pdf',
        mimeType: 'application/pdf',
        byteSize: 185240,
      ),
    ],
    mentionedAuthUserIds: const [],
  ),
];

YorksV1ChatMessage _message({
  required String id,
  required String conversationId,
  required String sender,
  required String body,
  bool isMine = false,
}) => YorksV1ChatMessage(
  id: id,
  conversationId: conversationId,
  kind: 'message',
  senderAuthUserId: isMine ? 'user-admin' : 'user-procurement',
  senderDisplayName: sender,
  senderExactRole: isMine ? YorksV1Role.admin : YorksV1Role.procurement,
  body: body,
  createdAt: DateTime(2026, 8, 14, 10, 30),
  isMine: isMine,
  isPinned: false,
  acknowledgementCount: 0,
  acknowledgedByMe: false,
  attachments: const [],
  mentionedAuthUserIds: const [],
);

Map<String, dynamic> _threadRpcFixture() => {
  'id': 'conversation-group',
  'kind': 'group',
  'title': 'Procurement Coordination',
  'description': 'Daily coordination',
  'project_id': null,
  'material_request_id': null,
  'created_at': '2026-08-14T04:00:00Z',
  'updated_at': '2026-08-14T06:42:00Z',
  'last_message_at': '2026-08-14T06:42:00Z',
  'is_pinned': true,
  'is_muted': false,
  'is_archived': false,
  'unread_count': 2,
  'participant_count': 3,
  'last_message': null,
  'participants': [
    {
      'auth_user_id': 'user-admin',
      'display_name': 'Owner',
      'exact_role': 'admin',
      'member_role': 'owner',
    },
    {
      'auth_user_id': 'user-procurement',
      'display_name': 'Silvin Pailo',
      'exact_role': 'procurement',
      'member_role': 'member',
    },
    {
      'auth_user_id': 'user-engineer',
      'display_name': 'Masaud Khan',
      'exact_role': 'project_engineer',
      'member_role': 'member',
    },
  ],
  'messages': [
    {
      'id': 'system-message',
      'conversation_id': 'conversation-group',
      'kind': 'system',
      'system_event_code': 'conversation_created',
      'sender_auth_user_id': null,
      'sender_display_name': null,
      'sender_exact_role': null,
      'body': 'Owner created this group.',
      'reply_to_message_id': null,
      'reply_preview': null,
      'linked_entity_type': null,
      'linked_entity_id': null,
      'created_at': '2026-08-14T04:00:00Z',
      'is_mine': false,
      'is_pinned': false,
      'acknowledgement_count': 0,
      'acknowledged_by_me': false,
      'attachments': [],
      'mentions': [],
    },
    ..._messages().skip(1).map(_messageToRpc),
  ],
};

Map<String, dynamic> _messageToRpc(YorksV1ChatMessage message) => {
  'id': message.id,
  'conversation_id': message.conversationId,
  'kind': message.kind,
  'system_event_code': message.systemEventCode,
  'sender_auth_user_id': message.senderAuthUserId,
  'sender_display_name': message.senderDisplayName,
  'sender_exact_role': message.senderExactRole?.claimValue,
  'body': message.body,
  'reply_to_message_id': message.replyToMessageId,
  'reply_preview': message.replyPreview == null
      ? null
      : {
          'id': message.replyPreview!.id,
          'sender_display_name': message.replyPreview!.senderDisplayName,
          'body': message.replyPreview!.body,
        },
  'linked_entity_type': message.linkedEntityType,
  'linked_entity_id': message.linkedEntityId,
  'created_at': message.createdAt.toUtc().toIso8601String(),
  'is_mine': message.isMine,
  'is_pinned': message.isPinned,
  'acknowledgement_count': message.acknowledgementCount,
  'acknowledged_by_me': message.acknowledgedByMe,
  'attachments': message.attachments
      .map(
        (attachment) => {
          'id': attachment.id,
          'file_name': attachment.fileName,
          'mime_type': attachment.mimeType,
          'byte_size': attachment.byteSize,
        },
      )
      .toList(),
  'mentions': message.mentionedAuthUserIds,
};
