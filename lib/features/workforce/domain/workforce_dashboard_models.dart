enum YorksWorkforceOverviewKind {
  supervisor,
  management,
  admin;

  static YorksWorkforceOverviewKind fromWire(Object? value) =>
      values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => throw const FormatException('Unknown overview kind'),
      );
}

final class YorksWorkforceOverviewRequest {
  const YorksWorkforceOverviewRequest({
    required this.kind,
    this.teamId,
    this.projectId,
  });

  final YorksWorkforceOverviewKind kind;
  final String? teamId;
  final String? projectId;

  Map<String, Object?> toRpcJson() {
    if (kind != YorksWorkforceOverviewKind.supervisor && teamId != null ||
        kind != YorksWorkforceOverviewKind.management && projectId != null ||
        teamId != null && !_isUuid(teamId!) ||
        projectId != null && !_isUuid(projectId!)) {
      throw const FormatException('Invalid overview scope');
    }
    return <String, Object?>{
      'overview_kind': kind.name,
      if (teamId != null) 'team_id': teamId,
      if (projectId != null) 'project_id': projectId,
    };
  }
}

final class YorksWorkforceOverviewAsOf {
  const YorksWorkforceOverviewAsOf({
    required this.timezone,
    required this.localDate,
    required this.teamCount,
  });

  final String timezone;
  final String localDate;
  final int teamCount;

  factory YorksWorkforceOverviewAsOf.fromJson(Map<String, dynamic> json) {
    _exact(json, const {
      'calendar_timezone',
      'local_date',
      'team_count',
    }, 'as-of');
    return YorksWorkforceOverviewAsOf(
      timezone: _text(json['calendar_timezone']),
      localDate: _date(json['local_date']),
      teamCount: _integer(json['team_count']),
    );
  }
}

final class YorksWorkforceOverviewMetrics {
  const YorksWorkforceOverviewMetrics({
    required this.workerCount,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
    required this.notEnteredCount,
    required this.todayEnteredCount,
    required this.todayCompletionPercent,
    required this.monthRequiredCount,
    required this.monthEnteredCount,
    required this.monthCompletionPercent,
    required this.warningCount,
    required this.returnedCorrectionCount,
    required this.canCompleteTodayAttendance,
  });

  final int workerCount;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int notEnteredCount;
  final int todayEnteredCount;
  final double todayCompletionPercent;
  final int monthRequiredCount;
  final int monthEnteredCount;
  final double monthCompletionPercent;
  final int warningCount;
  final int returnedCorrectionCount;
  final bool canCompleteTodayAttendance;

  factory YorksWorkforceOverviewMetrics.fromJson(Map<String, dynamic> json) {
    _exact(json, const {
      'worker_count',
      'present_count',
      'absent_count',
      'leave_count',
      'not_entered_count',
      'today_entered_count',
      'today_completion_percent',
      'month_required_count',
      'month_entered_count',
      'month_completion_percent',
      'warning_count',
      'returned_correction_count',
      'can_complete_today_attendance',
    }, 'team metrics');
    return YorksWorkforceOverviewMetrics(
      workerCount: _integer(json['worker_count']),
      presentCount: _integer(json['present_count']),
      absentCount: _integer(json['absent_count']),
      leaveCount: _integer(json['leave_count']),
      notEnteredCount: _integer(json['not_entered_count']),
      todayEnteredCount: _integer(json['today_entered_count']),
      todayCompletionPercent: _percent(json['today_completion_percent']),
      monthRequiredCount: _integer(json['month_required_count']),
      monthEnteredCount: _integer(json['month_entered_count']),
      monthCompletionPercent: _percent(json['month_completion_percent']),
      warningCount: _integer(json['warning_count']),
      returnedCorrectionCount: _integer(json['returned_correction_count']),
      canCompleteTodayAttendance: _boolean(
        json['can_complete_today_attendance'],
      ),
    );
  }
}

final class YorksWorkforceOverviewTeam {
  const YorksWorkforceOverviewTeam({
    required this.teamId,
    required this.teamCode,
    required this.teamName,
    required this.projectId,
    required this.projectRef,
    required this.projectName,
    required this.supervisorName,
    required this.calendarTimezone,
    required this.localDate,
    required this.metrics,
  });

  final String teamId;
  final String teamCode;
  final String teamName;
  final String? projectId;
  final String? projectRef;
  final String? projectName;
  final String? supervisorName;
  final String calendarTimezone;
  final String localDate;
  final YorksWorkforceOverviewMetrics metrics;

  factory YorksWorkforceOverviewTeam.fromJson(Map<String, dynamic> json) {
    _exact(json, const {
      'team_id',
      'team_code',
      'team_name',
      'department',
      'project_id',
      'project_ref',
      'project_name',
      'project_state',
      'internal_location_id',
      'internal_location_name',
      'supervisor_auth_user_id',
      'supervisor_name',
      'calendar_id',
      'calendar_name',
      'calendar_timezone',
      'local_date',
      'period_month',
      'schedule_link_id',
      'metrics',
    }, 'team');
    return YorksWorkforceOverviewTeam(
      teamId: _uuid(json['team_id']),
      teamCode: _text(json['team_code']),
      teamName: _text(json['team_name']),
      projectId: _nullableUuid(json['project_id']),
      projectRef: _nullableText(json['project_ref']),
      projectName: _nullableText(json['project_name']),
      supervisorName: _nullableText(json['supervisor_name']),
      calendarTimezone: _text(json['calendar_timezone']),
      localDate: _date(json['local_date']),
      metrics: YorksWorkforceOverviewMetrics.fromJson(_map(json['metrics'])),
    );
  }
}

final class YorksWorkforceOverviewProject {
  const YorksWorkforceOverviewProject({
    required this.projectId,
    required this.projectRef,
    required this.projectName,
    required this.teamCount,
    required this.workerCount,
    required this.missingTodayCount,
    required this.warningCount,
  });

  final String projectId;
  final String projectRef;
  final String projectName;
  final int teamCount;
  final int workerCount;
  final int missingTodayCount;
  final int warningCount;

  factory YorksWorkforceOverviewProject.fromJson(Map<String, dynamic> json) {
    _exact(json, const {
      'project_id',
      'project_ref',
      'project_name',
      'team_count',
      'worker_count',
      'missing_today_count',
      'warning_count',
    }, 'project');
    return YorksWorkforceOverviewProject(
      projectId: _uuid(json['project_id']),
      projectRef: _text(json['project_ref']),
      projectName: _text(json['project_name']),
      teamCount: _integer(json['team_count']),
      workerCount: _integer(json['worker_count']),
      missingTodayCount: _integer(json['missing_today_count']),
      warningCount: _integer(json['warning_count']),
    );
  }
}

final class YorksWorkforceOverviewQueueItem {
  const YorksWorkforceOverviewQueueItem({
    required this.periodId,
    required this.teamName,
    required this.periodMonth,
    required this.status,
    required this.submittedByName,
    required this.workerCount,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.warningCount,
    required this.blockingIssueCount,
    required this.reviewerCorrectionCount,
    required this.missingSupportingEvidenceCount,
    required this.supportingEvidencePolicy,
    required this.highOvertimeExceptionCount,
    required this.overtimeLimitPolicy,
    required this.canReturn,
    required this.canCorrect,
    required this.canVerify,
    required this.canFinalApprove,
  });

  final String periodId;
  final String teamName;
  final String periodMonth;
  final String status;
  final String? submittedByName;
  final int workerCount;
  final int regularMinutes;
  final int overtimeMinutes;
  final int warningCount;
  final int blockingIssueCount;
  final int reviewerCorrectionCount;
  final int missingSupportingEvidenceCount;
  final String supportingEvidencePolicy;
  final int highOvertimeExceptionCount;
  final String overtimeLimitPolicy;
  final bool canReturn;
  final bool canCorrect;
  final bool canVerify;
  final bool canFinalApprove;

  factory YorksWorkforceOverviewQueueItem.fromJson(Map<String, dynamic> json) {
    _exact(json, const {
      'period_id',
      'team_id',
      'team_name',
      'period_month',
      'status',
      'record_version',
      'submitted_by_auth_user_id',
      'submitted_by_name',
      'worker_count',
      'regular_minutes',
      'overtime_minutes',
      'warning_count',
      'blocking_issue_count',
      'reviewer_correction_count',
      'missing_supporting_evidence_count',
      'supporting_evidence_policy',
      'high_overtime_exception_count',
      'overtime_limit_policy',
      'can_return',
      'can_correct',
      'can_verify',
      'can_final_approve',
      'updated_at',
      'exception_priority',
    }, 'review queue item');
    final supportingPolicy = _dashboardPolicy(
      json['supporting_evidence_policy'],
    );
    final overtimePolicy = _dashboardPolicy(json['overtime_limit_policy']);
    final supportingCount = _integer(json['missing_supporting_evidence_count']);
    final overtimeCount = _integer(json['high_overtime_exception_count']);
    if ((supportingPolicy == 'not_configured') != (supportingCount == 0) ||
        (overtimePolicy == 'not_configured') != (overtimeCount == 0) ||
        !_queueStatuses.contains(json['status'])) {
      throw const FormatException('Unsupported dashboard policy');
    }
    return YorksWorkforceOverviewQueueItem(
      periodId: _uuid(json['period_id']),
      teamName: _text(json['team_name']),
      periodMonth: _date(json['period_month']),
      status: _text(json['status']),
      submittedByName: _nullableText(json['submitted_by_name']),
      workerCount: _integer(json['worker_count']),
      regularMinutes: _integer(json['regular_minutes']),
      overtimeMinutes: _integer(json['overtime_minutes']),
      warningCount: _integer(json['warning_count']),
      blockingIssueCount: _integer(json['blocking_issue_count']),
      reviewerCorrectionCount: _integer(json['reviewer_correction_count']),
      missingSupportingEvidenceCount: supportingCount,
      supportingEvidencePolicy: supportingPolicy,
      highOvertimeExceptionCount: overtimeCount,
      overtimeLimitPolicy: overtimePolicy,
      canReturn: _boolean(json['can_return']),
      canCorrect: _boolean(json['can_correct']),
      canVerify: _boolean(json['can_verify']),
      canFinalApprove: _boolean(json['can_final_approve']),
    );
  }
}

final class YorksWorkforceOverviewProjection {
  YorksWorkforceOverviewProjection({
    required this.kind,
    required this.generatedAt,
    required this.asOf,
    required this.summary,
    required this.teams,
    required this.projects,
    required this.reviewQueue,
    required this.actionFlags,
  });

  final YorksWorkforceOverviewKind kind;
  final DateTime generatedAt;
  final List<YorksWorkforceOverviewAsOf> asOf;
  final Map<String, num> summary;
  final List<YorksWorkforceOverviewTeam> teams;
  final List<YorksWorkforceOverviewProject> projects;
  final List<YorksWorkforceOverviewQueueItem> reviewQueue;
  final Map<String, bool> actionFlags;

  factory YorksWorkforceOverviewProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _exact(json, const {
      'schema_version',
      'authorization_mode',
      'source_version',
      'overview_kind',
      'generated_at',
      'as_of_mode',
      'as_of_groups',
      'summary',
      'teams',
      'projects',
      'review_queue',
      'action_flags',
      'policies',
    }, 'overview');
    if (json['schema_version'] != 1 ||
        json['authorization_mode'] != 'enforced_t10' ||
        json['source_version'] != 'workforce_t10_v1' ||
        json['as_of_mode'] != 'calendar_local_by_team') {
      throw const FormatException('Unsupported overview contract');
    }
    final policies = _map(json['policies']);
    _exact(policies, const {
      'overtime_limit',
      'supporting_evidence_requirement',
    }, 'overview policies');
    policies.values.forEach(_dashboardPolicy);
    final kind = YorksWorkforceOverviewKind.fromWire(json['overview_kind']);
    final summaryJson = _map(json['summary']);
    final expectedSummary = switch (kind) {
      YorksWorkforceOverviewKind.supervisor => _supervisorSummaryKeys,
      YorksWorkforceOverviewKind.management => _managementSummaryKeys,
      YorksWorkforceOverviewKind.admin => _adminSummaryKeys,
    };
    _exact(summaryJson, expectedSummary, 'overview summary');
    final summary = <String, num>{};
    for (final entry in summaryJson.entries) {
      if (entry.key.endsWith('_percent')) {
        summary[entry.key] = _percent(entry.value);
      } else {
        summary[entry.key] = _integer(entry.value);
      }
    }
    final actionJson = _map(json['action_flags']);
    final expectedActions = switch (kind) {
      YorksWorkforceOverviewKind.supervisor => const {
        'can_complete_today_attendance',
      },
      YorksWorkforceOverviewKind.management => const {
        'can_open_review_queue',
        'can_open_final_approval_queue',
      },
      YorksWorkforceOverviewKind.admin => const {
        'can_open_reopen_queue',
        'can_open_final_approval_queue',
      },
    };
    _exact(actionJson, expectedActions, 'overview action flags');
    return YorksWorkforceOverviewProjection(
      kind: kind,
      generatedAt: _timestamp(json['generated_at']),
      asOf: _list(json['as_of_groups'])
          .map((value) => YorksWorkforceOverviewAsOf.fromJson(_map(value)))
          .toList(growable: false),
      summary: Map.unmodifiable(summary),
      teams: _list(json['teams'])
          .map((value) => YorksWorkforceOverviewTeam.fromJson(_map(value)))
          .toList(growable: false),
      projects: _list(json['projects'])
          .map((value) => YorksWorkforceOverviewProject.fromJson(_map(value)))
          .toList(growable: false),
      reviewQueue: _list(json['review_queue'])
          .map((value) => YorksWorkforceOverviewQueueItem.fromJson(_map(value)))
          .toList(growable: false),
      actionFlags: Map.unmodifiable(
        actionJson.map((key, value) => MapEntry(key, _boolean(value))),
      ),
    );
  }
}

const _supervisorSummaryKeys = {
  'team_count',
  'worker_count',
  'present_count',
  'absent_count',
  'leave_count',
  'not_entered_count',
  'warning_count',
  'returned_correction_count',
  'today_entered_count',
  'today_completion_percent',
  'month_entered_count',
  'month_required_count',
  'month_completion_percent',
};
const _managementSummaryKeys = {
  ..._supervisorSummaryKeys,
  'active_project_count',
  'review_queue_count',
  'approval_queue_count',
  'returned_count',
  'overtime_exception_count',
};
const _adminSummaryKeys = {
  'active_worker_count',
  'active_supervisor_count',
  'missing_today_count',
  'monthly_pending_count',
  'returned_count',
  'awaiting_final_count',
  'locked_count',
  'reopen_request_count',
  'configuration_issue_count',
};
const _queueStatuses = {
  'submitted',
  'under_review',
  'returned_for_correction',
  'awaiting_final_approval',
};

String _dashboardPolicy(Object? value) {
  if (value == 'not_configured' || value == 'typed_validation_issue') {
    return value as String;
  }
  throw const FormatException('Unsupported dashboard policy');
}

void _exact(Map<String, dynamic> value, Set<String> expected, String label) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw FormatException('Unexpected $label fields');
  }
}

Map<String, dynamic> _map(Object? value) => switch (value) {
  final Map map => Map<String, dynamic>.from(map),
  _ => throw const FormatException('Expected object'),
};
List<dynamic> _list(Object? value) => switch (value) {
  final List list => list,
  _ => throw const FormatException('Expected list'),
};
String _text(Object? value) => value is String && value.trim().isNotEmpty
    ? value.trim()
    : throw const FormatException('Expected text');
String? _nullableText(Object? value) => value == null ? null : _text(value);
int _integer(Object? value) => switch (value) {
  final int number when number >= 0 => number,
  final num number when number >= 0 && number == number.roundToDouble() =>
    number.toInt(),
  _ => throw const FormatException('Expected non-negative integer'),
};
double _percent(Object? value) {
  final number = value is num ? value.toDouble() : double.nan;
  if (!number.isFinite || number < 0 || number > 100) {
    throw const FormatException('Expected percentage');
  }
  return number;
}

bool _boolean(Object? value) =>
    value is bool ? value : throw const FormatException('Expected boolean');
DateTime _timestamp(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null || !parsed.isUtc) {
    throw const FormatException('Expected UTC timestamp');
  }
  return parsed;
}

String _date(Object? value) {
  final text = value is String ? value : '';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      DateTime.tryParse(text) == null) {
    throw const FormatException('Expected ISO date');
  }
  return text;
}

String _uuid(Object? value) => value is String && _isUuid(value)
    ? value
    : throw const FormatException('Expected UUID');
String? _nullableUuid(Object? value) => value == null ? null : _uuid(value);
bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
