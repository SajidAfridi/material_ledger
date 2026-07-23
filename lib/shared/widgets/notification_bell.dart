import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/constants.dart';
import '../models/app_strings.dart';
import '../providers/notification_provider.dart';

/// Notification bell with an unread dot. Reusable across every tab root so the
/// admin (and every role) can reach alerts without first navigating Home — the
/// bell used to live only on the dashboard header.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: AppStrings.notifications.primary,
          onPressed: () => context.push(RoutePaths.notifications),
          icon: const Icon(Icons.notifications_outlined),
          style: IconButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
