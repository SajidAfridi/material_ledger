import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_configuration_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  test('configuration parses calendar, Ramadan date and night shift', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_get_workforce_configuration');
      expect(parameters, {'p_on_date': '2027-03-01'});
      return _configurationResponse();
    });

    final projection = await _repository(
      rpc: rpc,
    ).getConfiguration(onDate: '2027-03-01');

    expect(projection.authorizationMode, 'admin_legacy_t02');
    expect(projection.calendars.single.weekdays, hasLength(7));
    expect(
      projection.calendars.single.dateOverrides.single.overrideKind,
      YorksWorkforceCalendarOverrideKind.ramadan,
    );
    expect(projection.shiftTemplates.single.crossesMidnight, isTrue);
    expect(
      projection.shiftTemplates.single.kind,
      YorksWorkforceShiftKind.night,
    );
    expect(projection.teamScheduleLinks.single.shiftCode, 'NIGHT');
  });

  test('configuration without a date uses the server default', () async {
    final rpc = _RpcClient((functionName, parameters) {
      expect(functionName, 'v1_get_workforce_configuration');
      expect(parameters, isEmpty);
      return _configurationResponse();
    });

    await _repository(rpc: rpc).getConfiguration();
  });

  test(
    'save calendar sends version and idempotency through typed boundary',
    () async {
      final rpc = _RpcClient((functionName, parameters) {
        expect(functionName, 'v1_save_workforce_calendar');
        expect(parameters, {
          'p_payload': {'calendar_code': 'UAE-SITE'},
          'p_expected_version': 2,
          'p_idempotency_key': 'calendar-key',
        });
        return {
          'schema_version': 1,
          'calendar_id': 'calendar-1',
          'record_version': 3,
        };
      });

      final result = await _repository(rpc: rpc).saveCalendar(
        const {'calendar_code': 'UAE-SITE'},
        expectedVersion: 2,
        idempotencyKey: ' calendar-key ',
      );

      expect(result.entityId, 'calendar-1');
      expect(result.recordVersion, 3);
    },
  );

  test('malformed configuration response fails closed', () async {
    final response = _configurationResponse();
    (response['shift_templates'] as List).first['work_date_basis'] =
        'shift_end_date';

    await expectLater(
      _repository(
        rpc: _RpcClient((_, _) => response),
      ).getConfiguration(onDate: '2027-03-01'),
      throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
    );
  });

  test(
    'calendar response without all seven ISO weekdays fails closed',
    () async {
      final response = _configurationResponse();
      final calendar = (response['calendars'] as List).single as Map;
      (calendar['weekdays'] as List).removeLast();

      await expectLater(
        _repository(
          rpc: _RpcClient((_, _) => response),
        ).getConfiguration(onDate: '2027-03-01'),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test('feature flag fails before configuration RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    final repository = _repository(
      rpc: rpc,
      featureFlags: const YorksV1FeatureFlags(
        foundation: true,
        projects: true,
        boq: true,
        excel: true,
        requests: true,
        arrangement: true,
        logistics: true,
        returnsDocuments: true,
        documents: true,
      ),
    );

    await expectLater(
      repository.getConfiguration(),
      throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('offline state fails before configuration RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));

    await expectLater(
      _repository(
        rpc: rpc,
        connectivity: const _Connectivity(false),
      ).getConfiguration(),
      throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
    );
    expect(rpc.calls, isEmpty);
  });

  test('missing backend fails before configuration request', () async {
    await expectLater(
      _repository().getConfiguration(),
      throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
    );
  });

  test('invalid date and optimistic input fail before RPC', () async {
    final rpc = _RpcClient((_, _) => throw StateError('must not call'));
    final repository = _repository(rpc: rpc);

    await expectLater(
      repository.getConfiguration(onDate: '2027-02-30'),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    await expectLater(
      repository.saveShiftTemplate(
        const {},
        expectedVersion: 0,
        idempotencyKey: 'shift-key',
      ),
      throwsA(_domainCode(YorksV1DomainErrorCode.invalidInput)),
    );
    expect(rpc.calls, isEmpty);
  });
}

YorksSupabaseWorkforceRepository _repository({
  YorksWorkforceRpcClient? rpc,
  YorksV1FeatureFlags featureFlags = const YorksV1FeatureFlags(
    foundation: true,
    projects: true,
    boq: true,
    excel: true,
    requests: true,
    arrangement: true,
    logistics: true,
    returnsDocuments: true,
    documents: true,
    workforce: true,
  ),
  ConnectivityService connectivity = const _Connectivity(true),
}) => YorksSupabaseWorkforceRepository(
  featureFlags: featureFlags,
  connectivity: connectivity,
  rpcClient: rpc,
);

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);

Map<String, dynamic> _configurationResponse() => {
  'schema_version': 1,
  'authorization_mode': 'admin_legacy_t02',
  'actor_auth_user_id': 'admin-1',
  'on_date': '2027-03-01',
  'server_time': '2027-03-01T08:00:00Z',
  'calendars': [
    {
      'calendar_id': 'calendar-1',
      'calendar_code': 'UAE-SITE',
      'calendar_name': 'UAE Site Calendar',
      'timezone_name': 'Asia/Dubai',
      'standard_scheduled_minutes': 480,
      'break_minutes': 60,
      'valid_from': '2026-01-01',
      'valid_to': null,
      'is_active': true,
      'is_effective': true,
      'record_version': 1,
      'weekdays': [
        for (var weekday = 1; weekday <= 7; weekday++)
          {
            'iso_weekday': weekday,
            'day_type': weekday <= 5 ? 'regular_working_day' : 'weekly_off',
          },
      ],
      'date_overrides': [
        {
          'calendar_date_id': 'date-1',
          'calendar_date': '2027-03-01',
          'override_kind': 'ramadan',
          'day_type': 'regular_working_day',
          'exception_name': 'Ramadan schedule',
          'scheduled_minutes': 360,
          'break_minutes': 0,
          'shift_template_id': 'shift-1',
          'notes': null,
          'is_active': true,
          'record_version': 1,
        },
      ],
    },
  ],
  'shift_templates': [
    {
      'shift_template_id': 'shift-1',
      'shift_code': 'NIGHT',
      'shift_name': 'Night Shift',
      'shift_kind': 'night',
      'start_time': '22:00:00',
      'end_time': '06:00:00',
      'scheduled_minutes': 420,
      'break_minutes': 60,
      'crosses_midnight': true,
      'work_date_basis': 'shift_start_date',
      'valid_from': '2026-01-01',
      'valid_to': null,
      'is_active': true,
      'is_effective': true,
      'record_version': 1,
    },
  ],
  'team_schedule_links': [
    {
      'team_schedule_link_id': 'link-1',
      'team_id': 'team-1',
      'team_code': 'T-01',
      'team_name': 'Night Team',
      'calendar_id': 'calendar-1',
      'calendar_code': 'UAE-SITE',
      'calendar_name': 'UAE Site Calendar',
      'timezone_name': 'Asia/Dubai',
      'shift_template_id': 'shift-1',
      'shift_code': 'NIGHT',
      'shift_name': 'Night Shift',
      'valid_from': '2026-01-01',
      'valid_to': null,
      'reason': 'Default night schedule',
      'is_effective': true,
      'record_version': 1,
    },
  ],
};

final class _RpcClient implements YorksWorkforceRpcClient {
  _RpcClient(this.handler);

  final Map<String, dynamic> Function(
    String functionName,
    Map<String, Object?> parameters,
  )
  handler;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(functionName);
    return handler(functionName, parameters);
  }
}

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);

  @override
  final bool isOnline;

  @override
  Stream<bool> get onChange => const Stream.empty();
}
