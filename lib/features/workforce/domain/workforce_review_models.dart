import 'workforce_monthly_period_models.dart';

const yorksWorkforceReviewQueueMaxPageSize = 100;

final class YorksWorkforceReviewActions {
  const YorksWorkforceReviewActions({
    required this.canSubmit,
    required this.canReturn,
    required this.canCorrect,
    required this.canVerify,
    required this.canFinalApprove,
    required this.canRequestReopen,
    required this.canAuthorizeReopen,
  });

  final bool canSubmit;
  final bool canReturn;
  final bool canCorrect;
  final bool canVerify;
  final bool canFinalApprove;
  final bool canRequestReopen;
  final bool canAuthorizeReopen;
}

final class YorksWorkforceReviewTransition {
  const YorksWorkforceReviewTransition({
    required this.id,
    required this.action,
    required this.fromStatus,
    required this.toStatus,
    required this.actorAuthUserId,
    required this.actorExactRole,
    required this.reason,
    required this.occurredAt,
  });

  final String id;
  final String action;
  final YorksWorkforceMonthlyPeriodStatus fromStatus;
  final YorksWorkforceMonthlyPeriodStatus toStatus;
  final String actorAuthUserId;
  final String actorExactRole;
  final String reason;
  final String occurredAt;

  factory YorksWorkforceReviewTransition.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _exact(json, const {
      'transition_id',
      'action_kind',
      'from_status',
      'to_status',
      'actor_auth_user_id',
      'actor_exact_role',
      'reason',
      'occurred_at',
    }, 'review transition');
    return YorksWorkforceReviewTransition(
      id: _uuid(json['transition_id']),
      action: _text(json['action_kind']),
      fromStatus: YorksWorkforceMonthlyPeriodStatus.fromWire(
        json['from_status'],
      ),
      toStatus: YorksWorkforceMonthlyPeriodStatus.fromWire(json['to_status']),
      actorAuthUserId: _uuid(json['actor_auth_user_id']),
      actorExactRole: _text(json['actor_exact_role']),
      reason: _string(json['reason']),
      occurredAt: _timestamp(json['occurred_at']),
    );
  }
}

final class YorksWorkforceApprovedSnapshot {
  const YorksWorkforceApprovedSnapshot({
    required this.id,
    required this.revisionNumber,
    required this.hash,
    required this.approvedByAuthUserId,
    required this.approvedAt,
    required this.lockedAt,
  });

  final String id;
  final int revisionNumber;
  final String hash;
  final String approvedByAuthUserId;
  final String approvedAt;
  final String lockedAt;

  factory YorksWorkforceApprovedSnapshot.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _exact(json, const {
      'snapshot_id',
      'revision_number',
      'snapshot_hash',
      'approved_by_auth_user_id',
      'approved_at',
      'locked_at',
    }, 'approved snapshot');
    return YorksWorkforceApprovedSnapshot(
      id: _uuid(json['snapshot_id']),
      revisionNumber: _positiveInt(json['revision_number']),
      hash: _fingerprint(json['snapshot_hash']),
      approvedByAuthUserId: _uuid(json['approved_by_auth_user_id']),
      approvedAt: _timestamp(json['approved_at']),
      lockedAt: _timestamp(json['locked_at']),
    );
  }
}

final class YorksWorkforceReopenRequest {
  YorksWorkforceReopenRequest({
    required this.id,
    required this.reason,
    required Iterable<YorksWorkforceAffectedEntry> affectedEntries,
    required this.requestedByAuthUserId,
    required this.requestedAt,
    required this.authorizedByAuthUserId,
    required this.authorizedAt,
    required this.newRevisionNumber,
  }) : affectedEntries = List.unmodifiable(affectedEntries);

  final String id;
  final String reason;
  final List<YorksWorkforceAffectedEntry> affectedEntries;
  final String requestedByAuthUserId;
  final String requestedAt;
  final String? authorizedByAuthUserId;
  final String? authorizedAt;
  final int? newRevisionNumber;

  bool get isPending => authorizedAt == null;

  factory YorksWorkforceReopenRequest.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'request_id',
      'reason',
      'affected_entries',
      'requested_by_auth_user_id',
      'requested_at',
      'authorized_by_auth_user_id',
      'authorized_at',
      'new_revision_number',
    }, 'reopen request');
    final authorizedBy = _nullableUuid(json['authorized_by_auth_user_id']);
    final authorizedAt = _nullableTimestamp(json['authorized_at']);
    final revision = _nullablePositiveInt(json['new_revision_number']);
    if ((authorizedBy == null) != (authorizedAt == null) ||
        (authorizedAt == null) != (revision == null)) {
      throw const FormatException('Invalid reopen authorization tuple');
    }
    return YorksWorkforceReopenRequest(
      id: _uuid(json['request_id']),
      reason: _text(json['reason']),
      affectedEntries: _list(
        json['affected_entries'],
      ).map((value) => YorksWorkforceAffectedEntry.fromRpcJson(_map(value))),
      requestedByAuthUserId: _uuid(json['requested_by_auth_user_id']),
      requestedAt: _timestamp(json['requested_at']),
      authorizedByAuthUserId: authorizedBy,
      authorizedAt: authorizedAt,
      newRevisionNumber: revision,
    );
  }
}

final class YorksWorkforceReviewerCorrection {
  const YorksWorkforceReviewerCorrection({
    required this.id,
    required this.workerId,
    required this.workDate,
    required this.beforeValue,
    required this.afterValue,
    required this.reason,
    required this.correctedByAuthUserId,
    required this.correctedAt,
  });

  final String id;
  final String workerId;
  final String workDate;
  final Map<String, dynamic> beforeValue;
  final Map<String, dynamic> afterValue;
  final String reason;
  final String correctedByAuthUserId;
  final String correctedAt;

  factory YorksWorkforceReviewerCorrection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _exact(json, const {
      'correction_id',
      'worker_id',
      'work_date',
      'before_value',
      'after_value',
      'reason',
      'corrected_by_auth_user_id',
      'corrected_at',
    }, 'reviewer correction');
    return YorksWorkforceReviewerCorrection(
      id: _uuid(json['correction_id']),
      workerId: _uuid(json['worker_id']),
      workDate: _date(json['work_date']),
      beforeValue: _map(json['before_value']),
      afterValue: _map(json['after_value']),
      reason: _text(json['reason']),
      correctedByAuthUserId: _uuid(json['corrected_by_auth_user_id']),
      correctedAt: _timestamp(json['corrected_at']),
    );
  }
}

final class YorksWorkforceReviewLifecycle {
  YorksWorkforceReviewLifecycle({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.periodId,
    required this.teamId,
    required this.periodMonth,
    required this.status,
    required this.recordVersion,
    required this.approvalRevisionNumber,
    required this.validationRunId,
    required this.validationNumber,
    required this.sourceFingerprint,
    required this.currentSourceFingerprint,
    required this.isStale,
    required this.blockingIssueCount,
    required this.warningIssueCount,
    required this.submitterAuthUserId,
    required this.actions,
    required Iterable<YorksWorkforceReviewTransition> transitions,
    required Iterable<YorksWorkforceReviewerCorrection> corrections,
    required Iterable<YorksWorkforceApprovedSnapshot> approvedSnapshots,
    required Iterable<YorksWorkforceReopenRequest> reopenRequests,
  }) : transitions = List.unmodifiable(transitions),
       corrections = List.unmodifiable(corrections),
       approvedSnapshots = List.unmodifiable(approvedSnapshots),
       reopenRequests = List.unmodifiable(reopenRequests) {
    if (schemaVersion != 1 || authorizationMode != 'enforced_t07') {
      throw const FormatException('Unsupported Workforce T07 lifecycle');
    }
    if (isStale &&
        (actions.canSubmit || actions.canVerify || actions.canFinalApprove)) {
      throw const FormatException('Stale lifecycle exposes a critical action');
    }
    if (blockingIssueCount > 0 && actions.canSubmit) {
      throw const FormatException('Blocked lifecycle exposes submit');
    }
    if (status == YorksWorkforceMonthlyPeriodStatus.locked &&
        approvedSnapshots.isEmpty) {
      throw const FormatException('Locked lifecycle lacks a snapshot');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final String periodId;
  final String teamId;
  final String periodMonth;
  final YorksWorkforceMonthlyPeriodStatus status;
  final int recordVersion;
  final int approvalRevisionNumber;
  final String validationRunId;
  final int validationNumber;
  final String sourceFingerprint;
  final String currentSourceFingerprint;
  final bool isStale;
  final int blockingIssueCount;
  final int warningIssueCount;
  final String? submitterAuthUserId;
  final YorksWorkforceReviewActions actions;
  final List<YorksWorkforceReviewTransition> transitions;
  final List<YorksWorkforceReviewerCorrection> corrections;
  final List<YorksWorkforceApprovedSnapshot> approvedSnapshots;
  final List<YorksWorkforceReopenRequest> reopenRequests;

  factory YorksWorkforceReviewLifecycle.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'schema_version',
      'authorization_mode',
      'period_id',
      'team_id',
      'period_month',
      'status',
      'record_version',
      'approval_revision_number',
      'validation_run_id',
      'validation_number',
      'source_fingerprint',
      'current_source_fingerprint',
      'is_stale',
      'blocking_issue_count',
      'warning_issue_count',
      'submitter_auth_user_id',
      'can_submit',
      'can_return',
      'can_correct',
      'can_verify',
      'can_final_approve',
      'can_request_reopen',
      'can_authorize_reopen',
      'transitions',
      'corrections',
      'approved_snapshots',
      'reopen_requests',
    }, 'review lifecycle');
    return YorksWorkforceReviewLifecycle(
      schemaVersion: _positiveInt(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      periodId: _uuid(json['period_id']),
      teamId: _uuid(json['team_id']),
      periodMonth: _firstOfMonth(json['period_month']),
      status: YorksWorkforceMonthlyPeriodStatus.fromWire(json['status']),
      recordVersion: _positiveInt(json['record_version']),
      approvalRevisionNumber: _nonNegativeInt(json['approval_revision_number']),
      validationRunId: _uuid(json['validation_run_id']),
      validationNumber: _positiveInt(json['validation_number']),
      sourceFingerprint: _fingerprint(json['source_fingerprint']),
      currentSourceFingerprint: _fingerprint(
        json['current_source_fingerprint'],
      ),
      isStale: _bool(json['is_stale']),
      blockingIssueCount: _nonNegativeInt(json['blocking_issue_count']),
      warningIssueCount: _nonNegativeInt(json['warning_issue_count']),
      submitterAuthUserId: _nullableUuid(json['submitter_auth_user_id']),
      actions: YorksWorkforceReviewActions(
        canSubmit: _bool(json['can_submit']),
        canReturn: _bool(json['can_return']),
        canCorrect: _bool(json['can_correct']),
        canVerify: _bool(json['can_verify']),
        canFinalApprove: _bool(json['can_final_approve']),
        canRequestReopen: _bool(json['can_request_reopen']),
        canAuthorizeReopen: _bool(json['can_authorize_reopen']),
      ),
      transitions: _list(
        json['transitions'],
      ).map((value) => YorksWorkforceReviewTransition.fromRpcJson(_map(value))),
      corrections: _list(json['corrections']).map(
        (value) => YorksWorkforceReviewerCorrection.fromRpcJson(_map(value)),
      ),
      approvedSnapshots: _list(
        json['approved_snapshots'],
      ).map((value) => YorksWorkforceApprovedSnapshot.fromRpcJson(_map(value))),
      reopenRequests: _list(
        json['reopen_requests'],
      ).map((value) => YorksWorkforceReopenRequest.fromRpcJson(_map(value))),
    );
  }
}

final class YorksWorkforceReviewQueueItem {
  const YorksWorkforceReviewQueueItem({
    required this.periodId,
    required this.teamName,
    required this.periodMonth,
    required this.status,
    required this.updatedAt,
    required this.lifecycle,
  });

  final String periodId;
  final String teamName;
  final String periodMonth;
  final YorksWorkforceMonthlyPeriodStatus status;
  final String updatedAt;
  final YorksWorkforceReviewLifecycle lifecycle;

  factory YorksWorkforceReviewQueueItem.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'period_id',
      'team_name',
      'period_month',
      'status',
      'updated_at',
      'lifecycle',
    }, 'review queue item');
    final lifecycle = YorksWorkforceReviewLifecycle.fromRpcJson(
      _map(json['lifecycle']),
    );
    final id = _uuid(json['period_id']);
    if (lifecycle.periodId != id) {
      throw const FormatException('Queue lifecycle context mismatch');
    }
    return YorksWorkforceReviewQueueItem(
      periodId: id,
      teamName: _text(json['team_name']),
      periodMonth: _firstOfMonth(json['period_month']),
      status: YorksWorkforceMonthlyPeriodStatus.fromWire(json['status']),
      updatedAt: _timestamp(json['updated_at']),
      lifecycle: lifecycle,
    );
  }
}

final class YorksWorkforceReviewQueue {
  YorksWorkforceReviewQueue({
    required this.schemaVersion,
    required this.authorizationMode,
    required this.statusFilter,
    required this.limit,
    required this.offset,
    required this.totalCount,
    required Iterable<YorksWorkforceReviewQueueItem> items,
  }) : items = List.unmodifiable(items) {
    if (schemaVersion != 1 ||
        authorizationMode != 'enforced_t07' ||
        limit < 1 ||
        limit > yorksWorkforceReviewQueueMaxPageSize ||
        offset < 0 ||
        totalCount < this.items.length ||
        this.items.length > limit ||
        (offset < totalCount && this.items.isEmpty)) {
      throw const FormatException('Invalid Workforce review queue');
    }
  }

  final int schemaVersion;
  final String authorizationMode;
  final YorksWorkforceMonthlyPeriodStatus? statusFilter;
  final int limit;
  final int offset;
  final int totalCount;
  final List<YorksWorkforceReviewQueueItem> items;

  factory YorksWorkforceReviewQueue.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {
      'schema_version',
      'authorization_mode',
      'status_filter',
      'limit',
      'offset',
      'total_count',
      'items',
    }, 'review queue');
    return YorksWorkforceReviewQueue(
      schemaVersion: _positiveInt(json['schema_version']),
      authorizationMode: _text(json['authorization_mode']),
      statusFilter: json['status_filter'] == null
          ? null
          : YorksWorkforceMonthlyPeriodStatus.fromWire(json['status_filter']),
      limit: _positiveInt(json['limit']),
      offset: _nonNegativeInt(json['offset']),
      totalCount: _nonNegativeInt(json['total_count']),
      items: _list(
        json['items'],
      ).map((value) => YorksWorkforceReviewQueueItem.fromRpcJson(_map(value))),
    );
  }
}

final class YorksWorkforceAffectedEntry {
  const YorksWorkforceAffectedEntry({
    required this.workerId,
    required this.workDate,
  });

  final String workerId;
  final String workDate;

  bool get isValid => _isUuid(workerId.trim()) && _isDate(workDate.trim());
  Map<String, Object?> toRpcJson() => {
    'worker_id': workerId.trim(),
    'work_date': workDate.trim(),
  };

  factory YorksWorkforceAffectedEntry.fromRpcJson(Map<String, dynamic> json) {
    _exact(json, const {'worker_id', 'work_date'}, 'affected entry');
    return YorksWorkforceAffectedEntry(
      workerId: _uuid(json['worker_id']),
      workDate: _date(json['work_date']),
    );
  }
}

void _exact(Map<String, dynamic> json, Set<String> keys, String context) {
  if (json.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(json.keys.toSet()).isNotEmpty) {
    throw FormatException('Unexpected $context shape');
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : throw const FormatException('Expected object');
List<dynamic> _list(Object? value) => value is List
    ? List<dynamic>.from(value)
    : throw const FormatException('Expected list');
String _string(Object? value) =>
    value is String ? value : throw const FormatException('Expected string');
String _text(Object? value) {
  final result = _string(value).trim();
  if (result.isEmpty) throw const FormatException('Expected text');
  return result;
}

bool _bool(Object? value) =>
    value is bool ? value : throw const FormatException('Expected boolean');
int _nonNegativeInt(Object? value) => value is int && value >= 0
    ? value
    : throw const FormatException('Expected non-negative integer');
int _positiveInt(Object? value) => value is int && value > 0
    ? value
    : throw const FormatException('Expected positive integer');
int? _nullablePositiveInt(Object? value) =>
    value == null ? null : _positiveInt(value);
String _uuid(Object? value) {
  final result = _string(value);
  if (!_isUuid(result)) throw const FormatException('Expected UUID');
  return result;
}

String? _nullableUuid(Object? value) => value == null ? null : _uuid(value);
String _date(Object? value) {
  final result = _string(value);
  if (!_isDate(result)) throw const FormatException('Expected ISO date');
  return result;
}

String _firstOfMonth(Object? value) {
  final result = _date(value);
  if (!result.endsWith('-01')) {
    throw const FormatException('Expected first of month');
  }
  return result;
}

String _timestamp(Object? value) {
  final result = _string(value);
  if (DateTime.tryParse(result) == null) {
    throw const FormatException('Expected timestamp');
  }
  return result;
}

String? _nullableTimestamp(Object? value) =>
    value == null ? null : _timestamp(value);
String _fingerprint(Object? value) {
  final result = _string(value);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(result)) {
    throw const FormatException('Expected fingerprint');
  }
  return result;
}

bool _isDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  return DateTime.tryParse(value) != null;
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
