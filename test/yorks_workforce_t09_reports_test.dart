import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_report_controller.dart';
import 'package:material_ledger/features/workforce/data/workforce_report_service.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_report_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _artifactId = '90000000-0000-4000-8000-000000000001';
const _snapshotId = '90000000-0000-4000-8000-000000000002';
const _teamId = '90000000-0000-4000-8000-000000000003';
const _key = '90000000-0000-4000-8000-000000000004';
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('T09 strict report and history envelopes reject drift', () {
    final artifact = YorksWorkforceReportArtifact.fromRpcJson(_artifactJson());
    expect(artifact.isApproved, isTrue);
    expect(artifact.rows.single['projects'], '=SUM(1,1)');
    expect(artifact.totals.manDays, 1.125);

    expect(
      () => YorksWorkforceReportArtifact.fromRpcJson({
        ..._artifactJson(),
        'salary': 100,
      }),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceReportArtifact.fromRpcJson({
        ..._artifactJson(),
        'source_status': 'approved_locked',
        'source_kind': 'current_daily',
      }),
      throwsFormatException,
    );
    final malformedSource = _artifactJson();
    malformedSource['sources'] = [
      {...(malformedSource['sources']! as List).single, 'approved_by': null},
    ];
    expect(
      () => YorksWorkforceReportArtifact.fromRpcJson(malformedSource),
      throwsFormatException,
    );
    final wrongColumns = _artifactJson();
    final columns = List<Map<String, Object?>>.from(
      wrongColumns['columns']! as List,
    );
    columns[0] = {...columns[0], 'key': 'worker_number'};
    wrongColumns['columns'] = columns;
    expect(
      () => YorksWorkforceReportArtifact.fromRpcJson(wrongColumns),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceReportHistory.fromRpcJson({
        ..._historyJson(),
        'total_count': 0,
      }),
      throwsFormatException,
    );
  });

  test('request validation denies incomplete and forged report scopes', () {
    expect(
      () => YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.supervisorTeamMonthly,
      ).toRpcJson(),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.dailyAttendanceRegister,
        workDate: '2026-08-01',
        teamId: 'forged',
      ).toRpcJson(),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.supervisorTeamMonthly,
        snapshotIds: const [_snapshotId],
      ).toRpcJson(),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.exceptionMissingAttendance,
        periodMonth: '2026-08-01',
        projectId: _teamId,
      ).toRpcJson(),
      throwsFormatException,
    );
    expect(
      YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.supervisorTeamMonthly,
        snapshotIds: const [_snapshotId],
        teamId: _teamId,
      ).toRpcJson()['snapshot_ids'],
      [_snapshotId],
    );
    expect(
      () => const YorksWorkforceReportIssueRequest(
        artifactId: _artifactId,
        format: YorksWorkforceReportFormat.xlsx,
        action: YorksWorkforceReportAction.preview,
      ).toRpcJson(),
      throwsFormatException,
    );
    expect(
      YorksWorkforceReportIssueReceipt.fromRpcJson(
        _issueReceiptJson(
          YorksWorkforceReportFormat.pdf,
          YorksWorkforceReportAction.preview,
        ),
      ).reportPayloadHash,
      _hash,
    );
  });

  test(
    'repository fails closed for flag, offline, backend and malformed RPC',
    () async {
      final rpc = _RpcClient((_, _) => const {});
      final request = YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.supervisorTeamMonthly,
        snapshotIds: const [_snapshotId],
        teamId: _teamId,
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).generateReport(request, idempotencyKey: _key),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).generateReport(request, idempotencyKey: _key),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
        ).generateReport(request, idempotencyKey: _key),
        throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).generateReport(request, idempotencyKey: _key),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test('repository maps only the dedicated T09 RPC contracts', () async {
    final rpc = _RpcClient(
      (name, parameters) => switch (name) {
        'v1_generate_workforce_report' => _artifactJson(),
        'v1_list_workforce_report_artifacts' => _historyJson(),
        'v1_issue_workforce_report_export' => _issueReceiptJson(
          YorksWorkforceReportFormat.pdf,
          YorksWorkforceReportAction.preview,
        ),
        _ => const {},
      },
    );
    final repository = YorksSupabaseWorkforceRepository(
      featureFlags: _workforceFlags,
      connectivity: const _Connectivity(true),
      rpcClient: rpc,
    );
    final artifact = await repository.generateReport(
      YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.supervisorTeamMonthly,
        snapshotIds: const [_snapshotId],
        teamId: _teamId,
      ),
      idempotencyKey: _key,
    );
    final history = await repository.listReportArtifacts(limit: 25);
    final receipt = await repository.issueReportExport(
      const YorksWorkforceReportIssueRequest(
        artifactId: _artifactId,
        format: YorksWorkforceReportFormat.pdf,
        action: YorksWorkforceReportAction.preview,
      ),
      idempotencyKey: _key,
    );
    expect(artifact.artifactId, _artifactId);
    expect(history.items.single.artifactId, _artifactId);
    expect(receipt.action, YorksWorkforceReportAction.preview);
    expect(rpc.calls, [
      'v1_generate_workforce_report',
      'v1_list_workforce_report_artifacts',
      'v1_issue_workforce_report_export',
    ]);
  });

  test(
    'XLSX uses typed cells, frozen panes, filters and formula hardening',
    () {
      final report = YorksWorkforceReportArtifact.fromRpcJson(_artifactJson());
      final bytes = const YorksWorkforceReportService().buildExcel(report);
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet = String.fromCharCodes(
        archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      final styles = String.fromCharCodes(
        archive.findFile('xl/styles.xml')!.content as List<int>,
      );
      final sourceSheet = String.fromCharCodes(
        archive.findFile('xl/worksheets/sheet2.xml')!.content as List<int>,
      );
      expect(bytes.take(2), [0x50, 0x4b]);
      expect(sheet, contains('xSplit="2" ySplit="1"'));
      expect(sheet, contains('<autoFilter ref="A1:J2"'));
      expect(sheet, contains("'=SUM(1,1)"));
      expect(sheet, isNot(contains('<f>')));
      expect(sheet, contains('s="3"><v>'));
      expect(sheet, contains('s="4"><v>1</v>'));
      expect(sheet, contains('s="5"><v>8</v>'));
      expect(styles, contains('formatCode="yyyy-mm-dd"'));
      expect(styles, contains('formatCode="0.####"'));
      expect(
        sourceSheet,
        contains('Yorks Air Conditioning &amp; Refrigeration LLC-SPC'),
      );
      expect(sourceSheet, contains('Site Engineer (site_engineer)'));
      expect(sourceSheet, contains('Local Admin (admin)'));
    },
  );

  test('PDF renders short and multi-page protected RTL artifacts', () async {
    final service = const YorksWorkforceReportService();
    final artifact = YorksWorkforceReportArtifact.fromRpcJson(_artifactJson());
    final format = YorksWorkforceReportService.pageFormatFor(artifact);
    expect(format.width, greaterThan(format.height));
    final projectFormat = YorksWorkforceReportService.pageFormatFor(
      YorksWorkforceReportArtifact.fromRpcJson(_projectArtifactJson()),
    );
    final companyFormat = YorksWorkforceReportService.pageFormatFor(
      YorksWorkforceReportArtifact.fromRpcJson(_companyArtifactJson()),
    );
    expect(projectFormat.width, greaterThan(projectFormat.height));
    expect(companyFormat.width, greaterThan(companyFormat.height));
    expect(
      YorksWorkforceReportService.approvedHeaderLines(artifact),
      containsAll([
        'Yorks Air Conditioning & Refrigeration LLC-SPC',
        'يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و',
        'MONTHLY TIMESHEET',
        'August 2026',
      ]),
    );
    final footer = YorksWorkforceReportService.approvalFooterEvidence(artifact);
    expect(footer.map((item) => item.$1), [
      'Prepared By',
      'Reviewed By',
      'Approved By',
      'Approval Dates',
      'Revision',
    ]);
    expect(footer.last.$2, 'R1');
    final bytes = await service.buildPdf(artifact);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final multiPageJson = _artifactJson();
    multiPageJson['rows'] = List.generate(
      160,
      (index) => {
        'team': index == 0 ? '=SUM(1,1)' : 'Team ${index + 1}',
        'period_month': '2026-08-01',
        'workers_managed': 1,
        'attendance_summary': 'Present 1',
        'regular_hours': 8,
        'overtime_hours': 1,
        'absences': 0,
        'projects': 'WF-T09',
        'exceptions': 'None',
        'review_approval_status': 'Approved & locked · R1',
      },
    );
    multiPageJson['totals'] = const {
      'row_count': 160,
      'regular_minutes': 76800,
      'overtime_minutes': 0,
      'man_days': 160,
    };
    final multiPageBytes = await service.buildPdf(
      YorksWorkforceReportArtifact.fromRpcJson(multiPageJson),
    );
    final pdfText = latin1.decode(multiPageBytes, allowInvalid: true);
    expect(multiPageBytes.length, greaterThan(bytes.length));
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(pdfText).length,
      greaterThan(1),
    );
  });

  test(
    'controller preserves uncertain key and reuses identical cached bytes',
    () async {
      final connectivity = _Connectivity(true);
      final repository = _ReportRepository(
        failures: [
          const YorksV1DomainException(
            YorksV1DomainErrorCode.backendUnavailable,
          ),
          const YorksV1DomainException(
            YorksV1DomainErrorCode.backendUnavailable,
          ),
        ],
      );
      final binary = _BinaryService();
      final preferences = await SharedPreferences.getInstance();
      final controller = YorksWorkforceReportController(
        repository: repository,
        binaryService: binary,
        commandKeys: YorksV1CriticalCommandKeyStore(
          preferences: preferences,
          actorAuthUserId: _teamId,
          uuidFactory: () => _key,
        ),
        connectivity: connectivity,
      );
      addTearDown(controller.dispose);
      final request = YorksWorkforceReportRequest(
        kind: YorksWorkforceReportKind.supervisorTeamMonthly,
        snapshotIds: const [_snapshotId],
        teamId: _teamId,
      );
      expect(await controller.generate(request), isFalse);
      expect(await controller.generate(request), isFalse);
      expect(repository.keys, [_key, _key]);
      expect(controller.state.status, YorksWorkforceReportStatus.uncertain);

      repository.failures.clear();
      expect(await controller.generate(request), isTrue);
      final excel = controller.state.excelBytes;
      final pdf = controller.state.pdfBytes;
      expect(await controller.saveExcel(), isTrue);
      expect(await controller.savePdf(), isTrue);
      expect(await controller.previewPdf(), isTrue);
      expect(await controller.printPdf(), isTrue);
      expect(await controller.sharePdf(), isTrue);
      expect(identical(binary.savedExcel, excel), isTrue);
      expect(identical(binary.savedPdf, pdf), isTrue);
      expect(identical(binary.printedPdf, pdf), isTrue);
      expect(identical(binary.sharedPdf, pdf), isTrue);
      expect(repository.issues.map((issue) => issue.action), [
        YorksWorkforceReportAction.download,
        YorksWorkforceReportAction.download,
        YorksWorkforceReportAction.preview,
        YorksWorkforceReportAction.print,
        YorksWorkforceReportAction.share,
      ]);
    },
  );

  test(
    'controller purges artifact, history and binary bytes on authority loss',
    () async {
      final controller = YorksWorkforceReportController(
        repository: _ReportRepository(),
        binaryService: _BinaryService(),
        commandKeys: YorksV1CriticalCommandKeyStore(
          preferences: await SharedPreferences.getInstance(),
          actorAuthUserId: _teamId,
          uuidFactory: () => _key,
        ),
        connectivity: const _Connectivity(true),
      );
      addTearDown(controller.dispose);
      expect(await controller.loadHistory(), isTrue);
      expect(controller.state.history, isNotNull);
      expect(
        await controller.generate(
          YorksWorkforceReportRequest(
            kind: YorksWorkforceReportKind.supervisorTeamMonthly,
            snapshotIds: const [_snapshotId],
            teamId: _teamId,
          ),
        ),
        isTrue,
      );
      controller.purgeProtectedState();
      expect(controller.state.artifact, isNull);
      expect(controller.state.history, isNull);
      expect(controller.state.excelBytes, isNull);
      expect(controller.state.pdfBytes, isNull);
      expect(controller.state.status, YorksWorkforceReportStatus.forbidden);
    },
  );
}

Map<String, dynamic> _artifactJson() => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t09',
  'artifact_id': _artifactId,
  'report_kind': 'supervisor_team_monthly',
  'source_kind': 'approved_snapshot',
  'source_status': 'approved_locked',
  'source_version': _snapshotId,
  'source_hash': _hash,
  'period_month': '2026-08-01',
  'work_date': null,
  'scope_kind': 'team',
  'scope_reference': _teamId,
  'generated_at': '2026-08-31T00:00:00Z',
  'generated_by': 'Local Admin',
  'generated_by_role': 'admin',
  'company_legal_name': 'Yorks Air Conditioning & Refrigeration LLC-SPC',
  'company_secondary_name': 'يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و',
  'sources': [
    {
      'snapshot_id': _snapshotId,
      'period_id': '59980000-0000-4000-8000-000000000001',
      'snapshot_hash': _hash,
      'approval_revision_number': 1,
      'approved_at': '2026-08-30T23:59:00Z',
      'approved_by': 'Local Admin',
      'approved_role': 'admin',
      'review_chain': const [
        {
          'action': 'submit_for_review',
          'actor': 'Site Engineer',
          'role': 'site_engineer',
          'at': '2026-08-29T10:00:00Z',
        },
      ],
    },
  ],
  'columns': const [
    {'key': 'team', 'label': 'Team', 'type': 'text'},
    {'key': 'period_month', 'label': 'Period', 'type': 'date'},
    {'key': 'workers_managed', 'label': 'Workers Managed', 'type': 'integer'},
    {
      'key': 'attendance_summary',
      'label': 'Attendance Summary',
      'type': 'text',
    },
    {'key': 'regular_hours', 'label': 'Regular Hours', 'type': 'decimal'},
    {'key': 'overtime_hours', 'label': 'OT Hours', 'type': 'decimal'},
    {'key': 'absences', 'label': 'Absences', 'type': 'integer'},
    {'key': 'projects', 'label': 'Projects', 'type': 'text'},
    {'key': 'exceptions', 'label': 'Exceptions', 'type': 'text'},
    {
      'key': 'review_approval_status',
      'label': 'Review / Approval Status',
      'type': 'text',
    },
  ],
  'rows': const [
    {
      'team': 'T09 Reports Team',
      'period_month': '2026-08-01',
      'workers_managed': 1,
      'attendance_summary': 'Present 1',
      'regular_hours': 8,
      'overtime_hours': 1,
      'absences': 0,
      'projects': '=SUM(1,1)',
      'exceptions': 'None',
      'review_approval_status': 'Approved & locked · R1',
    },
  ],
  'totals': const {
    'row_count': 1,
    'regular_minutes': 480,
    'overtime_minutes': 60,
    'man_days': 1.125,
  },
};

Map<String, dynamic> _historyJson() => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t09',
  'limit': 25,
  'offset': 0,
  'total_count': 1,
  'items': [_artifactJson()],
};

Map<String, dynamic> _projectArtifactJson() => {
  ..._artifactJson(),
  'report_kind': 'project_workforce',
  'scope_kind': 'project',
  'scope_reference': '90000000-0000-4000-8000-000000000005',
  'columns': const [
    {'key': 'project', 'label': 'Project', 'type': 'text'},
    {'key': 'buildings', 'label': 'Buildings / Common', 'type': 'text'},
    {'key': 'worker_count', 'label': 'Worker Count', 'type': 'integer'},
    {
      'key': 'trade_distribution',
      'label': 'Trade Distribution',
      'type': 'text',
    },
    {'key': 'man_hours', 'label': 'Man-hours', 'type': 'decimal'},
    {'key': 'man_days', 'label': 'Man-days', 'type': 'decimal'},
    {'key': 'regular_hours', 'label': 'Regular Hours', 'type': 'decimal'},
    {'key': 'overtime_hours', 'label': 'OT Hours', 'type': 'decimal'},
    {'key': 'absences', 'label': 'Absences', 'type': 'integer'},
    {'key': 'supervisors', 'label': 'Supervisors', 'type': 'text'},
    {
      'key': 'outstanding_periods',
      'label': 'Outstanding Periods',
      'type': 'integer',
    },
  ],
  'rows': const [
    {
      'project': 'WF-T09 · T09 Export Project',
      'buildings': 'Common / All Buildings',
      'worker_count': 1,
      'trade_distribution': 'HVAC Technician: 1',
      'man_hours': 9,
      'man_days': 1.125,
      'regular_hours': 8,
      'overtime_hours': 1,
      'absences': 0,
      'supervisors': 'Local Admin',
      'outstanding_periods': 0,
    },
  ],
};

Map<String, dynamic> _companyArtifactJson() => {
  ..._artifactJson(),
  'report_kind': 'company_workforce_summary',
  'scope_kind': 'organization',
  'scope_reference': 'organization',
  'columns': const [
    {'key': 'period_month', 'label': 'Period', 'type': 'date'},
    {
      'key': 'total_active_workforce',
      'label': 'Total Active Workforce',
      'type': 'integer',
    },
    {
      'key': 'attendance_completion',
      'label': 'Attendance Completion %',
      'type': 'decimal',
    },
    {
      'key': 'approved_regular_hours',
      'label': 'Approved Regular Hours',
      'type': 'decimal',
    },
    {
      'key': 'approved_overtime_hours',
      'label': 'Approved OT Hours',
      'type': 'decimal',
    },
    {'key': 'absence_position', 'label': 'Absence Position', 'type': 'integer'},
    {
      'key': 'project_allocation',
      'label': 'Project Allocation',
      'type': 'text',
    },
    {
      'key': 'pending_submissions',
      'label': 'Pending Submissions',
      'type': 'integer',
    },
    {
      'key': 'pending_approvals',
      'label': 'Pending Approvals',
      'type': 'integer',
    },
    {'key': 'reopened_periods', 'label': 'Reopened Periods', 'type': 'integer'},
  ],
  'rows': const [
    {
      'period_month': '2026-08-01',
      'total_active_workforce': 1,
      'attendance_completion': 100,
      'approved_regular_hours': 8,
      'approved_overtime_hours': 1,
      'absence_position': 0,
      'project_allocation': 'WF-T09 · T09 Export Project',
      'pending_submissions': 0,
      'pending_approvals': 0,
      'reopened_periods': 0,
    },
  ],
};

Map<String, dynamic> _issueReceiptJson(
  YorksWorkforceReportFormat format,
  YorksWorkforceReportAction action,
) => {
  'schema_version': 1,
  'authorization_mode': 'enforced_t09',
  'artifact_id': _artifactId,
  'format': format.name,
  'action': action.name,
  'source_hash': _hash,
  'report_payload_hash': _hash,
  'issued_at': '2026-08-31T00:05:00Z',
  'issued_by': _teamId,
  'issued_by_role': 'admin',
  'capability_key': 'workforce.reports.export',
  'scope_kind': 'team',
  'scope_reference': _teamId,
  'source_authority_hash': _hash,
};

final class _RpcClient implements YorksWorkforceRpcClient {
  _RpcClient(this.handler);
  final Map<String, dynamic> Function(
    String name,
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

final class _ReportRepository implements YorksWorkforceReportRepository {
  _ReportRepository({List<YorksV1DomainException>? failures})
    : failures = failures ?? [];
  final List<YorksV1DomainException> failures;
  final List<String> keys = [];
  final List<YorksWorkforceReportIssueRequest> issues = [];

  @override
  Future<YorksWorkforceReportArtifact> generateReport(
    YorksWorkforceReportRequest request, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return YorksWorkforceReportArtifact.fromRpcJson(_artifactJson());
  }

  @override
  Future<YorksWorkforceReportHistory> listReportArtifacts({
    int limit = 25,
    int offset = 0,
  }) async => YorksWorkforceReportHistory.fromRpcJson(_historyJson());

  @override
  Future<YorksWorkforceReportIssueReceipt> issueReportExport(
    YorksWorkforceReportIssueRequest request, {
    required String idempotencyKey,
  }) async {
    issues.add(request);
    return YorksWorkforceReportIssueReceipt.fromRpcJson(
      _issueReceiptJson(request.format, request.action),
    );
  }
}

final class _BinaryService implements YorksWorkforceReportBinaryService {
  final excel = Uint8List.fromList([1, 2, 3]);
  final pdf = Uint8List.fromList([4, 5, 6]);
  Uint8List? savedExcel;
  Uint8List? savedPdf;
  Uint8List? printedPdf;
  Uint8List? sharedPdf;

  @override
  Uint8List buildExcel(YorksWorkforceReportArtifact report) => excel;

  @override
  Future<Uint8List> buildPdf(YorksWorkforceReportArtifact report) async => pdf;

  @override
  Future<void> printPdfBytes(Uint8List bytes) async => printedPdf = bytes;

  @override
  Future<void> saveExcelBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  ) async => savedExcel = bytes;

  @override
  Future<void> savePdfBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  ) async => savedPdf = bytes;

  @override
  Future<void> sharePdfBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  ) async => sharedPdf = bytes;
}

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);
  @override
  final bool isOnline;
  @override
  Stream<bool> get onChange => const Stream.empty();
}

const _workforceFlags = YorksV1FeatureFlags(
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
);

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);
