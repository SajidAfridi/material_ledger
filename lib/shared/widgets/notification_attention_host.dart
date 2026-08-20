import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_provider.dart';
import '../services/application_attention_service.dart';

/// Mirrors authoritative unread attention onto the app/window shell.
///
/// Workflow rows and Team Chat keep their own correct read semantics. This host
/// only combines their visible unresolved counts for the external app badge,
/// browser title and native desktop attention surfaces. It never writes read
/// state, stores a device-local badge or changes either notification centre.
class NotificationAttentionHost extends ConsumerStatefulWidget {
  const NotificationAttentionHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationAttentionHost> createState() =>
      _NotificationAttentionHostState();
}

class _NotificationAttentionHostState
    extends ConsumerState<NotificationAttentionHost> {
  ProviderSubscription<int>? _subscription;
  int _previousUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(yorksApplicationUnreadCountProvider, (
      _,
      next,
    ) {
      final unreadCount = next < 0 ? 0 : next;
      final attentionRaised = unreadCount > _previousUnreadCount;
      _previousUnreadCount = unreadCount;
      unawaited(
        ref
            .read(yorksApplicationAttentionServiceProvider)
            .update(unreadCount: unreadCount, attentionRaised: attentionRaised)
            .catchError((_) {}),
      );
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
