import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/application/accounts_records_controller.dart';
import 'package:material_ledger/features/accounts/data/accounts_records_repository.dart';
import 'package:material_ledger/features/accounts/data/accounts_report_service.dart';
import 'package:material_ledger/features/accounts/data/accounts_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_records_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_documents_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T06 protected record projections', () {
    test('activity filters are exact, bounded and UTC normalized', () {
      final filters = YorksAccountsActivityFilters(
        entityType: ' accounts_client_invoice ',
        action: ' submitted ',
        actorAuthUserId: ' actor-1 ',
        from: DateTime.parse('2026-08-25T09:00:00+03:00'),
        to: DateTime.parse('2026-08-26T09:00:00+03:00'),
        limit: 25,
        offset: 50,
      );

      expect(filters.isValid, isTrue);
      expect(filters.toRpcParameters('project-1'), {
        'p_project_id': 'project-1',
        'p_entity_type': 'accounts_client_invoice',
        'p_action': 'submitted',
        'p_actor_auth_user_id': 'actor-1',
        'p_from': '2026-08-25T06:00:00.000Z',
        'p_to': '2026-08-26T06:00:00.000Z',
        'p_limit': 25,
        'p_offset': 50,
      });
      expect(YorksAccountsActivityFilters(limit: 101).isValid, isFalse);
    });

    test('report rows must match the protected server column shape', () {
      expect(
        () => YorksAccountsReportProjection.fromRpcJson({
          ..._reportJson(),
          'rows': [
            ['only-one-cell'],
          ],
        }),
        throwsFormatException,
      );
      final report = YorksAccountsReportProjection.fromRpcJson(_reportJson());
      expect(report.reportKind, 'project_summary');
      expect(report.rows.single, ['YRA-001', '=1+1']);
    });

    test('Accounts document targets reject non-Accounts entity types', () {
      expect(
        () => YorksV1AccountsDocumentTarget.fromRpcJson({
          'entity_type': 'material_request',
          'entity_id': 'record-1',
          'label': 'MR-001',
        }),
        throwsA(isA<YorksV1DomainException>()),
      );
      final target = YorksV1AccountsDocumentTarget.fromRpcJson({
        'entity_type': 'accounts_client_invoice',
        'entity_id': 'invoice-1',
        'label': 'INV-001',
      });
      expect(
        target.entityType,
        YorksV1DocumentEntityType.accountsClientInvoice,
      );
    });
  });

  group('T06 repository and controller authority', () {
    test('activity and export call only their protected RPCs', () async {
      final rpc = _RpcClient((name, parameters) {
        if (name == 'v1_get_accounts_activity') {
          expect(parameters['p_project_id'], 'project-1');
          return _activityJson();
        }
        expect(name, 'v1_get_accounts_export');
        expect(parameters, {
          'p_export_kind': 'project_summary',
          'p_project_id': 'project-1',
          'p_idempotency_key': 'key-1',
        });
        return _reportJson();
      });
      final repository = _recordsRepository(rpc);

      final activity = await repository.getActivity(
        ' project-1 ',
        const YorksAccountsActivityFilters(),
      );
      final report = await repository.getReport(
        YorksAccountsReportKind.projectSummary,
        projectId: ' project-1 ',
        idempotencyKey: 'key-1',
      );

      expect(activity.entries.single.actorDisplayName, 'Accounts User');
      expect(report.projectId, 'project-1');
      expect(rpc.names, ['v1_get_accounts_activity', 'v1_get_accounts_export']);
    });

    test('feature, connectivity and response identity fail closed', () async {
      await expectLater(
        _recordsRepository(
          _RpcClient((_, _) => throw StateError('must not call')),
          accounts: false,
        ).getActivity('project-1', const YorksAccountsActivityFilters()),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      await expectLater(
        _recordsRepository(
          _RpcClient((_, _) => throw StateError('must not call')),
          online: false,
        ).getReport(
          YorksAccountsReportKind.projectSummary,
          projectId: 'project-1',
          idempotencyKey: 'key-1',
        ),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      final mismatch = _activityJson()..['project_id'] = 'project-2';
      await expectLater(
        _recordsRepository(
          _RpcClient((_, _) => mismatch),
        ).getActivity('project-1', const YorksAccountsActivityFilters()),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    });

    test(
      'authorization loss purges cached activity and document data',
      () async {
        final records = _QueuedRecordsRepository([
          YorksAccountsActivityProjection.fromRpcJson(_activityJson()),
          const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
        ]);
        final activity = YorksAccountsActivityController(
          projectId: 'project-1',
          repository: records,
        );
        expect(await activity.load(), isTrue);
        expect(activity.state.projection, isNotNull);
        expect(await activity.load(), isFalse);
        expect(activity.state.projection, isNull);

        final documents = YorksAccountsDocumentsController(
          projectId: 'project-1',
          repository: _DeniedDocumentsRepository(),
        );
        expect(await documents.load(), isFalse);
        expect(documents.state.workspace, isNull);
        expect(documents.state.status.name, 'forbidden');
      },
    );
  });

  group('T06 deterministic report artifacts', () {
    test('XLSX is valid OOXML and neutralizes spreadsheet formulas', () {
      final report = YorksAccountsReportProjection.fromRpcJson(_reportJson());
      final bytes = const YorksAccountsReportService().buildExcel(report);
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet = archive.findFile('xl/worksheets/sheet1.xml');

      expect(bytes.take(2), [0x50, 0x4b]);
      expect(sheet, isNotNull);
      expect(
        String.fromCharCodes(sheet!.content as List<int>),
        contains("'=1+1"),
      );
    });

    test('PDF uses the same protected structured report model', () async {
      final report = YorksAccountsReportProjection.fromRpcJson(_reportJson());
      final bytes = await const YorksAccountsReportService().buildPdf(report);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}

YorksSupabaseAccountsRecordsRepository _recordsRepository(
  YorksAccountsRpcClient rpc, {
  bool accounts = true,
  bool online = true,
}) => YorksSupabaseAccountsRecordsRepository(
  featureFlags: _flags(accounts: accounts),
  connectivity: DefaultConnectivity(online: online),
  rpcClient: rpc,
);

YorksV1FeatureFlags _flags({required bool accounts}) => YorksV1FeatureFlags(
  foundation: true,
  projects: true,
  boq: true,
  excel: true,
  requests: true,
  arrangement: true,
  logistics: true,
  returnsDocuments: true,
  documents: true,
  accounts: accounts,
);

Map<String, dynamic> _activityJson() => {
  'project_id': 'project-1',
  'total': 1,
  'limit': 50,
  'offset': 0,
  'entries': [
    {
      'id': 'audit-1',
      'event_type': 'accounts.client_invoice.submitted',
      'entity_type': 'accounts_client_invoice',
      'entity_id': 'invoice-1',
      'project_id': 'project-1',
      'actor_auth_user_id': 'actor-1',
      'actor_display_name': 'Accounts User',
      'actor_exact_role': 'accountant',
      'occurred_at': '2026-08-26T10:00:00Z',
      'reason': null,
      'idempotency_key': 'key-1',
      'before_data': null,
      'after_data': {'status': 'submitted'},
    },
  ],
};

Map<String, dynamic> _reportJson() => {
  'schema_version': 6,
  'report_kind': 'project_summary',
  'project_id': 'project-1',
  'project_reference': 'YRA-001',
  'project_name': 'Project One',
  'currency': 'AED',
  'access_context': 'accountant',
  'generated_at': '2026-08-26T10:00:00Z',
  'generated_by_auth_user_id': 'actor-1',
  'generated_by_display_name': 'Accounts User',
  'columns': ['Project', 'Value'],
  'rows': [
    ['YRA-001', '=1+1'],
  ],
};

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);

class _RpcClient implements YorksAccountsRpcClient {
  _RpcClient(this.handler);

  final Map<String, dynamic> Function(
    String name,
    Map<String, Object?> parameters,
  )
  handler;
  final names = <String>[];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    names.add(functionName);
    return handler(functionName, parameters);
  }
}

class _QueuedRecordsRepository implements YorksAccountsRecordsRepository {
  _QueuedRecordsRepository(this.values);

  final List<Object> values;

  @override
  Future<YorksAccountsActivityProjection> getActivity(
    String projectId,
    YorksAccountsActivityFilters filters,
  ) async {
    final value = values.removeAt(0);
    if (value is YorksV1DomainException) throw value;
    return value as YorksAccountsActivityProjection;
  }

  @override
  Future<YorksAccountsReportProjection> getReport(
    YorksAccountsReportKind kind, {
    String? projectId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

class _DeniedDocumentsRepository implements YorksV1AccountsDocumentsRepository {
  @override
  Future<Uint8List> downloadDocument({
    required String bucketId,
    required String objectPath,
  }) => throw UnimplementedError();

  @override
  Future<YorksV1AccountsDocumentWorkspace> getAccountsWorkspace(
    String projectId, {
    String? search,
    YorksV1AccountsDocumentType? documentType,
    bool includeArchived = false,
  }) => Future.error(
    const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized),
  );

  @override
  Future<YorksV1AccountsDocumentWorkspace> uploadAccounts(
    YorksV1DocumentUploadInput input,
  ) => throw UnimplementedError();
}
