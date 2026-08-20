import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_document.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_documents_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  const enabledFlags = YorksV1FeatureFlags(
    foundation: true,
    projects: true,
    boq: true,
    excel: true,
    requests: true,
    arrangement: true,
    logistics: true,
    returnsDocuments: true,
    documents: true,
    inventorySuppliers: true,
  );

  test('supplier workspace uses its dedicated protected projection', () async {
    final rpc = _SupplierDocumentRpc();
    final repository = YorksV1SupabaseDocumentsRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    final workspace = await repository.getSupplierWorkspace('supplier-1');

    expect(
      rpc.calls.single.functionName,
      'v1_supplier_document_workspace_projection',
    );
    expect(rpc.calls.single.parameters, {'p_supplier_id': 'supplier-1'});
    expect(workspace.projectId, 'supplier-1');
    expect(workspace.documents.single.currentVersion.fileName, 'dn-41.pdf');
    expect(
      workspace.documents.single.currentVersion.supplierDocumentType,
      YorksV1SupplierDocumentType.deliveryNote,
    );
    expect(
      workspace.documents.single.currentVersion.businessReference,
      'DN-41',
    );
    expect(
      workspace.documents.single.currentVersion.supplierDocumentNotes,
      'Signed at the warehouse',
    );
    expect(
      workspace.documents.single.links.single.entityType,
      YorksV1DocumentEntityType.supplier,
    );
  });

  test(
    'supplier upload keeps supplier identity in the trusted prepare RPC',
    () async {
      final rpc = _SupplierDocumentRpc(finalizedIntent: true);
      final repository = YorksV1SupabaseDocumentsRepository(
        featureFlags: enabledFlags,
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
        storageClient: _NoopStorage(),
        finalizerClient: _NoopFinalizer(),
      );

      final workspace = await repository.uploadSupplier(
        YorksV1DocumentUploadInput(
          projectId: 'supplier-1',
          entityType: YorksV1DocumentEntityType.supplier,
          entityId: 'supplier-1',
          classification: YorksV1DocumentClassification.operational,
          fileName: 'dn-41.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
          idempotencyKey: 'supplier-upload-1',
          supplierDocumentType: YorksV1SupplierDocumentType.deliveryNote,
          businessReference: '  DN-41  ',
          supplierDocumentNotes: '  Signed at the warehouse  ',
        ),
      );

      expect(workspace.projectId, 'supplier-1');
      expect(rpc.calls.map((call) => call.functionName), [
        'v1_prepare_supplier_document_upload',
        'v1_supplier_document_workspace_projection',
      ]);
      final prepare = rpc.calls.first;
      final payload = prepare.parameters['p_payload'] as Map<String, Object?>;
      expect(payload['project_id'], 'supplier-1');
      expect(payload['entity_type'], 'supplier');
      expect(payload['entity_id'], 'supplier-1');
      expect(payload['classification'], 'operational');
      expect(payload['supplier_document_type'], 'delivery_note');
      expect(payload['business_reference'], 'DN-41');
      expect(payload['supplier_document_notes'], 'Signed at the warehouse');
    },
  );

  test('generic payload never emits supplier business metadata keys', () {
    final input = YorksV1DocumentUploadInput(
      projectId: 'project-1',
      entityType: YorksV1DocumentEntityType.project,
      entityId: 'project-1',
      classification: YorksV1DocumentClassification.operational,
      fileName: 'project.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList(const [1]),
      idempotencyKey: 'generic-upload-1',
      supplierDocumentType: YorksV1SupplierDocumentType.other,
      businessReference: 'SHOULD-NOT-LEAK',
      supplierDocumentNotes: 'Supplier-only metadata',
    );

    final payload = input.toRpcPayload(List.filled(64, 'a').join());

    expect(payload, isNot(contains('supplier_document_type')));
    expect(payload, isNot(contains('business_reference')));
    expect(payload, isNot(contains('supplier_document_notes')));
  });

  test('supplier upload rejects missing controlled document type locally', () {
    final rpc = _SupplierDocumentRpc(finalizedIntent: true);
    final repository = YorksV1SupabaseDocumentsRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
      storageClient: _NoopStorage(),
      finalizerClient: _NoopFinalizer(),
    );

    expect(
      () => repository.uploadSupplier(
        YorksV1DocumentUploadInput(
          projectId: 'supplier-1',
          entityType: YorksV1DocumentEntityType.supplier,
          entityId: 'supplier-1',
          classification: YorksV1DocumentClassification.operational,
          fileName: 'untyped.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1]),
          idempotencyKey: 'supplier-upload-untyped',
        ),
      ),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.invalidInput,
        ),
      ),
    );
    expect(rpc.calls, isEmpty);
  });

  test('delivery note requires a bounded business reference locally', () {
    final rpc = _SupplierDocumentRpc(finalizedIntent: true);
    final repository = YorksV1SupabaseDocumentsRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
      storageClient: _NoopStorage(),
      finalizerClient: _NoopFinalizer(),
    );

    expect(
      () => repository.uploadSupplier(
        YorksV1DocumentUploadInput(
          projectId: 'supplier-1',
          entityType: YorksV1DocumentEntityType.supplier,
          entityId: 'supplier-1',
          classification: YorksV1DocumentClassification.operational,
          fileName: 'dn.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1]),
          idempotencyKey: 'supplier-upload-no-reference',
          supplierDocumentType: YorksV1SupplierDocumentType.deliveryNote,
          businessReference: '   ',
        ),
      ),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.invalidInput,
        ),
      ),
    );
    expect(rpc.calls, isEmpty);
  });

  test('supplier invoice must use commercial classification locally', () {
    final rpc = _SupplierDocumentRpc(finalizedIntent: true);
    final repository = YorksV1SupabaseDocumentsRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
      storageClient: _NoopStorage(),
      finalizerClient: _NoopFinalizer(),
    );

    expect(
      () => repository.uploadSupplier(
        YorksV1DocumentUploadInput(
          projectId: 'supplier-1',
          entityType: YorksV1DocumentEntityType.supplier,
          entityId: 'supplier-1',
          classification: YorksV1DocumentClassification.operational,
          fileName: 'invoice.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1]),
          idempotencyKey: 'supplier-upload-invoice-operational',
          supplierDocumentType: YorksV1SupplierDocumentType.invoice,
          businessReference: 'INV-41',
        ),
      ),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.invalidInput,
        ),
      ),
    );
    expect(rpc.calls, isEmpty);
  });

  test('invalid controlled type in a projection fails closed', () async {
    final response = Map<String, Object?>.from(_workspaceResponse);
    final documents = List<Object?>.from(response['documents']! as List);
    final document = Map<String, Object?>.from(documents.single! as Map);
    final version = Map<String, Object?>.from(
      document['current_version']! as Map,
    );
    version['supplier_document_type'] = 'forged_type';
    document['current_version'] = version;
    documents[0] = document;
    response['documents'] = documents;
    final repository = YorksV1SupabaseDocumentsRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: _SupplierDocumentRpc(workspaceResponse: response),
    );

    await expectLater(
      repository.getSupplierWorkspace('supplier-1'),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.unexpectedResponse,
        ),
      ),
    );
  });

  test('supplier document boundary follows the R38.9 rollout flag', () async {
    final rpc = _SupplierDocumentRpc();
    final repository = YorksV1SupabaseDocumentsRepository(
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
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    await expectLater(
      repository.getSupplierWorkspace('supplier-1'),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.featureDisabled,
        ),
      ),
    );
    expect(rpc.calls, isEmpty);
  });
}

typedef _RpcCall = ({String functionName, Map<String, Object?> parameters});

class _SupplierDocumentRpc implements YorksV1MaterialRequestRpcClient {
  _SupplierDocumentRpc({
    this.finalizedIntent = false,
    this.workspaceResponse = _workspaceResponse,
  });

  final bool finalizedIntent;
  final Map<String, Object?> workspaceResponse;
  final calls = <_RpcCall>[];

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add((functionName: functionName, parameters: parameters));
    if (functionName == 'v1_prepare_supplier_document_upload') {
      return {
        'upload_intent_id': 'intent-1',
        'bucket_id': 'v1-controlled-documents',
        'object_path': 'supplier/supplier-1/dn-41.pdf',
        'mime_type': 'application/pdf',
        'byte_size': 3,
        'expires_at': '2026-08-20T09:30:00Z',
        'planned_revision_number': 1,
        if (finalizedIntent) 'finalized_document_id': 'document-1',
        if (finalizedIntent) 'finalized_version_id': 'version-1',
      };
    }
    return workspaceResponse;
  }
}

class _NoopStorage implements YorksV1DocumentStorageClient {
  @override
  Future<Uint8List> download({
    required String bucketId,
    required String objectPath,
  }) async => Uint8List(0);

  @override
  Future<void> upload({
    required String bucketId,
    required String objectPath,
    required Uint8List bytes,
    required String mimeType,
  }) async {}
}

class _NoopFinalizer implements YorksV1DocumentFinalizerClient {
  @override
  Future<Object?> finalize(String uploadIntentId) async => null;
}

const _workspaceResponse = <String, Object?>{
  'project_id': 'supplier-1',
  'documents': [
    {
      'id': 'document-1',
      'classification': 'operational',
      'created_at': '2026-08-20T08:00:00Z',
      'current_version': {
        'id': 'version-1',
        'revision_number': 1,
        'bucket_id': 'v1-controlled-documents',
        'object_path': 'supplier/supplier-1/dn-41.pdf',
        'original_file_name': 'dn-41.pdf',
        'mime_type': 'application/pdf',
        'byte_size': 3,
        'sha256':
            '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
        'origin': 'uploaded',
        'uploaded_at': '2026-08-20T08:00:00Z',
        'uploaded_by_auth_user_id': 'actor-1',
        'uploaded_by_role': 'procurement',
        'uploaded_by_display_name': 'Procurement User',
        'supplier_document_type': 'delivery_note',
        'business_reference': 'DN-41',
        'supplier_document_notes': 'Signed at the warehouse',
      },
      'links': [
        {
          'id': 'link-1',
          'project_id': 'supplier-1',
          'entity_type': 'supplier',
          'entity_id': 'supplier-1',
          'linked_at': '2026-08-20T08:00:00Z',
          'cross_project_reason': null,
        },
      ],
    },
  ],
  'audit_entries': <Object?>[],
};
