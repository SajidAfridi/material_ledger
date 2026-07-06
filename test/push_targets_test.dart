import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/app_user.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';

AppUser _user(String id, UserRole role, {bool active = true}) => AppUser(
      id: id,
      fullName: id,
      email: '$id@test.com',
      role: role,
      active: active,
      createdAt: DateTime(2026, 1, 1),
    );

AppNotification _notif({String userId = '', String audience = ''}) =>
    AppNotification(
      id: 'n1',
      type: NotificationType.request,
      title: 't',
      titleSecondary: '',
      timestamp: DateTime(2026, 1, 1),
      userId: userId,
      audience: audience,
    );

void main() {
  final users = [
    _user('usr-eng-1', UserRole.engineer),
    _user('usr-eng-2', UserRole.engineer),
    _user('usr-proc-1', UserRole.procurement),
    _user('usr-eng-inactive', UserRole.engineer, active: false),
  ];

  group('resolvePushTargets', () {
    test('a personally-targeted notification pushes only that user', () {
      final targets = resolvePushTargets(
        _notif(userId: 'usr-eng-1'),
        users,
        currentUserId: 'usr-admin',
      );
      expect(targets, {'usr-eng-1'});
    });

    test('a role-audience notification fans out to every active user of that role', () {
      final targets = resolvePushTargets(
        _notif(audience: 'engineer'),
        users,
        currentUserId: 'usr-admin',
      );
      expect(targets, {'usr-eng-1', 'usr-eng-2'});
    });

    test('an inactive user of the target role is excluded', () {
      final targets = resolvePushTargets(
        _notif(audience: 'engineer'),
        users,
        currentUserId: 'usr-admin',
      );
      expect(targets.contains('usr-eng-inactive'), false);
    });

    test('the acting user is excluded even if they match the target', () {
      final targets = resolvePushTargets(
        _notif(audience: 'engineer'),
        users,
        currentUserId: 'usr-eng-1', // the actor is one of the targeted engineers
      );
      expect(targets, {'usr-eng-2'});
    });

    test('a pure broadcast (no userId, no audience) has no push recipients', () {
      final targets = resolvePushTargets(_notif(), users, currentUserId: 'usr-admin');
      expect(targets, isEmpty);
    });

    test('userId takes precedence over audience when both are set', () {
      final targets = resolvePushTargets(
        _notif(userId: 'usr-proc-1', audience: 'engineer'),
        users,
        currentUserId: 'usr-admin',
      );
      expect(targets, {'usr-proc-1'});
    });
  });
}
