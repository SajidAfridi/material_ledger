import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/application/accounts_controller.dart';
import 'package:material_ledger/features/accounts/application/accounts_providers.dart';
import 'package:material_ledger/features/accounts/application/accounts_supplier_controller.dart';
import 'package:material_ledger/features/accounts/application/accounts_supplier_providers.dart';
import 'package:material_ledger/features/accounts/data/accounts_supplier_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_receivables_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_supplier_inputs.dart';
import 'package:material_ledger/features/accounts/domain/accounts_supplier_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'access denial purges every protected supplier-cost projection',
    () async {
      final repository = _Repository();
      final controller = await _controller(repository);
      expect(await controller.loadBills(), isTrue);
      expect(controller.state.hasProtectedSupplierCosts, isTrue);

      repository.readError = const YorksV1DomainException(
        YorksV1DomainErrorCode.unauthorized,
      );
      expect(await controller.loadBills(), isFalse);
      expect(controller.state.status, YorksAccountsViewStatus.forbidden);
      expect(controller.state.hasProtectedSupplierCosts, isFalse);
    },
  );

  test(
    'project controller rejects cross-project supplier command intent',
    () async {
      final repository = _Repository();
      final controller = await _controller(repository);
      expect(
        await controller.createBillDraft(_draft(projectId: 'project-2')),
        isNull,
      );
      expect(repository.createCalls, 0);
      expect(controller.state.error?.code, YorksV1DomainErrorCode.invalidInput);
    },
  );

  test('lost response is uncertain and retry reuses the same key', () async {
    final repository = _Repository(failFirstCreate: true);
    final controller = await _controller(repository);
    final input = _draft();

    expect(await controller.createBillDraft(input), isNull);
    expect(controller.state.status, YorksAccountsViewStatus.uncertain);
    expect(await controller.createBillDraft(input), isNotNull);
    expect(repository.commandKeys, hasLength(2));
    expect(repository.commandKeys.last, repository.commandKeys.first);
    expect(controller.state.bills, isNotNull);
  });

  test(
    'conflict is explicit and busy guard prevents duplicate money',
    () async {
      final conflictRepository = _Repository()
        ..commandError = const YorksV1DomainException(
          YorksV1DomainErrorCode.conflict,
        );
      final conflictController = await _controller(conflictRepository);
      expect(await conflictController.createBillDraft(_draft()), isNull);
      expect(conflictController.state.status, YorksAccountsViewStatus.conflict);

      final pending = Completer<YorksAccountsSupplierCommandResult>();
      final busyRepository = _Repository(deferredCreate: pending);
      final busyController = await _controller(busyRepository);
      final first = busyController.createBillDraft(_draft());
      await Future<void>.delayed(Duration.zero);
      expect(busyController.state.isMutating, isTrue);
      expect(await busyController.createBillDraft(_draft()), isNull);
      expect(busyRepository.createCalls, 1);
      pending.complete(_result());
      expect(await first, isNotNull);
    },
  );

  test('permission epoch rebuild disposes protected supplier state', () async {
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
        yorksAccountsSupplierRepositoryProvider.overrideWithValue(repository),
        yorksAccountsPermissionEpochProvider.overrideWith(
          (ref) => ref.watch(epoch),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = yorksAccountsSupplierControllerProvider('project-1');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final original = container.read(provider.notifier);
    await original.loadBills();
    expect(container.read(provider).hasProtectedSupplierCosts, isTrue);

    container.read(epoch.notifier).state = (
      revision: 2,
      trusted: false,
      stale: true,
      revisionSignalHealthy: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider.notifier), isNot(same(original)));
    expect(container.read(provider).hasProtectedSupplierCosts, isFalse);
    expect(container.read(provider).status, YorksAccountsViewStatus.idle);
  });
}

Future<YorksAccountsSupplierController> _controller(
  _Repository repository,
) async => YorksAccountsSupplierController(
  projectId: 'project-1',
  repository: repository,
  commandKeys: YorksV1CriticalCommandKeyStore(
    preferences: await SharedPreferences.getInstance(),
    actorAuthUserId: 'actor-1',
  ),
);

YorksAccountsSupplierBillDraftInput _draft({String projectId = 'project-1'}) =>
    YorksAccountsSupplierBillDraftInput(
      projectId: projectId,
      supplierName: 'Yorks Supplier LLC',
      supplierInvoiceReference: 'SUP-001',
      invoiceDate: YorksAccountsDate.parse('2026-08-01'),
      dueDate: YorksAccountsDate.parse('2026-08-31'),
      exVatAmount: YorksAccountsDecimal.parse('1000.00'),
      vatRatePercent: YorksAccountsDecimal.parse('5.0000'),
      poLpoReference: 'PO-001',
      poLpoDocumentId: 'po-doc-1',
      acceptedReceiptReviewId: 'receipt-1',
      supplierInvoiceDocumentId: 'invoice-doc-1',
      explicitMismatchReason: null,
      notes: null,
    );

final class _Repository implements YorksAccountsSupplierRepository {
  _Repository({this.failFirstCreate = false, this.deferredCreate});

  final bool failFirstCreate;
  final Completer<YorksAccountsSupplierCommandResult>? deferredCreate;
  YorksV1DomainException? readError;
  YorksV1DomainException? commandError;
  int createCalls = 0;
  final List<String> commandKeys = [];

  @override
  Future<YorksAccountsSupplierBillsProjection> listBills(
    String projectId, {
    String? search,
    YorksAccountsSupplierMatchStatus? matchStatus,
    YorksAccountsSupplierPaymentStatus? paymentStatus,
    YorksAccountsSupplierBillCursor? before,
    int limit = 25,
  }) async {
    if (readError case final error?) throw error;
    return YorksAccountsSupplierBillsProjection(
      projectId: projectId,
      items: const [],
      nextCursor: null,
      capabilities: _capabilities,
      commands: _commands,
    );
  }

  @override
  Future<YorksAccountsSupplierCommandResult> createBillDraft(
    YorksAccountsSupplierBillDraftInput input, {
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

const _capabilities = YorksAccountsSupplierCapabilities(
  manageSupplierBills: true,
  approveSupplierBillPayment: true,
  viewSupplierCosts: true,
);

const _commands = YorksAccountsSupplierCommands(
  createBill: true,
  editBill: true,
  approveBill: true,
  recordPayment: true,
  reversePayment: true,
  cancelBill: true,
);

YorksAccountsSupplierCommandResult _result() =>
    YorksAccountsSupplierCommandResult(
      projectId: 'project-1',
      entityId: 'bill-1',
      supplierBillId: 'bill-1',
      paymentId: null,
      reversalId: null,
      recordVersion: 1,
      status: YorksAccountsSupplierBillStatus.draft,
      matchStatus: YorksAccountsSupplierMatchStatus.matched,
      paymentStatus: YorksAccountsSupplierPaymentStatus.pending,
      amount: null,
      replayed: false,
      updatedAt: DateTime.parse('2026-08-26T09:15:00Z'),
    );
