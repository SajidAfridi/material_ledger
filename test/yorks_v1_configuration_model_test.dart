import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_configuration.dart';

void main() {
  test('setting decodes enforcement metadata and draft attribution', () {
    final setting = YorksV1ConfigurationSetting.fromJson({
      'key': 'notifications.push_enabled',
      'area': 'notifications',
      'type': 'boolean',
      'published_value': false,
      'draft_value': true,
      'effective_value': true,
      'changed': true,
      'control_mode': 'operational',
      'impact_scope': ['notifications', 'security_audit'],
      'enforcement_target': 'notification_delivery_claim',
      'staged_by': 'Owner',
      'staged_at': '2026-08-24T08:20:00Z',
    });

    expect(setting.controlMode, YorksV1ConfigurationControlMode.operational);
    expect(setting.isOperational, isTrue);
    expect(setting.isProtected, isFalse);
    expect(setting.impactScope, [
      YorksV1ConfigurationArea.notifications,
      YorksV1ConfigurationArea.securityAudit,
    ]);
    expect(setting.enforcementTarget, 'notification_delivery_claim');
    expect(setting.stagedBy, 'Owner');
    expect(setting.stagedAt, isNotNull);
  });

  test('centre decodes shared-draft actor and operational delivery health', () {
    final centre = YorksV1ConfigurationCentre.fromJson({
      'schema_version': 'R38.5 / 1.1',
      'environment': 'production',
      'published_version': 5,
      'published_label': 'v1.4.0',
      'published_at': '2026-08-24T08:30:00Z',
      'published_by': 'Owner',
      'draft_revision': 9,
      'draft_base_version': 5,
      'draft_updated_at': '2026-08-24T08:20:00Z',
      'draft_updated_by': 'Administrator',
      'operational_health': {
        'push_enabled': true,
        'active_device_count': 12,
        'pending_delivery_count': 3,
        'recent_failure_count': 1,
        'last_successful_delivery_at': '2026-08-24T08:25:00Z',
      },
      'settings': const <Object?>[],
      'master_actions': const <Object?>[],
      'material_categories': const <Object?>[],
      'material_units': const <Object?>[],
      'boq_group_templates': const <Object?>[],
      'history': const <Object?>[],
      'validation': {
        'status': 'ready',
        'blocking': const <Object?>[],
        'recommendations': const <Object?>[],
      },
    });

    expect(centre.draftUpdatedBy, 'Administrator');
    expect(centre.operationalHealth.pushEnabled, isTrue);
    expect(centre.operationalHealth.activeDeviceCount, 12);
    expect(centre.operationalHealth.pendingDeliveryCount, 3);
    expect(centre.operationalHealth.recentFailureCount, 1);
    expect(centre.operationalHealth.lastSuccessfulDeliveryAt, isNotNull);
  });

  test('runtime and publication detail decode role-safe projections', () {
    final runtime = YorksV1RuntimeConfiguration.fromJson({
      'schema_version': 'R38.5 / 1.1',
      'published_version': 5,
      'published_label': 'v1.4.0',
      'published_at': '2026-08-24T08:30:00Z',
      'default_timing': 'normal',
      'urgent_enabled': true,
      'allow_authorized_creator_self_approval': true,
      'require_external_source_readiness': false,
      'push_enabled': true,
    });
    final detail = YorksV1ConfigurationPublicationDetail.fromJson({
      'publication': {
        'id': 'publication-5',
        'version_number': 5,
        'version_label': 'v1.4.0',
        'reason': 'Enable production notification delivery.',
        'affected_areas': ['notifications'],
        'published_at': '2026-08-24T08:30:00Z',
        'published_by': 'Owner',
        'published_by_exact_role': 'admin',
        'change_count': 1,
      },
      'changes': [
        {
          'id': 'change-1',
          'setting_key': 'notifications.push_enabled',
          'area': 'notifications',
          'before_value': false,
          'after_value': true,
          'change_kind': 'setting',
        },
      ],
    });

    expect(runtime.publishedLabel, 'v1.4.0');
    expect(runtime.urgentEnabled, isTrue);
    expect(runtime.requireExternalSourceReadiness, isFalse);
    expect(detail.publication.changeCount, 1);
    expect(detail.changes.single.settingKey, 'notifications.push_enabled');
    expect(detail.changes.single.beforeValue, isFalse);
    expect(detail.changes.single.afterValue, isTrue);
  });
}
