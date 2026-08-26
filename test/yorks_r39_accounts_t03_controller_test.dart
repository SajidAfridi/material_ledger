import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/application/accounts_controller.dart';
import 'package:material_ledger/features/accounts/application/accounts_providers.dart';
import 'package:material_ledger/features/accounts/application/accounts_receivables_controller.dart';
import 'package:material_ledger/features/accounts/application/accounts_receivables_providers.dart';
import 'package:material_ledger/features/accounts/data/accounts_receivables_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('access denial purges the entire protected T03 projection', () async {
    final repository = _Repository();
    final controller = await _controller(repository);
    expect(await controller.loadClaims(), isTrue);
    expect(controller.state.hasCommercialValues, isTrue);

    repository.readError = const YorksV1DomainException(
      YorksV1DomainErrorCode.unauthorized,
    );
    expect(await controller.loadClaims(), isFalse);

    expect(controller.state.status, YorksAccountsViewStatus.forbidden);
    expect(controller.state.hasCommercialValues, isFalse);
    expect(controller.state.claims, isNull);
    expect(controller.state.invoices, isNull);
    expect(controller.state.ledger, isNull);
  });

  test('project controller rejects cross-project command intent', () async {
    final repository = _Repository();
    final controller = await _controller(repository);

    expect(
      await controller.createClaimDraft(_claim(projectId: 'project-2')),
      isNull,
    );
    expect(repository.createCalls, 0);
    expect(repository.commandKeys, isEmpty);
    expect(controller.state.status, YorksAccountsViewStatus.failure);
    expect(controller.state.error?.code, YorksV1DomainErrorCode.invalidInput);
  });

  test('lost response is uncertain and retry reuses the same key', () async {
    final repository = _Repository(failFirstCreate: true);
    final controller = await _controller(repository);
    final input = _claim();

    expect(await controller.createClaimDraft(input), isNull);
    expect(controller.state.status, YorksAccountsViewStatus.uncertain);
    expect(repository.commandKeys, hasLength(1));

    final result = await controller.createClaimDraft(input);
    expect(result, isNotNull);
    expect(repository.commandKeys, hasLength(2));
    expect(repository.commandKeys[1], repository.commandKeys[0]);
    expect(controller.state.status, YorksAccountsViewStatus.success);
    expect(controller.state.claims, isNotNull);
  });

  test(
    'conflict is explicit and command busy guard prevents duplicates',
    () async {
      final conflictRepository = _Repository()
        ..commandError = const YorksV1DomainException(
          YorksV1DomainErrorCode.conflict,
        );
      final conflictController = await _controller(conflictRepository);
      expect(await conflictController.createClaimDraft(_claim()), isNull);
      expect(conflictController.state.status, YorksAccountsViewStatus.conflict);

      final deferred = Completer<YorksAccountsReceivablesCommandResult>();
      final busyRepository = _Repository(deferredCreate: deferred);
      final busyController = await _controller(busyRepository);
      final first = busyController.createClaimDraft(_claim());
      await Future<void>.delayed(Duration.zero);
      expect(busyController.state.isMutating, isTrue);
      expect(await busyController.createClaimDraft(_claim()), isNull);
      expect(busyRepository.createCalls, 1);

      deferred.complete(_result());
      expect(await first, isNotNull);
      expect(busyController.state.isMutating, isFalse);
    },
  );

  test('session expiry and disabled state purge all commercial data', () async {
    final cases = <YorksV1DomainErrorCode, YorksAccountsViewStatus>{
      YorksV1DomainErrorCode.unauthenticated:
          YorksAccountsViewStatus.sessionExpired,
      YorksV1DomainErrorCode.featureDisabled:
          YorksAccountsViewStatus.unavailable,
    };
    for (final entry in cases.entries) {
      final repository = _Repository();
      final controller = await _controller(repository);
      await controller.loadClaims();
      repository.readError = YorksV1DomainException(entry.key);

      expect(await controller.loadClaims(), isFalse);
      expect(controller.state.status, entry.value);
      expect(controller.state.hasCommercialValues, isFalse);
    }
  });

  test('permission epoch rebuild purges protected provider state', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = _Repository();
    final epoch = StateProvider<YorksAccountsPermissionEpoch>(
      (ref) => (
        revision: 1,
        trusted: true,
        stale: false,
        revisionSignalHealthy: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1AuthUserIdProvider.overrideWithValue('actor-1'),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.accountant),
        yorksAccountsReceivablesRepositoryProvider.overrideWithValue(
          repository,
        ),
        yorksAccountsPermissionEpochProvider.overrideWith(
          (ref) => ref.watch(epoch),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = yorksAccountsReceivablesControllerProvider('project-1');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final original = container.read(provider.notifier);
    await original.loadClaims();
    expect(container.read(provider).hasCommercialValues, isTrue);

    container.read(epoch.notifier).state = (
      revision: 2,
      trusted: false,
      stale: true,
      revisionSignalHealthy: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider.notifier), isNot(same(original)));
    expect(container.read(provider).hasCommercialValues, isFalse);
    expect(container.read(provider).status, YorksAccountsViewStatus.idle);
  });
}

Future<YorksAccountsReceivablesController> _controller(
  _Repository repository,
) async => YorksAccountsReceivablesController(
  projectId: 'project-1',
  repository: repository,
  commandKeys: YorksV1CriticalCommandKeyStore(
    preferences: await SharedPreferences.getInstance(),
    actorAuthUserId: 'actor-1',
  ),
);

YorksAccountsClaimDraftInput _claim({String projectId = 'project-1'}) =>
    YorksAccountsClaimDraftInput(
      projectId: projectId,
      claimReference: 'CLAIM-001',
      periodStart: YorksAccountsDate.parse('2026-08-01'),
      periodEnd: YorksAccountsDate.parse('2026-08-31'),
      lines: [
        YorksAccountsClaimLineInput(
          progressEntryId: 'progress-1',
          claimedAmount: YorksAccountsDecimal.parse('1250.50'),
          evidenceReference: 'DO-001',
        ),
      ],
      notes: '',
    );

final class _Repository implements YorksAccountsReceivablesRepository {
  _Repository({this.failFirstCreate = false, this.deferredCreate});

  final bool failFirstCreate;
  final Completer<YorksAccountsReceivablesCommandResult>? deferredCreate;
  YorksV1DomainException? readError;
  YorksV1DomainException? commandError;
  int createCalls = 0;
  final List<String> commandKeys = [];

  @override
  Future<YorksAccountsClaimsProjection> listClaims(
    String projectId, {
    YorksAccountsClaimStatus? status,
    YorksAccountsCompositeCursor? before,
    int limit = 50,
  }) async {
    if (readError case final error?) throw error;
    return YorksAccountsClaimsProjection(
      schemaVersion: 3,
      projectId: projectId,
      claims: const [],
      nextCursor: null,
      capabilities: _capabilities,
      commands: _commands,
    );
  }

  @override
  Future<YorksAccountsReceivablesCommandResult> createClaimDraft(
    YorksAccountsClaimDraftInput input, {
    required String idempotencyKey,
  }) async {
    createCalls += 1;
    commandKeys.add(idempotencyKey);
    if (commandError case final error?) throw error;
    if (failFirstCreate && createCalls == 1) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    if (deferredCreate case final pending?) return pending.future;
    return _result();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _capabilities = YorksAccountsReceivablesCapabilities(
  canViewValues: true,
  prepareClientClaim: true,
  manageClientInvoices: true,
  recordClientCertification: true,
  recordClientPayment: true,
  managePdc: true,
);

const _commands = YorksAccountsReceivablesCommands(
  createClaimDraft: true,
  editClaimDraft: true,
  submitClaimToAccounts: true,
  cancelClaim: true,
  createInvoiceDraft: true,
  submitInvoice: true,
  returnInvoice: true,
  cancelInvoice: true,
  recordCertification: true,
  recordPayment: true,
  reversePayment: true,
  createPdc: true,
  transitionPdc: true,
  replacePdc: true,
);

YorksAccountsReceivablesCommandResult _result() =>
    YorksAccountsReceivablesCommandResult(
      replayed: false,
      projectId: 'project-1',
      entityId: 'claim-1',
      recordVersion: 1,
      status: 'draft',
      claimId: 'claim-1',
      invoiceId: null,
      certificationId: null,
      paymentId: null,
      pdcId: null,
      updatedAt: DateTime.parse('2026-08-26T09:15:00Z'),
    );
