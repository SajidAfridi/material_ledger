import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_feature_flags_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_team_chat_provider.dart';
import 'package:material_ledger/shared/services/application_attention_service.dart';
import 'package:material_ledger/shared/widgets/notification_attention_host.dart';

final _workflowUnreadOverride = StateProvider<int>((_) => 0);
final _chatUnreadOverride = StateProvider<int>((_) => 0);

void main() {
  test('badge title is compact and returns to the Yorks application title', () {
    expect(yorksDisplayedUnreadCount(-4), 0);
    expect(yorksDisplayedUnreadCount(123), 99);
    expect(yorksUnreadBadgeLabel(100), '99+');
    expect(yorksApplicationWindowTitle(2), '(2) Yorks AC. & Ref.');
    expect(yorksApplicationWindowTitle(0), 'Yorks AC. & Ref.');
  });

  testWidgets(
    'external application attention combines workflow and chat without merging their centres',
    (tester) async {
      final attention = _FakeApplicationAttentionService();
      final container = ProviderContainer(
        overrides: [
          yorksV1FeatureFlagsProvider.overrideWithValue(_chatEnabledFlags),
          unreadNotificationCountProvider.overrideWith(
            (ref) => ref.watch(_workflowUnreadOverride),
          ),
          yorksV1TeamChatUnreadProvider.overrideWith(
            (ref) => ref.watch(_chatUnreadOverride),
          ),
          yorksApplicationAttentionServiceProvider.overrideWithValue(attention),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NotificationAttentionHost(
            child: MaterialApp(home: Scaffold(body: Text('Workspace'))),
          ),
        ),
      );
      await tester.pump();

      expect(attention.updates, [const _AttentionUpdate(0, false)]);

      container.read(_workflowUnreadOverride.notifier).state = 2;
      await tester.pump();
      expect(attention.updates.last, const _AttentionUpdate(2, true));

      container.read(_chatUnreadOverride.notifier).state = 3;
      await tester.pump();
      expect(attention.updates.last, const _AttentionUpdate(5, true));

      container.read(_workflowUnreadOverride.notifier).state = 0;
      container.read(_chatUnreadOverride.notifier).state = 0;
      await tester.pump();
      expect(attention.updates.last, const _AttentionUpdate(0, false));
    },
  );
}

const _chatEnabledFlags = YorksV1FeatureFlags(
  foundation: true,
  projects: true,
  boq: true,
  excel: true,
  requests: true,
  arrangement: true,
  logistics: true,
  returnsDocuments: true,
  documents: true,
  teamChat: true,
);

class _FakeApplicationAttentionService
    implements YorksApplicationAttentionService {
  final List<_AttentionUpdate> updates = [];

  @override
  Future<void> update({
    required int unreadCount,
    required bool attentionRaised,
  }) async {
    updates.add(_AttentionUpdate(unreadCount, attentionRaised));
  }
}

class _AttentionUpdate {
  const _AttentionUpdate(this.unreadCount, this.attentionRaised);

  final int unreadCount;
  final bool attentionRaised;

  @override
  bool operator ==(Object other) =>
      other is _AttentionUpdate &&
      other.unreadCount == unreadCount &&
      other.attentionRaised == attentionRaised;

  @override
  int get hashCode => Object.hash(unreadCount, attentionRaised);
}
