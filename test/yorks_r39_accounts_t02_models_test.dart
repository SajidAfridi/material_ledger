import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_models.dart';

void main() {
  group('R39 exact decimals', () {
    test('canonicalizes without binary floating point', () {
      expect(YorksAccountsDecimal.parse('8400000.00').canonicalText, '8400000');
      expect(YorksAccountsDecimal.parse('5.2500').canonicalText, '5.25');
      expect(
        YorksAccountsDecimal.parse('33.3333') +
            YorksAccountsDecimal.parse('66.6667'),
        YorksAccountsDecimal.hundred,
      );
    });

    test('rejects JSON numbers and scientific notation', () {
      expect(
        () => YorksAccountsDecimal.fromRpcValue(8.4, key: 'contract_value'),
        throwsFormatException,
      );
      expect(YorksAccountsDecimal.tryParse('8.4e6'), isNull);
    });
  });

  group('R39 role-safe projections', () {
    test('non-commercial baseline omits and never manufactures values', () {
      final projection = YorksAccountsBaselineProjection.fromRpcJson(
        _redactedBaselineJson(),
      );

      expect(projection.capabilities.canViewValues, isFalse);
      expect(projection.baseline!.contractValue, isNull);
      expect(projection.baseline!.currencyCode, isNull);
      expect(projection.physicalBuildings.single.buildingName, 'Main Building');
      expect(projection.stageTemplates.single.stageKey, 'design');
      expect(projection.buildingAllocations.single.allocatedValue, isNull);
      expect(projection.stageAllocations.single.stageValue, isNull);
    });

    test('non-commercial progress keeps percentages and omits money', () {
      final projection = YorksAccountsProgressProjection.fromRpcJson(
        _redactedProgressJson(),
      );

      expect(projection.schemaVersion, 2);
      expect(projection.progress.single.confirmedPercent.canonicalText, '35');
      expect(projection.progress.single.stagePosition, 1);
      expect(projection.progress.single.actionOwner, 'project_engineer');
      expect(projection.progress.single.confirmedEligible, isNull);
      expect(projection.progress.single.stageValue, isNull);
      expect(projection.totals!.contractValue, isNull);
      expect(projection.totals!.confirmedPercent.canonicalText, '35');
    });

    test('compact row revision and full audit projection remain distinct', () {
      final json = _redactedProgressJson();
      ((json['progress'] as List).single
          as Map<String, dynamic>)['revisions'] = [
        <String, dynamic>{
          'revision_number': 2,
          'action': 'confirmed',
          'suggested_percent': '40.0000',
          'confirmed_percent': '35.0000',
          'reason': 'Confirmed against inspection',
          'actor_auth_user_id': 'actor-1',
          'created_at': '2026-08-25T12:00:00Z',
        },
      ];

      final projection = YorksAccountsProgressProjection.fromRpcJson(json);
      final summary = projection.progress.single.revisions.single;
      expect(summary.revisionNumber, 2);
      expect(summary.confirmedPercent.canonicalText, '35');
    });

    test('rejects a protected field leaked into a redacted projection', () {
      final json = _redactedProgressJson();
      (json['progress'] as List).first['stage_value'] = '4200000.00';

      expect(
        () => YorksAccountsProgressProjection.fromRpcJson(json),
        throwsFormatException,
      );
    });

    test('protected projection parses exact string values', () {
      final json = _redactedBaselineJson(canViewValues: true);
      final baseline = json['baseline'] as Map<String, dynamic>;
      baseline.addAll({
        'contract_value': '8400000.00',
        'currency_code': 'AED',
        'vat_rate': '5.0000',
        'payment_terms_days': 20,
        'reminder_lead_days': 10,
        'management_review_policy': <String, Object?>{
          'always_required': false,
          'threshold_amount': null,
          'confirming_exact_roles': <String>[],
        },
      });
      (json['building_allocations'] as List).first['allocated_value'] =
          '8400000.00';
      (json['stage_allocations'] as List).first['stage_value'] = '840000.00';

      final projection = YorksAccountsBaselineProjection.fromRpcJson(json);
      expect(projection.baseline!.contractValue!.canonicalText, '8400000');
      expect(projection.baseline!.vatRate!.canonicalText, '5');
    });
  });

  test('baseline input enforces exact 100 percent and explicit VAT', () {
    final input = _baselineInput();
    expect(input.isValid, isTrue);
    expect(input.vatRate.canonicalText, '5');
    expect(
      (input.idempotencyPayload()['building_allocations'] as List).single,
      containsPair('allocation_percent', '100'),
    );

    final invalid = _baselineInput(
      buildingPercent: YorksAccountsDecimal.parse('99.9999'),
    );
    expect(invalid.isValid, isFalse);
  });

  test('inputs reject zero allocations, zero position and excess scale', () {
    final invalidMoney = _baselineInput(
      contractValue: YorksAccountsDecimal.parse('1.001'),
    );
    expect(invalidMoney.isValid, isFalse);

    final zeroAllocation = _baselineInput(
      buildingPercent: YorksAccountsDecimal.zero,
    );
    expect(zeroAllocation.isValid, isFalse);

    final zeroPosition = _baselineInput(stagePosition: 0);
    expect(zeroPosition.isValid, isFalse);

    final excessivePercentScale = _baselineInput(
      buildingPercent: YorksAccountsDecimal.parse('100.00001'),
    );
    expect(excessivePercentScale.isValid, isFalse);
  });

  test('baseline rejects duplicate stage positions and malformed keys', () {
    final duplicatePositions = _baselineInput(
      stageAllocations: [
        YorksAccountsStageAllocationInput(
          stageKey: 'design',
          stageLabel: 'Design',
          position: 1,
          allocationPercent: YorksAccountsDecimal.parse('50'),
        ),
        YorksAccountsStageAllocationInput(
          stageKey: 'installation',
          stageLabel: 'Installation',
          position: 1,
          allocationPercent: YorksAccountsDecimal.parse('50'),
        ),
      ],
    );
    expect(duplicatePositions.isValid, isFalse);

    final malformedKey = _baselineInput(
      stageAllocations: [
        YorksAccountsStageAllocationInput(
          stageKey: 'Material Supply',
          stageLabel: 'Material Supply',
          position: 1,
          allocationPercent: YorksAccountsDecimal.hundred,
        ),
      ],
    );
    expect(malformedKey.isValid, isFalse);
  });

  test('every progress/review audit action requires a reason', () {
    final progress = YorksAccountsProgressInput(
      projectId: 'project-1',
      progressEntryId: 'progress-1',
      expectedVersion: 1,
      percent: YorksAccountsDecimal.parse('25'),
      evidenceSummary: 'Inspection',
      evidenceDocumentIds: const [],
      reason: '   ',
    );
    expect(progress.isValid, isFalse);

    const review = YorksAccountsReviewInput(
      projectId: 'project-1',
      progressEntryId: 'progress-1',
      expectedVersion: 1,
      decision: YorksAccountsReviewDecision.approved,
      reason: '',
    );
    expect(review.isValid, isFalse);
  });

  test('suggestion and confirmation evidence validation stay distinct', () {
    final input = YorksAccountsProgressInput(
      projectId: 'project-1',
      progressEntryId: 'progress-1',
      expectedVersion: 1,
      percent: YorksAccountsDecimal.parse('20'),
      evidenceSummary: '',
      evidenceDocumentIds: const [],
      reason: 'Confirm a defensible decrease',
    );

    expect(input.isValidSuggestion, isFalse);
    expect(input.isValidConfirmation, isTrue);
    expect(input.isValid, isFalse);
  });

  test('management review policy is typed and exact-decimal safe', () {
    final valid = YorksAccountsManagementReviewPolicy(
      alwaysRequired: false,
      thresholdAmount: YorksAccountsDecimal.parse('100000.00'),
      confirmingExactRoles: const ['project_manager'],
    );
    expect(valid.isValid, isTrue);
    expect(valid.toRpcJson()['threshold_amount'], '100000');

    final invalid = YorksAccountsManagementReviewPolicy(
      alwaysRequired: true,
      thresholdAmount: YorksAccountsDecimal.parse('1.001'),
      confirmingExactRoles: const ['admin'],
    );
    expect(invalid.isValid, isFalse);

    expect(
      () => YorksAccountsManagementReviewPolicy.fromRpcJson({
        'always_required': false,
        'threshold_amount': 100000.0,
        'confirming_exact_roles': <String>[],
        'unexpected': true,
      }),
      throwsFormatException,
    );
  });
}

YorksAccountsBaselineInput _baselineInput({
  YorksAccountsDecimal? buildingPercent,
  YorksAccountsDecimal? contractValue,
  int stagePosition = 1,
  List<YorksAccountsStageAllocationInput>? stageAllocations,
}) {
  return YorksAccountsBaselineInput(
    projectId: 'project-1',
    contractValue: contractValue ?? YorksAccountsDecimal.parse('8400000.00'),
    currencyCode: 'AED',
    vatRate: YorksAccountsDecimal.parse('5.0000'),
    paymentTermsDays: 20,
    reminderLeadDays: 10,
    buildingAllocations: [
      YorksAccountsBuildingAllocationInput(
        buildingScopeId: 'building-1',
        allocationPercent: buildingPercent ?? YorksAccountsDecimal.hundred,
        isCommonScope: false,
      ),
    ],
    stageAllocations:
        stageAllocations ??
        [
          YorksAccountsStageAllocationInput(
            stageKey: 'design',
            stageLabel: 'Design',
            position: stagePosition,
            allocationPercent: YorksAccountsDecimal.hundred,
          ),
        ],
    managementReviewPolicy: YorksAccountsManagementReviewPolicy(
      alwaysRequired: false,
      thresholdAmount: null,
      confirmingExactRoles: const [],
    ),
    reason: 'Initial approved contract baseline',
  );
}

Map<String, dynamic> _redactedBaselineJson({bool canViewValues = false}) => {
  'schema_version': 2,
  'project_id': 'project-1',
  'baseline': <String, dynamic>{
    'revision_id': 'revision-1',
    'revision_number': 1,
    'record_version': 1,
    'status': 'current',
    'reason': 'Initial baseline',
  },
  'physical_buildings': [
    <String, dynamic>{
      'building_scope_id': 'building-1',
      'building_name': 'Main Building',
      'scope_code': 'BLD-01',
    },
  ],
  'stage_templates': [
    <String, dynamic>{
      'stage_key': 'design',
      'stage_label': 'Design',
      'position': 1,
      'allocation_percent': '10.0000',
    },
  ],
  'building_allocations': [
    <String, dynamic>{
      'allocation_id': 'building-allocation-1',
      'building_scope_id': 'building-1',
      'building_name': 'Main Building',
      'allocation_percent': '100.0000',
    },
  ],
  'stage_allocations': [
    <String, dynamic>{
      'allocation_id': 'stage-allocation-1',
      'stage_key': 'design',
      'stage_label': 'Design',
      'position': 1,
      'allocation_percent': '10.0000',
    },
  ],
  'capabilities': _capabilities(canViewValues: canViewValues),
  'commands': {'suggest': true},
};

Map<String, dynamic> _redactedProgressJson() => {
  'schema_version': 2,
  'project_id': 'project-1',
  'baseline_revision_id': 'revision-1',
  'baseline_revision_number': 1,
  'progress': [
    {
      'progress_entry_id': 'progress-1',
      'project_id': 'project-1',
      'baseline_revision_id': 'revision-1',
      'building_scope_id': 'building-1',
      'building_name': 'Main Building',
      'stage_key': 'design',
      'stage_label': 'Design',
      'stage_position': 1,
      'record_version': 2,
      'suggested_percent': '40.0000',
      'confirmed_percent': '35.0000',
      'review_status': 'not_required',
      'evidence_summary': 'Inspection report',
      'evidence_document_ids': ['document-1'],
      'action_owner': 'project_engineer',
      'revisions': <Object?>[],
      'next_actions': <Object?>[],
      'updated_at': '2026-08-25T12:00:00Z',
    },
  ],
  'totals': {'confirmed_percent': '35.0000'},
  'capabilities': _capabilities(canViewValues: false),
  'commands': {'suggest': true},
  'next_actions': <Object?>[],
};

Map<String, dynamic> _capabilities({required bool canViewValues}) => {
  'can_view': true,
  'can_view_values': canViewValues,
  'can_configure': false,
  'can_suggest': true,
  'can_confirm': false,
  'can_review': false,
};
