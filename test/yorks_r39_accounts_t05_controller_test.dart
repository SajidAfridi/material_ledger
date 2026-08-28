import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/accounts/application/accounts_portfolio_controller.dart';
import 'package:material_ledger/features/accounts/application/accounts_portfolio_providers.dart';
import 'package:material_ledger/features/accounts/application/accounts_providers.dart';
import 'package:material_ledger/features/accounts/application/accounts_controller.dart';
import 'package:material_ledger/features/accounts/data/accounts_portfolio_repository.dart';
import 'package:material_ledger/features/accounts/domain/accounts_decimal.dart';
import 'package:material_ledger/features/accounts/domain/accounts_portfolio_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_role.dart';
import 'package:material_ledger/shared/providers/yorks_v1_identity_provider.dart';

void main() {
  test(
    'portfolio authorization failure purges protected projections',
    () async {
      final repository = _Repository();
      final controller = YorksAccountsPortfolioController(repository);
      expect(await controller.load(), isTrue);
      expect(controller.state.projection, isNotNull);

      repository.error = const YorksV1DomainException(
        YorksV1DomainErrorCode.unauthorized,
      );
      expect(await controller.load(), isFalse);
      expect(controller.state.status, YorksAccountsViewStatus.forbidden);
      expect(controller.state.projection, isNull);
    },
  );

  test('project overview authorization failure purges every domain', () async {
    final repository = _Repository();
    final controller = YorksAccountsProjectOverviewController(
      projectId: 'project-1',
      repository: repository,
    );
    expect(await controller.load(), isTrue);
    expect(controller.state.projection!.receivables, isNotNull);

    repository.error = const YorksV1DomainException(
      YorksV1DomainErrorCode.unauthorized,
    );
    expect(await controller.load(), isFalse);
    expect(controller.state.status, YorksAccountsViewStatus.forbidden);
    expect(controller.state.projection, isNull);
  });

  test(
    'project overview keeps confirmed data visible during refresh and transient failure',
    () async {
      final repository = _Repository();
      final controller = YorksAccountsProjectOverviewController(
        projectId: 'project-1',
        repository: repository,
      );
      expect(await controller.load(), isTrue);
      final confirmed = controller.state.projection;

      repository.pendingOverview = Completer();
      final refresh = controller.load();
      expect(controller.state.status, YorksAccountsViewStatus.loading);
      expect(controller.state.projection, same(confirmed));
      repository.pendingOverview!.complete(_overview('project-1'));
      expect(await refresh, isTrue);

      repository.error = const YorksV1DomainException(
        YorksV1DomainErrorCode.offline,
      );
      expect(await controller.load(), isFalse);
      expect(controller.state.status, YorksAccountsViewStatus.offline);
      expect(controller.state.projection, isNotNull);
    },
  );

  test(
    'project Accounts cache survives route disposal but not permission changes',
    () async {
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
          yorksV1AuthUserIdProvider.overrideWithValue('actor-1'),
          yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.accountant),
          yorksAccountsPortfolioRepositoryProvider.overrideWithValue(
            repository,
          ),
          yorksAccountsPermissionEpochProvider.overrideWith(
            (ref) => ref.watch(epoch),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = yorksAccountsProjectOverviewControllerProvider(
        'project-1',
      );
      final subscription = container.listen(provider, (_, _) {});
      final original = container.read(provider.notifier);
      await original.load();
      subscription.close();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider.notifier), same(original));
      expect(container.read(provider).projection, isNotNull);

      container.read(epoch.notifier).state = (
        revision: 2,
        trusted: false,
        stale: true,
        revisionSignalHealthy: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider.notifier), isNot(same(original)));
      expect(container.read(provider).projection, isNull);
    },
  );

  test('permission epoch rebuild disposes cached Accounts state', () async {
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
        yorksV1AuthUserIdProvider.overrideWithValue('actor-1'),
        yorksV1CurrentRoleProvider.overrideWithValue(YorksV1Role.accountant),
        yorksAccountsPortfolioRepositoryProvider.overrideWithValue(repository),
        yorksAccountsPermissionEpochProvider.overrideWith(
          (ref) => ref.watch(epoch),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      yorksAccountsPortfolioControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final original = container.read(
      yorksAccountsPortfolioControllerProvider.notifier,
    );
    await original.load();
    expect(
      container.read(yorksAccountsPortfolioControllerProvider).projection,
      isNotNull,
    );

    container.read(epoch.notifier).state = (
      revision: 2,
      trusted: false,
      stale: true,
      revisionSignalHealthy: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(yorksAccountsPortfolioControllerProvider.notifier),
      isNot(same(original)),
    );
    expect(
      container.read(yorksAccountsPortfolioControllerProvider).projection,
      isNull,
    );
  });

  test(
    'portfolio pages with the server cursor without duplicating rows',
    () async {
      final repository = _Repository()..paged = true;
      final controller = YorksAccountsPortfolioController(repository);

      expect(await controller.load(), isTrue);
      expect(controller.state.projection!.projects, hasLength(1));
      expect(controller.state.projection!.nextProjectId, 'project-1');

      expect(await controller.loadMore(), isTrue);
      expect(
        controller.state.projection!.projects.map((item) => item.projectId),
        ['project-1', 'project-2'],
      );
      expect(controller.state.projection!.nextProjectId, isNull);
    },
  );

  test(
    'newer portfolio filters win when an older request finishes last',
    () async {
      final repository = _OutOfOrderRepository();
      final controller = YorksAccountsPortfolioController(repository);

      final older = controller.load(
        const YorksAccountsPortfolioFilters(search: 'older'),
      );
      final newer = controller.load(
        const YorksAccountsPortfolioFilters(search: 'newer'),
      );

      repository.newer.complete(_projectionFor(_project2));
      expect(await newer, isTrue);
      expect(
        controller.state.projection!.projects.single.projectId,
        'project-2',
      );

      repository.older.complete(_projectionFor(_project));
      expect(await older, isFalse);
      expect(
        controller.state.projection!.projects.single.projectId,
        'project-2',
      );
      expect(controller.state.filters.search, 'newer');
    },
  );
}

final class _OutOfOrderRepository implements YorksAccountsPortfolioRepository {
  final older = Completer<YorksAccountsPortfolioProjection>();
  final newer = Completer<YorksAccountsPortfolioProjection>();

  @override
  Future<YorksAccountsPortfolioProjection> getPortfolio(
    YorksAccountsPortfolioFilters filters,
  ) => filters.search == 'older' ? older.future : newer.future;

  @override
  Future<YorksAccountsProjectOverviewProjection> getProjectOverview(
    String projectId,
  ) => throw UnimplementedError();
}

final class _Repository implements YorksAccountsPortfolioRepository {
  YorksV1DomainException? error;
  bool paged = false;
  Completer<YorksAccountsProjectOverviewProjection>? pendingOverview;

  @override
  Future<YorksAccountsPortfolioProjection> getPortfolio(
    YorksAccountsPortfolioFilters filters,
  ) async {
    if (error case final failure?) throw failure;
    final isNext = filters.beforeProjectId != null;
    return YorksAccountsPortfolioProjection(
      actorExactRole: 'accountant',
      canExport: true,
      authorizedProjectCount: paged ? 2 : 1,
      filteredProjectCount: paged ? 2 : 1,
      totals: paged ? _pagedTotals : _totals,
      projects: [isNext ? _project2 : _project],
      actionQueue: const [],
      nextActivityAt: paged && !isNext ? _project.latestActivityAt : null,
      nextProjectId: paged && !isNext ? _project.projectId : null,
    );
  }

  @override
  Future<YorksAccountsProjectOverviewProjection> getProjectOverview(
    String projectId,
  ) async {
    if (error case final failure?) throw failure;
    if (pendingOverview case final pending?) return pending.future;
    return _overview(projectId);
  }
}

YorksAccountsProjectOverviewProjection _overview(String projectId) =>
    YorksAccountsProjectOverviewProjection(
      projectId: projectId,
      projectReference: 'YRA-001',
      projectName: 'Project One',
      projectSite: 'Abu Dhabi',
      clientName: 'Client LLC',
      actorExactRole: 'accountant',
      capabilities: _capabilities,
      baseline: const {'contract_value': '1000000.00'},
      progress: const {'confirmed_eligible': '100000.00'},
      receivables: const {'still_due': '10000.00'},
      supplier: const {'open_amount': '250.00'},
    );

final _zero = YorksAccountsDecimal.zero;
final _totals = YorksAccountsPortfolioTotals(
  projectCount: 1,
  contractBaseline: YorksAccountsDecimal.parse('1000000.00'),
  confirmedEligible: YorksAccountsDecimal.parse('100000.00'),
  availableToClaim: _zero,
  claimed: _zero,
  certified: _zero,
  amountPaidTillDate: _zero,
  stillDue: _zero,
  pdcExposure: _zero,
  actionCount: 0,
);
final _pagedTotals = YorksAccountsPortfolioTotals(
  projectCount: 2,
  contractBaseline: YorksAccountsDecimal.parse('2000000.00'),
  confirmedEligible: YorksAccountsDecimal.parse('200000.00'),
  availableToClaim: _zero,
  claimed: _zero,
  certified: _zero,
  amountPaidTillDate: _zero,
  stillDue: _zero,
  pdcExposure: _zero,
  actionCount: 0,
);
YorksAccountsPortfolioProjection _projectionFor(
  YorksAccountsPortfolioProject project,
) => YorksAccountsPortfolioProjection(
  actorExactRole: 'accountant',
  canExport: true,
  authorizedProjectCount: 1,
  filteredProjectCount: 1,
  totals: _totals,
  projects: [project],
  actionQueue: const [],
  nextActivityAt: null,
  nextProjectId: null,
);
final _project = YorksAccountsPortfolioProject(
  projectId: 'project-1',
  projectReference: 'YRA-001',
  projectName: 'Project One',
  projectSite: 'Abu Dhabi',
  projectState: 'active',
  clientName: 'Client LLC',
  baselineRevisionNumber: 1,
  currencyCode: 'AED',
  contractBaseline: YorksAccountsDecimal.parse('1000000.00'),
  confirmedEligible: YorksAccountsDecimal.parse('100000.00'),
  availableToClaim: _zero,
  claimed: _zero,
  certified: _zero,
  amountPaidTillDate: _zero,
  stillDue: _zero,
  pdcExposure: _zero,
  confirmedPercent: YorksAccountsDecimal.parse('10'),
  dueState: 'current',
  paymentState: 'unpaid',
  actionCount: 0,
  latestActivityAt: DateTime.utc(2026, 8, 26),
  supplierReviewCount: 0,
  supplierOpenAmount: _zero,
);
final _project2 = YorksAccountsPortfolioProject(
  projectId: 'project-2',
  projectReference: 'YRA-002',
  projectName: 'Project Two',
  projectSite: 'Dubai',
  projectState: 'active',
  clientName: 'Client Two LLC',
  baselineRevisionNumber: 1,
  currencyCode: 'AED',
  contractBaseline: YorksAccountsDecimal.parse('1000000.00'),
  confirmedEligible: YorksAccountsDecimal.parse('100000.00'),
  availableToClaim: _zero,
  claimed: _zero,
  certified: _zero,
  amountPaidTillDate: _zero,
  stillDue: _zero,
  pdcExposure: _zero,
  confirmedPercent: YorksAccountsDecimal.parse('10'),
  dueState: 'current',
  paymentState: 'unpaid',
  actionCount: 0,
  latestActivityAt: DateTime.utc(2026, 8, 25),
  supplierReviewCount: 0,
  supplierOpenAmount: _zero,
);

const _capabilities = YorksAccountsProjectUiCapabilities(
  viewProjectAccounts: true,
  viewValues: true,
  viewSupplierCosts: true,
  suggestProgress: false,
  confirmProgress: false,
  prepareClaim: false,
  manageInvoices: true,
  manageSupplierBills: true,
  approveSupplierPayment: true,
  canExport: true,
);
