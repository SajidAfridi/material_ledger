import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/controllers/yorks_v1_procurement_progress_controller.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_procurement_progress.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_procurement_progress_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_procurement_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const scope = YorksV1ProcurementProgressScope(
  requestId: 'request',
  editorKind: YorksV1ProcurementEditorKind.arrangement,
  arrangementId: 'arrangement',
);
YorksV1ProcurementProgressDraft draft({
  String qty = '1.',
  String note = '',
  String? cost,
  int version = 3,
}) => YorksV1ProcurementProgressDraft(
  requestId: scope.requestId,
  editorKind: scope.editorKind,
  arrangementId: scope.arrangementId,
  baseRequestVersion: version,
  baseArrangementVersion: 2,
  inputs: {
    'note': note,
    'lines': [
      {
        'arrangement_line_id': 'line-1',
        'arranged_qty': qty,
        'inventory_item_id': null,
        'reason': '',
        'external_ready': false,
      },
    ],
  },
  commercialInputs: cost == null
      ? null
      : {
          'lines': [
            {'arrangement_line_id': 'line-1', 'unit_cost': cost},
          ],
        },
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<YorksV1ProcurementRecoveryStore> store({
    String actor = 'actor',
    String backend = 'staging',
  }) async => YorksV1ProcurementRecoveryStore(
    preferences: await SharedPreferences.getInstance(),
    actorAuthUserId: actor,
    backendIdentity: backend,
  );
  Future<YorksV1ProcurementProgressController> controller(
    FakeRepository repository,
  ) async => YorksV1ProcurementProgressController(
    repository: repository,
    recoveryStore: await store(),
    scope: scope,
    debounce: const Duration(days: 1),
    uuidFactory: () => 'checkpoint-key',
  );

  test(
    'device recovery preserves raw input and never serializes costs',
    () async {
      final recoveryStore = await store();
      await recoveryStore.save(
        draft: draft(qty: ' 1.', cost: '98765.43'),
        accountRevision: 2,
        generation: 4,
      );
      final result = await recoveryStore.load(scope);
      expect(
        result.recovery!.draft.inputs['lines'],
        contains(containsPair('arranged_qty', ' 1.')),
      );
      expect(result.recovery!.draft.commercialInputs, isNull);
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(recoveryStore.storageKey(scope))!;
      expect(raw, isNot(contains('unit_cost')));
      expect(raw, isNot(contains('98765.43')));
      expect(raw, isNot(contains('commercial_inputs')));
    },
  );

  test(
    'recovery is isolated by backend actor request and arrangement',
    () async {
      final first = await store();
      await first.save(draft: draft(), accountRevision: 0, generation: 1);
      expect(
        (await (await store(actor: 'other')).load(scope)).recovery,
        isNull,
      );
      expect(
        (await (await store(backend: 'production')).load(scope)).recovery,
        isNull,
      );
      expect(
        (await first.load(
          const YorksV1ProcurementProgressScope(
            requestId: 'request',
            editorKind: YorksV1ProcurementEditorKind.arrangement,
            arrangementId: 'another',
          ),
        )).recovery,
        isNull,
      );
    },
  );

  test(
    'corrupt recovery remains intact and cannot be overwritten silently',
    () async {
      final recoveryStore = await store();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(recoveryStore.storageKey(scope), '{broken');
      expect((await recoveryStore.load(scope)).isCorrupt, isTrue);
      await expectLater(
        recoveryStore.save(draft: draft(), accountRevision: 0, generation: 1),
        throwsFormatException,
      );
      expect(preferences.getString(recoveryStore.storageKey(scope)), '{broken');
      await recoveryStore.clear(scope);
      await recoveryStore.save(
        draft: draft(),
        accountRevision: 0,
        generation: 1,
      );
      expect((await recoveryStore.load(scope)).isCorrupt, isFalse);
    },
  );

  test('future fields are not silently discarded from recovery', () async {
    final recoveryStore = await store();
    await recoveryStore.save(draft: draft(), accountRevision: 0, generation: 1);
    final preferences = await SharedPreferences.getInstance();
    final json =
        jsonDecode(preferences.getString(recoveryStore.storageKey(scope))!)
            as Map;
    (json['draft'] as Map)['future_field'] = 'preserve';
    final raw = jsonEncode(json);
    await preferences.setString(recoveryStore.storageKey(scope), raw);
    expect((await recoveryStore.load(scope)).isCorrupt, isTrue);
    expect(preferences.getString(recoveryStore.storageKey(scope)), raw);
  });

  test(
    'operational allowlist rejects commercial and arbitrary nested fields',
    () {
      expect(
        () => YorksV1ProcurementProgressDraft(
          requestId: 'request',
          editorKind: scope.editorKind,
          baseRequestVersion: 1,
          inputs: {
            'lines': [
              {'arrangement_line_id': 'line', 'unit_cost': '4'},
            ],
          },
        ),
        throwsFormatException,
      );
      expect(
        () => YorksV1ProcurementProgressDraft(
          requestId: 'request',
          editorKind: scope.editorKind,
          baseRequestVersion: 1,
          inputs: {
            'lines': [
              {
                'arrangement_line_id': 'line',
                'reason': {'price': '4'},
              },
            ],
          },
        ),
        throwsFormatException,
      );
    },
  );

  test('snapshots freeze nested maps and preserve line ordering', () {
    final lines = <Object?>[
      {'arrangement_line_id': 'b', 'arranged_qty': '2'},
      {'arrangement_line_id': 'a', 'arranged_qty': '1'},
    ];
    final current = YorksV1ProcurementProgressDraft(
      requestId: 'request',
      editorKind: scope.editorKind,
      baseRequestVersion: 1,
      inputs: {'lines': lines},
    );
    lines.clear();
    expect(current.inputs['lines'], hasLength(2));
    expect(
      (current.inputs['lines'] as List).first,
      containsPair('arrangement_line_id', 'b'),
    );
    expect(
      () => (current.inputs['lines'] as List).clear(),
      throwsUnsupportedError,
    );
  });

  test('serialized writes finish in newest generation order', () async {
    final recoveryStore = await store();
    await Future.wait([
      recoveryStore.save(
        draft: draft(qty: '1'),
        accountRevision: 0,
        generation: 1,
      ),
      recoveryStore.save(
        draft: draft(qty: '2'),
        accountRevision: 0,
        generation: 2,
      ),
      recoveryStore.save(
        draft: draft(qty: '3'),
        accountRevision: 0,
        generation: 3,
      ),
    ]);
    expect((await recoveryStore.load(scope)).recovery!.generation, 3);
    expect(
      (await recoveryStore.load(scope)).recovery!.draft.inputs['lines'],
      contains(containsPair('arranged_qty', '3')),
    );
  });

  test(
    'account saves incomplete raw values with commercial fields protected remotely',
    () async {
      final repository = FakeRepository();
      final editor = await controller(repository);
      addTearDown(editor.dispose);
      await editor.initialize(draft());
      editor.update(draft(qty: '-', cost: '12.'));
      expect(await editor.saveProgress(), isTrue);
      expect(repository.saved!.commercialInputs, isNotNull);
      expect(editor.state.isDirty, isFalse);
      expect(editor.state.checkpoint!.revision, 1);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(preferences.getKeys().single),
        isNot(contains('unit_cost')),
      );
    },
  );

  test(
    'late save acknowledges its snapshot without marking newer edits saved',
    () async {
      final repository = FakeRepository()..saveWait = Completer<void>();
      final editor = await controller(repository);
      addTearDown(editor.dispose);
      await editor.initialize(draft());
      editor.update(draft(qty: '2'));
      final saving = editor.saveProgress();
      editor.update(draft(qty: '3'));
      repository.saveWait!.complete();
      expect(await saving, isTrue);
      expect(editor.state.isDirty, isTrue);
      expect(
        editor.state.current!.inputs['lines'],
        contains(containsPair('arranged_qty', '3')),
      );
      expect(
        editor.state.accepted!.inputs['lines'],
        contains(containsPair('arranged_qty', '2')),
      );
    },
  );

  test(
    'newer device copy requires choice and discard restores accepted boundary',
    () async {
      final recoveryStore = await store();
      await recoveryStore.save(
        draft: draft(qty: '9'),
        accountRevision: 1,
        generation: 7,
      );
      final repository = FakeRepository()
        ..read = YorksV1ProcurementProgressRead(
          checkpoint: YorksV1ProcurementProgressCheckpoint(
            draft: draft(qty: '2', cost: '50'),
            revision: 1,
            savedAt: DateTime.utc(2026),
          ),
          revision: 1,
        );
      final editor = await controller(repository);
      addTearDown(editor.dispose);
      await editor.initialize(draft());
      expect(editor.state.needsRecoveryChoice, isTrue);
      editor.acceptDeviceRecovery();
      expect(
        editor.state.current!.inputs['lines'],
        contains(containsPair('arranged_qty', '9')),
      );
      expect(
        editor.state.current!.commercialInputs,
        draft(cost: '50').commercialInputs,
      );
      expect(editor.state.isDirty, isTrue);
      await editor.discardChanges();
      expect(
        editor.state.current!.inputs['lines'],
        contains(containsPair('arranged_qty', '2')),
      );
    },
  );

  test('stale checkpoint cannot become an implicit new edit base', () async {
    final repository = FakeRepository()
      ..read = YorksV1ProcurementProgressRead(
        checkpoint: YorksV1ProcurementProgressCheckpoint(
          draft: draft(version: 2),
          revision: 5,
          savedAt: DateTime.utc(2026),
        ),
        revision: 5,
      );
    final editor = await controller(repository);
    addTearDown(editor.dispose);
    await editor.initialize(draft(version: 3));
    expect(editor.state.hasVersionConflict, isTrue);
    expect(await editor.saveProgress(), isFalse);
    editor.useAccountProgress();
    expect(editor.state.hasVersionConflict, isTrue);
    expect(editor.state.current!.baseRequestVersion, 3);
    expect(await editor.discardSavedProgress(), isTrue);
    await editor.reload(draft(version: 4));
    expect(editor.state.current!.baseRequestVersion, 4);
  });

  test(
    'retired checkpoint revision fences stale tabs instead of resetting to zero',
    () async {
      final repository = FakeRepository()
        ..read = const YorksV1ProcurementProgressRead(
          revision: 7,
          discarded: true,
        );
      final editor = await controller(repository);
      addTearDown(editor.dispose);
      await editor.initialize(draft());
      editor.update(draft(qty: '2'));
      expect(await editor.saveProgress(), isTrue);
      expect(repository.expectedRevision, 7);
    },
  );

  test('failed account save retains dirty values and retry key', () async {
    final repository = FakeRepository()
      ..saveError = const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    final editor = await controller(repository);
    addTearDown(editor.dispose);
    await editor.initialize(draft());
    editor.update(draft(qty: '2'));
    expect(await editor.saveProgress(), isFalse);
    expect(editor.state.isDirty, isTrue);
    repository.saveError = null;
    expect(await editor.saveProgress(), isTrue);
    expect(repository.saveKeys, ['checkpoint-key', 'checkpoint-key']);
  });

  test(
    'prepared final freezes edits and unknown outcome never unlocks',
    () async {
      final repository = FakeRepository();
      final editor = await controller(repository);
      addTearDown(editor.dispose);
      await editor.initialize(draft());
      await editor.prepareFinalIntent(
        commandName: 'v1_save_arrangement',
        commandKey: 'final-key',
        commandPayload: {'unit_cost': '5500'},
      );
      editor.update(draft(qty: '8'));
      expect(editor.state.isPending, isTrue);
      expect(
        editor.state.current!.inputs['lines'],
        contains(containsPair('arranged_qty', '1.')),
      );
      await editor.checkCommandStatus();
      expect(editor.state.isPending, isTrue);
      await editor.rejectFinalIntent(
        const YorksV1DomainException(YorksV1DomainErrorCode.backendUnavailable),
      );
      expect(editor.state.isPending, isTrue);
      expect(await editor.resumeEditingAfterCheck(), isTrue);
      expect(editor.state.isPending, isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(preferences.getKeys().single),
        isNot(contains('5500')),
      );
    },
  );

  test(
    'revoke clears protected memory and waits for queued recovery cleanup',
    () async {
      final repository = FakeRepository();
      final editor = await controller(repository);
      addTearDown(editor.dispose);
      await editor.initialize(draft(cost: '98'));
      editor.update(draft(cost: '99'));
      await editor.flushRecovery();
      await editor.revoke();
      expect(editor.state.current, isNull);
      expect(editor.state.accepted, isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
}

class FakeRepository implements YorksV1ProcurementProgressRepository {
  YorksV1ProcurementProgressRead read = const YorksV1ProcurementProgressRead();
  YorksV1ProcurementProgressDraft? saved;
  int? expectedRevision;
  final saveKeys = <String>[];
  Completer<void>? saveWait;
  Object? saveError;
  @override
  Future<YorksV1ProcurementProgressRead> get(
    YorksV1ProcurementProgressScope scope,
  ) async => read;
  @override
  Future<YorksV1ProcurementProgressCheckpoint> save({
    required YorksV1ProcurementProgressDraft draft,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    saved = draft;
    this.expectedRevision = expectedRevision;
    saveKeys.add(idempotencyKey);
    await saveWait?.future;
    if (saveError != null) throw saveError!;
    final checkpoint = YorksV1ProcurementProgressCheckpoint(
      draft: draft,
      revision: expectedRevision + 1,
      savedAt: DateTime.utc(2026),
    );
    read = YorksV1ProcurementProgressRead(
      checkpoint: checkpoint,
      revision: checkpoint.revision,
    );
    return checkpoint;
  }

  @override
  Future<int> discard({
    required YorksV1ProcurementProgressScope scope,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    read = YorksV1ProcurementProgressRead(
      revision: expectedRevision + 1,
      discarded: true,
    );
    return expectedRevision + 1;
  }

  @override
  Future<YorksV1ProcurementPendingCommand> prepare({
    required YorksV1ProcurementProgressScope scope,
    required int checkpointRevision,
    required String commandName,
    required String commandKey,
    required Map<String, Object?> commandPayload,
    required String idempotencyKey,
  }) async => YorksV1ProcurementPendingCommand(
    attemptId: 'attempt',
    commandName: commandName,
    commandKey: commandKey,
  );
  @override
  Future<YorksV1ProcurementCommandOutcome> outcome({
    required String requestId,
    required String commandName,
    required String commandKey,
  }) async => const YorksV1ProcurementCommandOutcome(status: 'not_found');
  @override
  Future<String> abandon({
    required String requestId,
    required String commandName,
    required String commandKey,
  }) async => 'abandoned';
}
