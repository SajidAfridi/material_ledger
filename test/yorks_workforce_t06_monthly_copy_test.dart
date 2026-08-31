import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/yorks_v1_workforce_strings.dart';

const _monthlyKeys = <String>[
  'monthly_timesheets',
  'monthly_body',
  'monthly_team',
  'monthly_month',
  'monthly_select_team',
  'monthly_select_month',
  'monthly_search_teams',
  'monthly_search_workers',
  'monthly_teams_loading',
  'monthly_teams_empty',
  'monthly_validate',
  'monthly_revalidate',
  'monthly_validating',
  'monthly_validated',
  'monthly_validation_hint',
  'monthly_validation_failed_title',
  'monthly_validation_failed_body',
  'monthly_validation_conflict_title',
  'monthly_validation_conflict_body',
  'monthly_validation_uncertain_title',
  'monthly_validation_uncertain_body',
  'monthly_access_changed_title',
  'monthly_access_changed_body',
  'monthly_online_required',
  'monthly_online_required_body',
  'monthly_absent_title',
  'monthly_absent_body',
  'monthly_stale_title',
  'monthly_stale_body',
  'monthly_read_only_title',
  'monthly_read_only_body',
  'monthly_status_draft',
  'monthly_status_ready',
  'monthly_summary',
  'monthly_metric_workers',
  'monthly_metric_dates',
  'monthly_metric_scheduled',
  'monthly_metric_future',
  'monthly_metric_present',
  'monthly_metric_absent',
  'monthly_metric_leave',
  'monthly_metric_weekly_off',
  'monthly_metric_public_holiday',
  'monthly_metric_site_closure',
  'monthly_metric_missing',
  'monthly_metric_regular',
  'monthly_metric_overtime',
  'monthly_metric_allocation',
  'monthly_metric_blocking',
  'monthly_metric_warnings',
  'monthly_metric_projects',
  'monthly_metric_locations',
  'monthly_workers',
  'monthly_worker_number',
  'monthly_worker_name',
  'monthly_worker_trade',
  'monthly_worker_employer',
  'monthly_worker_period',
  'monthly_worker_supervisors',
  'monthly_worker_targets',
  'monthly_worker_projects',
  'monthly_worker_locations',
  'monthly_worker_days',
  'monthly_worker_hours',
  'monthly_worker_issues',
  'monthly_worker_scheduled',
  'monthly_worker_present',
  'monthly_worker_absent',
  'monthly_worker_leave',
  'monthly_worker_regular',
  'monthly_worker_overtime',
  'monthly_worker_missing',
  'monthly_worker_status',
  'monthly_worker_status_complete',
  'monthly_worker_status_warnings',
  'monthly_worker_status_errors',
  'monthly_issue_filters',
  'monthly_issue_all',
  'monthly_issue_blocking',
  'monthly_issue_warning',
  'monthly_issue_type',
  'monthly_issue_clear_filters',
  'monthly_issue_none',
  'monthly_calendar',
  'monthly_day_detail',
  'monthly_select_worker',
  'monthly_day_type',
  'monthly_day_type_regular_working_day',
  'monthly_day_type_weekly_off',
  'monthly_day_type_public_holiday',
  'monthly_day_type_site_closed',
  'monthly_day_type_not_scheduled',
  'monthly_day_required',
  'monthly_day_future',
  'monthly_day_attendance',
  'monthly_day_scheduled',
  'monthly_day_regular',
  'monthly_day_overtime',
  'monthly_day_allocation',
  'monthly_day_status_future',
  'monthly_day_status_not_started',
  'monthly_day_status_complete',
  'monthly_day_status_warnings',
  'monthly_day_status_errors',
  'monthly_loading',
  'monthly_load_failed',
  'monthly_load_failed_body',
  'monthly_empty',
  'monthly_load_more',
  'monthly_retry',
  'monthly_close',
];

const _monthlyIssueCodes = <String>[
  'schedule_context_missing',
  'required_attendance_missing',
  'attendance_status_invalid',
  'attendance_minutes_invalid',
  'absent_with_work_minutes',
  'leave_with_work_minutes',
  'allocation_minutes_mismatch',
  'allocation_interval_overlap',
  'daily_minutes_over_1440',
  'attendance_before_joining',
  'attendance_after_leaving',
  'worker_inactive',
  'assignment_invalid',
  'supervisor_invalid',
  'allocation_target_invalid',
  'validation_stale',
  'work_on_weekly_off',
  'work_on_public_holiday',
  'work_on_site_closure',
  'below_standard_minutes',
  'assignment_changed_in_period',
  'supervisor_changed_in_period',
  'activity_missing',
  'allocation_off_assignment',
  'attendance_backdated',
];

Iterable<String> get _allMonthlyKeys sync* {
  yield* _monthlyKeys;
  for (final issueCode in _monthlyIssueCodes) {
    yield 'monthly_issue_$issueCode';
  }
}

void main() {
  test(
    'T06 Monthly copy covers every accepted locale without fallback keys',
    () {
      for (final key in _allMonthlyKeys) {
        final english = YorksV1WorkforceStrings.text(AppLanguage.english, key);
        expect(english.trim(), isNotEmpty, reason: '$key English copy');
        expect(english, isNot(key), reason: '$key must not use fallback copy');

        for (final language in AppLanguage.values.where(
          (language) => language != AppLanguage.english,
        )) {
          final localized = YorksV1WorkforceStrings.text(language, key);
          expect(
            localized.trim(),
            isNotEmpty,
            reason: '$key ${language.code} copy',
          );
          expect(
            localized,
            isNot(key),
            reason: '$key ${language.code} must not use fallback copy',
          );
          expect(
            localized,
            isNot(english),
            reason: '$key ${language.code} must not silently use English',
          );
        }
      }
    },
  );

  test('T06 Monthly copy stays inside validation-only lifecycle language', () {
    final deferredAction = RegExp(
      r'\b(submit|review|verify|approve|lock|reopen)\b',
      caseSensitive: false,
    );
    for (final key in _allMonthlyKeys) {
      final english = YorksV1WorkforceStrings.text(AppLanguage.english, key);
      expect(
        deferredAction.hasMatch(english),
        isFalse,
        reason: '$key must not promise a deferred lifecycle action: $english',
      );
    }

    expect(
      YorksV1WorkforceStrings.text(AppLanguage.english, 'monthly_absent_body'),
      contains('No period was created by opening this view.'),
    );
    expect(
      YorksV1WorkforceStrings.text(AppLanguage.english, 'monthly_status_ready'),
      'Ready',
    );
  });
}
