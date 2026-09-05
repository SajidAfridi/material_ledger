import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/constants/constants.dart';
import '../../../shared/models/app_language.dart';
import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../shared/models/yorks_v1_material_request.dart';
import '../../../shared/models/yorks_v1_material_request_strings.dart';
import '../../../shared/models/yorks_v1_project.dart';
import '../../../shared/models/yorks_v1_project_portfolio.dart';
import '../../../shared/models/yorks_v1_project_strings.dart';
import '../../../shared/providers/language_provider.dart';
import '../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../shared/providers/yorks_v1_project_portfolio_provider.dart';
import '../application/company_analytics_providers.dart';
import '../domain/company_analytics_models.dart';
import '../domain/company_analytics_strings.dart';

class CompanyAnalyticsScreen extends ConsumerStatefulWidget {
  const CompanyAnalyticsScreen({super.key});

  @override
  ConsumerState<CompanyAnalyticsScreen> createState() =>
      _CompanyAnalyticsScreenState();
}

/// Compact founder-facing company summary backed by the same protected
/// projection as Analytics. It owns no commands; every action opens a source
/// workspace that performs its normal authorization again.
class CompanyAnalyticsOverviewSummary extends StatefulWidget {
  const CompanyAnalyticsOverviewSummary({
    super.key,
    required this.language,
    required this.projection,
    required this.flags,
  });

  final AppLanguage language;
  final CompanyAnalyticsProjection projection;
  final YorksV1FeatureFlags flags;

  @override
  State<CompanyAnalyticsOverviewSummary> createState() =>
      _CompanyAnalyticsOverviewSummaryState();
}

class _CompanyAnalyticsOverviewSummaryState
    extends State<CompanyAnalyticsOverviewSummary> {
  String? _currencyCode;

  @override
  void didUpdateWidget(covariant CompanyAnalyticsOverviewSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currencies = widget.projection.accounts?.currencyGroups ?? const [];
    if (_currencyCode != null &&
        !currencies.any((group) => group.currencyCode == _currencyCode)) {
      _currencyCode = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final projection = widget.projection;
    final flags = widget.flags;
    final compact =
        MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final wide = MediaQuery.sizeOf(context).width >= 1180 && textScale <= 1.3;
    final kpis = _CompanyKpiGrid(
      language: language,
      projection: projection,
      flags: flags,
    );
    final actions = _ImportantActionsCard(
      language: language,
      projection: projection,
      flags: flags,
      maxVisible: wide ? 3 : 5,
    );
    final rental = projection.rentals == null
        ? null
        : _OverviewRentalCard(
            language: language,
            data: projection.rentals!,
            onOpen: () => context.go(RoutePaths.rentals),
          );
    final statusPanels = <Widget>[
      if (projection.accounts != null)
        _OverviewFinancialStatusCard(
          language: language,
          data: projection.accounts!,
          selectedCurrency: _currencyCode,
          onCurrencyChanged: (value) => setState(() => _currencyCode = value),
          onOpen: flags.accounts
              ? () => context.go(RoutePaths.yorksV1Accounts)
              : null,
        ),
      if (projection.materialRequests != null)
        _OverviewMaterialRequestsCard(
          language: language,
          data: projection.materialRequests!,
          onOpen: () => context.go(RoutePaths.yorksV1MaterialRequests),
        ),
      if (projection.workforce != null)
        _OverviewWorkforceCard(
          language: language,
          data: projection.workforce!,
          onOpen: flags.workforce
              ? () => context.go(RoutePaths.yorksV1Workforce)
              : null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConfirmationLine(language: language, value: projection.generatedAt),
        if (projection.isPartial) ...[
          const SizedBox(height: AppSpacing.md),
          _OverviewCoverageNotice(language: language),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (compact) ...[
          actions,
          const SizedBox(height: AppSpacing.lg),
          kpis,
          if (rental != null) ...[
            const SizedBox(height: AppSpacing.lg),
            rental,
          ],
        ] else ...[
          kpis,
          const SizedBox(height: AppSpacing.lg),
          if (wide && rental != null)
            SizedBox(
              height: 340,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: actions),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: rental),
                ],
              ),
            )
          else ...[
            actions,
            if (rental != null) ...[
              const SizedBox(height: AppSpacing.lg),
              rental,
            ],
          ],
        ],
        if (statusPanels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          if (wide)
            SizedBox(
              height: 420,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < statusPanels.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.lg),
                    Expanded(child: statusPanels[index]),
                  ],
                ],
              ),
            )
          else
            ...statusPanels.indexed.expand(
              (entry) => [
                if (entry.$1 > 0) const SizedBox(height: AppSpacing.lg),
                entry.$2,
              ],
            ),
        ],
      ],
    );
  }
}

class _OverviewCoverageNotice extends StatelessWidget {
  const _OverviewCoverageNotice({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: 0.52),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.blue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              CompanyAnalyticsStrings.overviewPartialDescription.active(
                language,
              ),
              style: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompanyAnalyticsScreenState
    extends ConsumerState<CompanyAnalyticsScreen> {
  CompanyAnalyticsFilters _filters = const CompanyAnalyticsFilters();

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final flags = ref.watch(yorksV1FeatureFlagsProvider);
    final projects = ref.watch(yorksV1AuthorizedProjectPortfolioProvider);
    final projection = ref.watch(companyAnalyticsProjectionProvider(_filters));
    final compact =
        MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint;

    return ColoredBox(
      color: compact ? AppColors.mobileSurface : AppColors.surface,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact
                    ? AppSpacing.mobileScreenHorizontal
                    : AppSpacing.screenHorizontal,
                compact
                    ? AppSpacing.mobileScreenVertical
                    : AppSpacing.screenVertical,
                compact
                    ? AppSpacing.mobileScreenHorizontal
                    : AppSpacing.screenHorizontal,
                AppSpacing.colossal,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.pageMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AnalyticsHeader(
                          language: language,
                          compact: compact,
                          onRefresh: _refresh,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _AnalyticsFilters(
                          language: language,
                          compact: compact,
                          filters: _filters,
                          projects:
                              projects.valueOrNull ??
                              const <YorksV1ProjectPortfolioItem>[],
                          projectsLoading: projects.isLoading,
                          onProjectChanged: (projectId) {
                            setState(() {
                              _filters = CompanyAnalyticsFilters(
                                projectId: projectId,
                                months: _filters.months,
                              );
                            });
                          },
                          onMonthsChanged: (months) {
                            setState(() {
                              _filters = CompanyAnalyticsFilters(
                                projectId: _filters.projectId,
                                months: months,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        projection.when(
                          loading: () => const _AnalyticsLoading(),
                          error: (error, _) => _AnalyticsError(
                            language: language,
                            error: error,
                            onRetry: _refresh,
                          ),
                          data: (data) => _AnalyticsContent(
                            language: language,
                            compact: compact,
                            projection: data,
                            flags: flags,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(companyAnalyticsProjectionProvider(_filters));
    await ref.read(companyAnalyticsProjectionProvider(_filters).future);
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.language,
    required this.compact,
    required this.onRefresh,
  });

  final AppLanguage language;
  final bool compact;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CompanyAnalyticsStrings.eyebrow.active(language),
          style: AppTypography.eyebrow,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          CompanyAnalyticsStrings.title.active(language),
          style: compact
              ? AppTypography.headlineMedium
              : AppTypography.displaySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            CompanyAnalyticsStrings.description.active(language),
            style: AppTypography.bodyLarge.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
    final refresh = OutlinedButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: Text(CompanyAnalyticsStrings.refresh.active(language)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.minTapTarget),
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: AppSpacing.lg),
          refresh,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: copy),
        const SizedBox(width: AppSpacing.lg),
        refresh,
      ],
    );
  }
}

class _AnalyticsFilters extends StatelessWidget {
  const _AnalyticsFilters({
    required this.language,
    required this.compact,
    required this.filters,
    required this.projects,
    required this.projectsLoading,
    required this.onProjectChanged,
    required this.onMonthsChanged,
  });

  final AppLanguage language;
  final bool compact;
  final CompanyAnalyticsFilters filters;
  final List<YorksV1ProjectPortfolioItem> projects;
  final bool projectsLoading;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<int> onMonthsChanged;

  @override
  Widget build(BuildContext context) {
    final projectControl = _FilterField(
      label: CompanyAnalyticsStrings.project.active(language),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: filters.projectId,
          icon: projectsLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                CompanyAnalyticsStrings.allProjects.active(language),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final item in projects)
              DropdownMenuItem<String?>(
                value: item.project.id,
                child: Text(
                  '${item.project.reference} · ${item.project.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onProjectChanged,
        ),
      ),
    );
    final periodControl = _FilterField(
      label: CompanyAnalyticsStrings.period.active(language),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: filters.months,
          icon: const Icon(Icons.expand_more_rounded),
          items: [
            for (final months in CompanyAnalyticsFilters.supportedMonths)
              DropdownMenuItem<int>(
                value: months,
                child: Text(
                  '$months ${CompanyAnalyticsStrings.months.active(language)}',
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onMonthsChanged(value);
          },
        ),
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          projectControl,
          const SizedBox(height: AppSpacing.md),
          periodControl,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 2, child: projectControl),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: periodControl),
      ],
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelMedium),
          SizedBox(height: AppSpacing.minTapTarget, child: child),
        ],
      ),
    ),
  );
}

enum _AnalyticsDomain {
  company,
  accounts,
  projects,
  materials,
  workforce,
  rentals,
}

class _AnalyticsContent extends StatefulWidget {
  const _AnalyticsContent({
    required this.language,
    required this.compact,
    required this.projection,
    required this.flags,
  });

  final AppLanguage language;
  final bool compact;
  final CompanyAnalyticsProjection projection;
  final YorksV1FeatureFlags flags;

  @override
  State<_AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<_AnalyticsContent> {
  _AnalyticsDomain _domain = _AnalyticsDomain.company;
  String? _currencyCode;

  @override
  void didUpdateWidget(covariant _AnalyticsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currencies = widget.projection.accounts?.currencyGroups ?? const [];
    if (_currencyCode != null &&
        !currencies.any((group) => group.currencyCode == _currencyCode)) {
      _currencyCode = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.projection;
    final language = widget.language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConfirmationLine(language: language, value: projection.generatedAt),
        const SizedBox(height: AppSpacing.md),
        _DomainSelector(
          language: language,
          compact: widget.compact,
          selected: _domain,
          projection: projection,
          onSelected: (value) => setState(() => _domain = value),
        ),
        if (projection.isPartial) ...[
          const SizedBox(height: AppSpacing.md),
          _PartialNotice(language: language),
        ],
        if (_domain == _AnalyticsDomain.company) ...[
          const SizedBox(height: AppSpacing.lg),
          if (widget.compact) ...[
            _ImportantActionsCard(
              language: language,
              projection: projection,
              flags: widget.flags,
            ),
            const SizedBox(height: AppSpacing.lg),
            _CompanyKpiGrid(
              language: language,
              projection: projection,
              flags: widget.flags,
            ),
          ] else ...[
            _CompanyKpiGrid(
              language: language,
              projection: projection,
              flags: widget.flags,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ImportantActionsCard(
              language: language,
              projection: projection,
              flags: widget.flags,
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        ..._domainSections(language, projection),
        if (_domain == _AnalyticsDomain.company) ...[
          const SizedBox(height: AppSpacing.lg),
          _CoverageCard(
            language: language,
            projection: projection,
            flags: widget.flags,
          ),
        ],
      ],
    );
  }

  List<Widget> _domainSections(
    AppLanguage language,
    CompanyAnalyticsProjection projection,
  ) {
    final projects = projection.projects;
    final requests = projection.materialRequests;
    final accounts = projection.accounts;
    final workforce = projection.workforce;
    final rentals = projection.rentals;
    final sections = <Widget>[];

    void add(Widget child) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: AppSpacing.lg));
      }
      sections.add(child);
    }

    if ((_domain == _AnalyticsDomain.company ||
            _domain == _AnalyticsDomain.accounts) &&
        accounts != null) {
      add(
        _AccountsPositionCard(
          language: language,
          data: accounts,
          selectedCurrency: _currencyCode,
          onCurrencyChanged: (value) => setState(() => _currencyCode = value),
          onOpen: widget.flags.accounts
              ? () => context.go(RoutePaths.yorksV1Accounts)
              : null,
        ),
      );
    }
    if (_domain == _AnalyticsDomain.company ||
        _domain == _AnalyticsDomain.projects) {
      if (projects != null) {
        add(_ProjectReviewCard(language: language, data: projects));
      } else if (_domain == _AnalyticsDomain.projects) {
        add(_DomainUnavailableCard(language: language));
      }
    }
    if (_domain == _AnalyticsDomain.company ||
        _domain == _AnalyticsDomain.materials) {
      if (requests != null) {
        add(_MaterialPipelineCard(language: language, data: requests));
        add(_MonthlyMovementCard(language: language, data: requests));
      } else if (_domain == _AnalyticsDomain.materials) {
        add(_DomainUnavailableCard(language: language));
      }
    }
    if ((_domain == _AnalyticsDomain.company ||
            _domain == _AnalyticsDomain.workforce) &&
        workforce != null) {
      add(
        _WorkforceEvidenceCard(
          language: language,
          data: workforce,
          onOpen: widget.flags.workforce
              ? () => context.go(RoutePaths.yorksV1Workforce)
              : null,
        ),
      );
    } else if (_domain == _AnalyticsDomain.workforce) {
      add(_DomainUnavailableCard(language: language));
    }
    if ((_domain == _AnalyticsDomain.company ||
            _domain == _AnalyticsDomain.rentals) &&
        rentals != null) {
      add(
        _RentalBusinessCard(
          language: language,
          data: rentals,
          onOpen: () => context.go(RoutePaths.rentals),
        ),
      );
    } else if (_domain == _AnalyticsDomain.rentals) {
      add(_DomainUnavailableCard(language: language));
    }
    if (sections.isEmpty) add(_DomainUnavailableCard(language: language));
    return sections;
  }
}

class _DomainSelector extends StatelessWidget {
  const _DomainSelector({
    required this.language,
    required this.compact,
    required this.selected,
    required this.projection,
    required this.onSelected,
  });

  final AppLanguage language;
  final bool compact;
  final _AnalyticsDomain selected;
  final CompanyAnalyticsProjection projection;
  final ValueChanged<_AnalyticsDomain> onSelected;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _FilterField(
        label: CompanyAnalyticsStrings.section.active(language),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_AnalyticsDomain>(
            key: const ValueKey('company-analytics-domain-dropdown'),
            isExpanded: true,
            value: selected,
            icon: const Icon(Icons.expand_more_rounded),
            items: [
              for (final domain in _AnalyticsDomain.values)
                DropdownMenuItem<_AnalyticsDomain>(
                  value: domain,
                  child: Row(
                    children: [
                      Icon(_icon(domain), size: 18, color: _stateColor(domain)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _label(domain),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final domain in _AnalyticsDomain.values) ...[
            ChoiceChip(
              selected: selected == domain,
              onSelected: (_) => onSelected(domain),
              avatar: Icon(
                _icon(domain),
                size: 18,
                color: selected == domain
                    ? AppColors.blue
                    : _stateColor(domain),
              ),
              label: Text(_label(domain)),
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              side: BorderSide(
                color: selected == domain ? AppColors.blue : AppColors.line,
              ),
            ),
            if (domain != _AnalyticsDomain.values.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  String _label(_AnalyticsDomain domain) => switch (domain) {
    _AnalyticsDomain.company => CompanyAnalyticsStrings.company.active(
      language,
    ),
    _AnalyticsDomain.accounts => CompanyAnalyticsStrings.accountsSource.active(
      language,
    ),
    _AnalyticsDomain.projects => CompanyAnalyticsStrings.projectSource.active(
      language,
    ),
    _AnalyticsDomain.materials => CompanyAnalyticsStrings.requestsSource.active(
      language,
    ),
    _AnalyticsDomain.workforce =>
      CompanyAnalyticsStrings.workforceSource.active(language),
    _AnalyticsDomain.rentals => CompanyAnalyticsStrings.rentalsSource.active(
      language,
    ),
  };

  IconData _icon(_AnalyticsDomain domain) => switch (domain) {
    _AnalyticsDomain.company => Icons.space_dashboard_outlined,
    _AnalyticsDomain.accounts => Icons.account_balance_wallet_outlined,
    _AnalyticsDomain.projects => Icons.account_tree_outlined,
    _AnalyticsDomain.materials => Icons.assignment_outlined,
    _AnalyticsDomain.workforce => Icons.groups_outlined,
    _AnalyticsDomain.rentals => Icons.apartment_outlined,
  };

  Color _stateColor(_AnalyticsDomain domain) {
    final key = switch (domain) {
      _AnalyticsDomain.company => null,
      _AnalyticsDomain.accounts => 'accounts',
      _AnalyticsDomain.projects => 'projects',
      _AnalyticsDomain.materials => 'material_requests',
      _AnalyticsDomain.workforce => 'workforce',
      _AnalyticsDomain.rentals => 'rentals',
    };
    final state = key == null ? null : projection.coverage[key]?.state;
    return switch (state) {
      CompanyAnalyticsCoverageState.available || null => AppColors.success,
      CompanyAnalyticsCoverageState.sourceOnly => AppColors.blue,
      CompanyAnalyticsCoverageState.denied => AppColors.muted,
    };
  }
}

class _CompanyKpiGrid extends StatelessWidget {
  const _CompanyKpiGrid({
    required this.language,
    required this.projection,
    required this.flags,
  });

  final AppLanguage language;
  final CompanyAnalyticsProjection projection;
  final YorksV1FeatureFlags flags;

  @override
  Widget build(BuildContext context) {
    final accounts = projection.accounts;
    final cards = <Widget>[
      if (accounts != null)
        _ExecutiveKpiCard(
          label: CompanyAnalyticsStrings.accountsSource.active(language),
          value: accounts.currencyGroups.length == 1
              ? _formatCompactMoney(
                  accounts.currencyGroups.single.currencyCode,
                  accounts.currencyGroups.single.received,
                  language,
                )
              : '${accounts.currencyGroups.length}',
          detail: accounts.currencyGroups.length == 1
              ? CompanyAnalyticsStrings.receivedMoney.active(language)
              : CompanyAnalyticsStrings.currencyGroups.active(language),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
          onTap: flags.accounts
              ? () => context.go(RoutePaths.yorksV1Accounts)
              : null,
        ),
      if (projection.projects != null)
        _ExecutiveKpiCard(
          label: CompanyAnalyticsStrings.projectsTitle.active(language),
          value: '${projection.projects!.active}',
          detail: CompanyAnalyticsStrings.active.active(language),
          icon: Icons.account_tree_outlined,
          color: AppColors.blue,
          onTap: () => context.go(RoutePaths.yorksV1Projects),
        ),
      if (projection.materialRequests != null)
        _ExecutiveKpiCard(
          label: CompanyAnalyticsStrings.materialFlowTitle.active(language),
          value: '${projection.materialRequests!.open}',
          detail: CompanyAnalyticsStrings.openRequests.active(language),
          icon: Icons.assignment_outlined,
          color: AppColors.tertiary,
          onTap: () => context.go(RoutePaths.yorksV1MaterialRequests),
        ),
      if (projection.workforce != null)
        _ExecutiveKpiCard(
          label: CompanyAnalyticsStrings.workforceSource.active(language),
          value: '${projection.workforce!.activeWorkerCount}',
          detail: CompanyAnalyticsStrings.activeWorkers.active(language),
          icon: Icons.groups_outlined,
          color: AppColors.success,
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1Workforce)
              : null,
        ),
      if (projection.rentals != null)
        _ExecutiveKpiCard(
          label: CompanyAnalyticsStrings.rentalBusiness.active(language),
          value: '${projection.rentals!.occupancyPercent.round()}%',
          detail: CompanyAnalyticsStrings.propertiesOccupied.active(language),
          icon: Icons.apartment_outlined,
          color: AppColors.warning,
          onTap: () => context.go(RoutePaths.rentals),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact =
            MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint;
        final columns = compact ? 1 : (width < 980 ? 2 : 5);
        final gap = AppSpacing.md * (columns - 1);
        final cardWidth = (width - gap) / columns;
        final textScale = MediaQuery.textScalerOf(
          context,
        ).scale(1).clamp(1.0, 2.0);
        final cardHeight =
            (compact ? 112.0 : 150.0) + (textScale - 1) * (compact ? 136 : 132);
        return Wrap(
          key: const ValueKey('company-analytics-kpi-grid'),
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (var index = 0; index < cards.length; index++)
              SizedBox(
                key: ValueKey('company-analytics-kpi-card-$index'),
                width: cardWidth,
                height: cardHeight,
                child: cards[index],
              ),
          ],
        );
      },
    );
  }
}

class _ExecutiveKpiCard extends StatelessWidget {
  const _ExecutiveKpiCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconBox = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Icon(icon, size: AppSpacing.xl, color: color),
      ),
    );
    final compact =
        MediaQuery.sizeOf(context).width <= AppSpacing.compactBreakpoint;
    if (compact) {
      return _Panel(
        onTap: onTap,
        semanticsLabel: '$label: $value. $detail',
        child: Row(
          children: [
            iconBox,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.headlineMedium,
              ),
            ),
          ],
        ),
      );
    }
    return _Panel(
      onTap: onTap,
      semanticsLabel: '$label: $value. $detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconBox,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ImportantActionsCard extends StatelessWidget {
  const _ImportantActionsCard({
    required this.language,
    required this.projection,
    required this.flags,
    this.maxVisible,
  });

  final AppLanguage language;
  final CompanyAnalyticsProjection projection;
  final YorksV1FeatureFlags flags;
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    final items = <_OverviewAttentionAction>[
      for (final request
          in (projection.materialRequests?.attention ?? const []).take(
            maxVisible == null ? 5 : 1,
          ))
        _OverviewAttentionAction(
          icon: request.actorCanAct
              ? Icons.assignment_turned_in_outlined
              : Icons.report_problem_outlined,
          color: request.actorCanAct ? AppColors.blue : AppColors.error,
          title: _requestActionLabel(request, language),
          detail:
              '${request.requestNumber} · ${request.projectReference} · '
              '${yorksV1MaterialRequestOwnerRoleCopy(request.currentOwnerRole).active(language)}',
          actionLabel: CompanyAnalyticsStrings.openRequest.active(language),
          onTap: () => context.go(
            RoutePaths.yorksV1MaterialRequestPath(request.requestId),
          ),
        ),
      if ((projection.accounts?.attentionCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.warning,
          title: CompanyAnalyticsStrings.accountsAttention.active(language),
          detail:
              '${projection.accounts!.attentionCount} · ${CompanyAnalyticsStrings.actionRequired.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openAccounts.active(language),
          onTap: flags.accounts
              ? () => context.go(RoutePaths.yorksV1Accounts)
              : null,
        ),
      if ((projection.workforce?.missingTodayCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.groups_outlined,
          color: AppColors.tertiary,
          title: CompanyAnalyticsStrings.completeAttendance.active(language),
          detail:
              '${projection.workforce!.missingTodayCount} ${CompanyAnalyticsStrings.workersWithoutAttendance.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openAttendance.active(language),
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1WorkforceAttendance)
              : null,
        ),
      if ((projection.workforce?.monthlyPendingCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.calendar_month_outlined,
          color: AppColors.tertiary,
          title: CompanyAnalyticsStrings.reviewTimesheets.active(language),
          detail:
              '${projection.workforce!.monthlyPendingCount} ${CompanyAnalyticsStrings.periodsAwaitingReview.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openTimesheets.active(language),
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1WorkforceTimesheets)
              : null,
        ),
      if ((projection.workforce?.returnedCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.assignment_return_outlined,
          color: AppColors.error,
          title: CompanyAnalyticsStrings.correctReturnedTimesheets.active(
            language,
          ),
          detail:
              '${projection.workforce!.returnedCount} ${CompanyAnalyticsStrings.returnedForCorrection.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openTimesheets.active(language),
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1WorkforceTimesheets)
              : null,
        ),
      if ((projection.workforce?.awaitingFinalCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.fact_check_outlined,
          color: AppColors.warning,
          title: CompanyAnalyticsStrings.finalizeTimesheets.active(language),
          detail:
              '${projection.workforce!.awaitingFinalCount} ${CompanyAnalyticsStrings.readyForFinalReview.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openTimesheets.active(language),
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1WorkforceTimesheets)
              : null,
        ),
      if ((projection.workforce?.reopenRequestCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.lock_open_outlined,
          color: AppColors.warning,
          title: CompanyAnalyticsStrings.reviewReopenRequests.active(language),
          detail:
              '${projection.workforce!.reopenRequestCount} ${CompanyAnalyticsStrings.reopenRequestsAwaitingDecision.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openTimesheets.active(language),
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1WorkforceTimesheets)
              : null,
        ),
      if ((projection.workforce?.configurationIssueCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.settings_outlined,
          color: AppColors.error,
          title: CompanyAnalyticsStrings.resolveWorkforceSetup.active(language),
          detail:
              '${projection.workforce!.configurationIssueCount} ${CompanyAnalyticsStrings.setupIssuesRequireAdmin.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openWorkforceAdministration
              .active(language),
          onTap: flags.workforce
              ? () => context.go(RoutePaths.yorksV1WorkforceAdministration)
              : null,
        ),
      if ((projection.rentals?.attentionCount ?? 0) > 0)
        _OverviewAttentionAction(
          icon: Icons.apartment_outlined,
          color: AppColors.warning,
          title: CompanyAnalyticsStrings.rentalFollowUp.active(language),
          detail:
              '${projection.rentals!.attentionCount} · ${CompanyAnalyticsStrings.actionRequired.active(language)}',
          actionLabel: CompanyAnalyticsStrings.openRental.active(language),
          onTap: () => context.go(RoutePaths.rentals),
        ),
    ];
    final visibleItems = maxVisible == null
        ? items
        : items.take(maxVisible!).toList(growable: false);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  CompanyAnalyticsStrings.importantForYou.active(language),
                  style: AppTypography.titleMedium,
                ),
              ),
              _CountBadge(value: projection.importantActionCount),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (visibleItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                CompanyAnalyticsStrings.noImportantActions.active(language),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            )
          else
            for (final item in visibleItems)
              _AttentionRow(
                icon: item.icon,
                color: item.color,
                title: item.title,
                detail: item.detail,
                actionLabel: item.actionLabel,
                onTap: item.onTap,
              ),
        ],
      ),
    );
  }
}

class _OverviewAttentionAction {
  const _OverviewAttentionAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback? onTap;
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(icon, size: 20, color: color),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (onTap != null &&
                      MediaQuery.sizeOf(context).width < 720) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      actionLabel,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              if (MediaQuery.sizeOf(context).width >= 720)
                Text(
                  actionLabel,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.blue,
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ],
        ),
      ),
    ),
  );
}

class _AccountsPositionCard extends StatelessWidget {
  const _AccountsPositionCard({
    required this.language,
    required this.data,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.onOpen,
  });

  final AppLanguage language;
  final CompanyAccountAnalytics data;
  final String? selectedCurrency;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final group = data.currencyGroups.isEmpty
        ? null
        : data.currencyGroups.firstWhere(
            (item) => item.currencyCode == selectedCurrency,
            orElse: () => data.currencyGroups.first,
          );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: CompanyAnalyticsStrings.financialStatus.active(language),
            actionLabel: CompanyAnalyticsStrings.openWorkforce.active(language),
            onOpen: onOpen,
          ),
          Text(
            CompanyAnalyticsStrings.currencyBoundary.active(language),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          if (data.currencyGroups.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DropdownButton<String>(
                value: group?.currencyCode,
                items: [
                  for (final item in data.currencyGroups)
                    DropdownMenuItem(
                      value: item.currencyCode,
                      child: Text(item.currencyCode),
                    ),
                ],
                onChanged: onCurrencyChanged,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (group == null)
            _EmptyData(language: language)
          else ...[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _MoneyMetric(
                  label: CompanyAnalyticsStrings.contractValue.active(language),
                  value: _formatMoney(group.currencyCode, group.contractValue),
                  color: AppColors.blue,
                ),
                _MoneyMetric(
                  label: CompanyAnalyticsStrings.claimed.active(language),
                  value: _formatMoney(group.currencyCode, group.claimed),
                  color: AppColors.tertiary,
                ),
                _MoneyMetric(
                  label: CompanyAnalyticsStrings.certified.active(language),
                  value: _formatMoney(group.currencyCode, group.certified),
                  color: AppColors.warning,
                ),
                _MoneyMetric(
                  label: CompanyAnalyticsStrings.receivedMoney.active(language),
                  value: _formatMoney(group.currencyCode, group.received),
                  color: AppColors.success,
                ),
                _MoneyMetric(
                  label: CompanyAnalyticsStrings.outstanding.active(language),
                  value: _formatMoney(group.currencyCode, group.outstanding),
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SeriesBarChart(
              points: [
                for (final month in group.monthlyFlow)
                  _ChartPoint(month.month, [
                    double.parse(month.claimed),
                    double.parse(month.certified),
                    double.parse(month.received).abs(),
                  ]),
              ],
              series: [
                _ChartSeries(
                  CompanyAnalyticsStrings.claimed.active(language),
                  AppColors.blue,
                ),
                _ChartSeries(
                  CompanyAnalyticsStrings.certified.active(language),
                  AppColors.warning,
                ),
                _ChartSeries(
                  CompanyAnalyticsStrings.receivedMoney.active(language),
                  AppColors.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 170, minHeight: 86),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: AppTypography.titleMedium.copyWith(color: color)),
      ],
    ),
  );
}

class _OverviewFinancialStatusCard extends StatelessWidget {
  const _OverviewFinancialStatusCard({
    required this.language,
    required this.data,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.onOpen,
  });

  final AppLanguage language;
  final CompanyAccountAnalytics data;
  final String? selectedCurrency;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final group = data.currencyGroups.isEmpty
        ? null
        : data.currencyGroups.firstWhere(
            (item) => item.currencyCode == selectedCurrency,
            orElse: () => data.currencyGroups.first,
          );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: CompanyAnalyticsStrings.financialStatus.active(language),
            actionLabel: CompanyAnalyticsStrings.openAccounts.active(language),
            onOpen: onOpen,
          ),
          if (data.currencyGroups.length > 1) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DropdownButton<String>(
                value: group?.currencyCode,
                items: [
                  for (final item in data.currencyGroups)
                    DropdownMenuItem(
                      value: item.currencyCode,
                      child: Text(item.currencyCode),
                    ),
                ],
                onChanged: onCurrencyChanged,
              ),
            ),
          ],
          if (group == null)
            _EmptyData(language: language)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _OverviewValue(
                    label: CompanyAnalyticsStrings.contractValue.active(
                      language,
                    ),
                    value: _formatMoney(
                      group.currencyCode,
                      group.contractValue,
                    ),
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _OverviewValue(
                    label: CompanyAnalyticsStrings.outstanding.active(language),
                    value: _formatMoney(group.currencyCode, group.outstanding),
                    color: AppColors.error,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _FinancialProgressRow(
              label: CompanyAnalyticsStrings.claimed.active(language),
              value: group.claimed,
              contractValue: group.contractValue,
              formattedValue: _formatCompactMoney(
                group.currencyCode,
                group.claimed,
                language,
              ),
              color: AppColors.blue,
            ),
            const SizedBox(height: AppSpacing.md),
            _FinancialProgressRow(
              label: CompanyAnalyticsStrings.certified.active(language),
              value: group.certified,
              contractValue: group.contractValue,
              formattedValue: _formatCompactMoney(
                group.currencyCode,
                group.certified,
                language,
              ),
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.md),
            _FinancialProgressRow(
              label: CompanyAnalyticsStrings.receivedMoney.active(language),
              value: group.received,
              contractValue: group.contractValue,
              formattedValue: _formatCompactMoney(
                group.currencyCode,
                group.received,
                language,
              ),
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              CompanyAnalyticsStrings.receivedAgainstContract.active(language),
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialProgressRow extends StatelessWidget {
  const _FinancialProgressRow({
    required this.label,
    required this.value,
    required this.contractValue,
    required this.formattedValue,
    required this.color,
  });

  final String label;
  final String value;
  final String contractValue;
  final String formattedValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(value) ?? 0;
    final contract = double.tryParse(contractValue) ?? 0;
    final progress = contract <= 0 ? 0.0 : (amount / contract).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.labelMedium)),
            Text(formattedValue, style: AppTypography.labelLarge),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.surfaceContainerLow,
          ),
        ),
      ],
    );
  }
}

class _OverviewMaterialRequestsCard extends StatelessWidget {
  const _OverviewMaterialRequestsCard({
    required this.language,
    required this.data,
    required this.onOpen,
  });

  final AppLanguage language;
  final CompanyMaterialRequestAnalytics data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: CompanyAnalyticsStrings.materialFlowTitle.active(language),
          actionLabel: CompanyAnalyticsStrings.openRequestsButton.active(
            language,
          ),
          onOpen: onOpen,
        ),
        _OverviewStatLine(
          label: CompanyAnalyticsStrings.openRequests.active(language),
          value: '${data.open}',
          color: AppColors.tertiary,
        ),
        _OverviewStatLine(
          label: CompanyAnalyticsStrings.dispatchReady.active(language),
          value: '${data.dispatchReady}',
          color: AppColors.blue,
        ),
        _OverviewStatLine(
          label: CompanyAnalyticsStrings.receiptPending.active(language),
          value: '${data.receiptPending}',
          color: AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.md),
        _OverviewRequestActivityChart(
          language: language,
          months: data.monthlyFlow,
        ),
      ],
    ),
  );
}

class _OverviewRequestActivityChart extends StatelessWidget {
  const _OverviewRequestActivityChart({
    required this.language,
    required this.months,
  });

  final AppLanguage language;
  final List<CompanyMaterialRequestMonth> months;

  @override
  Widget build(BuildContext context) {
    final visible = months.length <= 6
        ? months
        : months.sublist(months.length - 6);
    final maximum = visible.fold<int>(
      1,
      (value, month) =>
          math.max(value, math.max(month.submitted, month.closed)),
    );
    if (visible.isEmpty) return _EmptyData(language: language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            _Legend(
              label: CompanyAnalyticsStrings.submitted.active(language),
              color: AppColors.blue,
            ),
            _Legend(
              label: CompanyAnalyticsStrings.closed.active(language),
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final month in visible)
                Expanded(
                  child: _OverviewMonthBars(month: month, maximum: maximum),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewMonthBars extends StatelessWidget {
  const _OverviewMonthBars({required this.month, required this.maximum});

  final CompanyMaterialRequestMonth month;
  final int maximum;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _OverviewBar(
              value: month.submitted,
              maximum: maximum,
              color: AppColors.blue,
            ),
            const SizedBox(width: 3),
            _OverviewBar(
              value: month.closed,
              maximum: maximum,
              color: AppColors.success,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(month.month.split('-').last, style: AppTypography.labelSmall),
    ],
  );
}

class _OverviewBar extends StatelessWidget {
  const _OverviewBar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  final int value;
  final int maximum;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: value == 0 ? 3 : math.max(8, 72 * value / maximum).toDouble(),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusSm),
      ),
    ),
  );
}

class _OverviewWorkforceCard extends StatelessWidget {
  const _OverviewWorkforceCard({
    required this.language,
    required this.data,
    required this.onOpen,
  });

  final AppLanguage language;
  final CompanyWorkforceAnalytics data;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final totalMinutes =
        data.confirmedRegularMinutes + data.confirmedOvertimeMinutes;
    final regularShare = totalMinutes == 0
        ? 0.0
        : data.confirmedRegularMinutes / totalMinutes;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: CompanyAnalyticsStrings.workforceSource.active(language),
            actionLabel: CompanyAnalyticsStrings.openSource.active(language),
            onOpen: onOpen,
          ),
          _OverviewStatLine(
            label: CompanyAnalyticsStrings.activeWorkers.active(language),
            value: '${data.activeWorkerCount}',
            color: AppColors.blue,
          ),
          _OverviewStatLine(
            label: CompanyAnalyticsStrings.attendanceNotEntered.active(
              language,
            ),
            value: '${data.missingTodayCount}',
            color: AppColors.error,
          ),
          _OverviewStatLine(
            label: CompanyAnalyticsStrings.periodsPending.active(language),
            value: '${data.monthlyPendingCount}',
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _OverviewValue(
                  label: CompanyAnalyticsStrings.regularHours.active(language),
                  value: _minutesToHours(
                    data.confirmedRegularMinutes,
                    language,
                  ),
                  color: AppColors.tertiary,
                ),
              ),
              Expanded(
                child: _OverviewValue(
                  label: CompanyAnalyticsStrings.overtimeHours.active(language),
                  value: _minutesToHours(
                    data.confirmedOvertimeMinutes,
                    language,
                  ),
                  color: AppColors.warning,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (regularShare > 0)
                    Expanded(
                      flex: math.max(1, (regularShare * 1000).round()),
                      child: const ColoredBox(color: AppColors.tertiary),
                    ),
                  if (regularShare < 1)
                    Expanded(
                      flex: math.max(1, ((1 - regularShare) * 1000).round()),
                      child: const ColoredBox(color: AppColors.warning),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            CompanyAnalyticsStrings.approvedEvidenceNote.active(language),
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _OverviewRentalCard extends StatelessWidget {
  const _OverviewRentalCard({
    required this.language,
    required this.data,
    required this.onOpen,
  });

  final AppLanguage language;
  final CompanyRentalAnalytics data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: CompanyAnalyticsStrings.rentalBusiness.active(language),
          actionLabel: CompanyAnalyticsStrings.openRental.active(language),
          onOpen: onOpen,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (data.occupancyPercent / 100).clamp(0.0, 1.0),
                          strokeWidth: 9,
                          color: AppColors.success,
                          backgroundColor: AppColors.surfaceContainerLow,
                        ),
                      ),
                      Text(
                        '${data.occupancyPercent.round()}%',
                        style: AppTypography.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _OverviewStatLine(
                        label: CompanyAnalyticsStrings.propertiesOccupied
                            .active(language),
                        value: '${data.occupied}/${data.totalProperties}',
                        color: AppColors.blue,
                      ),
                      _OverviewStatLine(
                        label: CompanyAnalyticsStrings.collectedThisMonth
                            .active(language),
                        value: _formatCompactMoney(
                          data.currencyCode,
                          data.collectedThisMonth,
                          language,
                        ),
                        color: AppColors.success,
                      ),
                      _OverviewStatLine(
                        label: CompanyAnalyticsStrings.outstanding.active(
                          language,
                        ),
                        value: _formatCompactMoney(
                          data.currencyCode,
                          data.outstanding,
                          language,
                        ),
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _OverviewStatLine extends StatelessWidget {
  const _OverviewStatLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLarge.copyWith(color: color),
        ),
      ],
    ),
  );
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: AppTypography.labelSmall.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: AppTypography.titleMedium.copyWith(color: color),
      ),
    ],
  );
}

class _ProjectReviewCard extends StatelessWidget {
  const _ProjectReviewCard({required this.language, required this.data});

  final AppLanguage language;
  final CompanyProjectAnalytics data;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: CompanyAnalyticsStrings.projectReview.active(language),
          actionLabel: CompanyAnalyticsStrings.openProjects.active(language),
          onOpen: () => context.go(RoutePaths.yorksV1Projects),
        ),
        Text(
          CompanyAnalyticsStrings.projectReviewDescription.active(language),
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.register.isEmpty)
          _EmptyData(language: language)
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 720
                ? Column(
                    children: [
                      for (final item in data.register.take(8))
                        _ProjectReviewMobileRow(language: language, item: item),
                    ],
                  )
                : _ProjectReviewTable(language: language, rows: data.register),
          ),
      ],
    ),
  );
}

class _ProjectReviewTable extends StatelessWidget {
  const _ProjectReviewTable({required this.language, required this.rows});

  final AppLanguage language;
  final List<CompanyProjectRegisterItem> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
      columns: [
        DataColumn(
          label: Text(CompanyAnalyticsStrings.project.active(language)),
        ),
        DataColumn(
          label: Text(CompanyAnalyticsStrings.status.active(language)),
        ),
        DataColumn(
          numeric: true,
          label: Text(CompanyAnalyticsStrings.openRequests.active(language)),
        ),
        DataColumn(
          numeric: true,
          label: Text(CompanyAnalyticsStrings.actions.active(language)),
        ),
        DataColumn(label: Text(CompanyAnalyticsStrings.owner.active(language))),
        DataColumn(
          label: Text(CompanyAnalyticsStrings.latest.active(language)),
        ),
      ],
      rows: [
        for (final item in rows.take(12))
          DataRow(
            onSelectChanged: (_) =>
                context.go(RoutePaths.yorksV1ProjectPath(item.projectId)),
            cells: [
              DataCell(
                SizedBox(
                  width: 230,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, overflow: TextOverflow.ellipsis),
                      Text(
                        item.reference,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(_projectStateLabel(item.state, language))),
              DataCell(Text('${item.openRequestCount}')),
              DataCell(Text('${item.requestActionCount}')),
              DataCell(
                Text(
                  YorksV1ProjectStrings.roleLabel(
                    item.currentOwnerRole,
                  ).active(language),
                ),
              ),
              DataCell(Text(_formatTimestamp(item.latestActivityAt.toLocal()))),
            ],
          ),
      ],
    ),
  );
}

class _ProjectReviewMobileRow extends StatelessWidget {
  const _ProjectReviewMobileRow({required this.language, required this.item});

  final AppLanguage language;
  final CompanyProjectRegisterItem item;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go(RoutePaths.yorksV1ProjectPath(item.projectId)),
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${item.reference} · ${_projectStateLabel(item.state, language)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CountPill(
                      label: CompanyAnalyticsStrings.openRequests.active(
                        language,
                      ),
                      value: item.openRequestCount,
                      color: AppColors.blue,
                    ),
                    _CountPill(
                      label: CompanyAnalyticsStrings.actions.active(language),
                      value: item.requestActionCount,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    ),
  );
}

class _MaterialPipelineCard extends StatelessWidget {
  const _MaterialPipelineCard({required this.language, required this.data});

  final AppLanguage language;
  final CompanyMaterialRequestAnalytics data;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: CompanyAnalyticsStrings.materialPipeline.active(language),
          actionLabel: CompanyAnalyticsStrings.openRequestsButton.active(
            language,
          ),
          onOpen: () => context.go(RoutePaths.yorksV1MaterialRequests),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _PipelineStep(
              label: CompanyAnalyticsStrings.awaitingApproval.active(language),
              value: data.awaitingEngineeringApproval,
              color: AppColors.blue,
            ),
            _PipelineStep(
              label: CompanyAnalyticsStrings.toArrange.active(language),
              value: data.toArrange,
              color: AppColors.tertiary,
            ),
            _PipelineStep(
              label: CompanyAnalyticsStrings.dispatchReady.active(language),
              value: data.dispatchReady,
              color: AppColors.warning,
            ),
            _PipelineStep(
              label: CompanyAnalyticsStrings.receiptPending.active(language),
              value: data.receiptPending,
              color: AppColors.success,
            ),
          ],
        ),
        if (data.attention.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            CompanyAnalyticsStrings.requestsNeedAction.active(language),
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in data.attention.take(6))
            _AttentionRow(
              icon: Icons.assignment_outlined,
              color: item.actorCanAct ? AppColors.blue : AppColors.error,
              title: _requestActionLabel(item, language),
              detail: '${item.requestNumber} · ${item.projectName}',
              actionLabel: CompanyAnalyticsStrings.openRequest.active(language),
              onTap: () => context.go(
                RoutePaths.yorksV1MaterialRequestPath(item.requestId),
              ),
            ),
        ],
      ],
    ),
  );
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Text(
          '$value',
          style: AppTypography.headlineSmall.copyWith(color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: AppTypography.labelLarge)),
      ],
    ),
  );
}

class _WorkforceEvidenceCard extends StatelessWidget {
  const _WorkforceEvidenceCard({
    required this.language,
    required this.data,
    this.onOpen,
  });

  final AppLanguage language;
  final CompanyWorkforceAnalytics data;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: CompanyAnalyticsStrings.approvedWorkforceEvidence.active(
            language,
          ),
          actionLabel: CompanyAnalyticsStrings.openSource.active(language),
          onOpen: onOpen,
        ),
        Text(
          CompanyAnalyticsStrings.approvedEvidenceNote.active(language),
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricTile(
              label: CompanyAnalyticsStrings.activeWorkers.active(language),
              value: '${data.activeWorkerCount}',
              color: AppColors.blue,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.regularHours.active(language),
              value: _minutesToHours(data.confirmedRegularMinutes, language),
              color: AppColors.success,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.overtimeHours.active(language),
              value: _minutesToHours(data.confirmedOvertimeMinutes, language),
              color: AppColors.warning,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.attendanceNotEntered.active(
                language,
              ),
              value: '${data.missingTodayCount}',
              color: AppColors.error,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.periodsPending.active(language),
              value: '${data.monthlyPendingCount}',
              color: AppColors.tertiary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SeriesBarChart(
          points: [
            for (final month in data.monthlyFlow)
              _ChartPoint(month.month, [
                month.regularMinutes / 60,
                month.overtimeMinutes / 60,
              ]),
          ],
          series: [
            _ChartSeries(
              CompanyAnalyticsStrings.regularHours.active(language),
              AppColors.blue,
            ),
            _ChartSeries(
              CompanyAnalyticsStrings.overtimeHours.active(language),
              AppColors.warning,
            ),
          ],
        ),
      ],
    ),
  );
}

class _RentalBusinessCard extends StatelessWidget {
  const _RentalBusinessCard({
    required this.language,
    required this.data,
    required this.onOpen,
  });

  final AppLanguage language;
  final CompanyRentalAnalytics data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: CompanyAnalyticsStrings.rentalBusiness.active(language),
          actionLabel: CompanyAnalyticsStrings.openSource.active(language),
          onOpen: onOpen,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricTile(
              label: CompanyAnalyticsStrings.propertiesOccupied.active(
                language,
              ),
              value: '${data.occupied}/${data.totalProperties}',
              color: AppColors.blue,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.monthlyRentRoll.active(language),
              value: _formatMoney(data.currencyCode, data.monthlyRentRoll),
              color: AppColors.tertiary,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.collectedThisMonth.active(
                language,
              ),
              value: _formatMoney(data.currencyCode, data.collectedThisMonth),
              color: AppColors.success,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.outstanding.active(language),
              value: _formatMoney(data.currencyCode, data.outstanding),
              color: AppColors.error,
            ),
            _MetricTile(
              label: CompanyAnalyticsStrings.leaseChequeAttention.active(
                language,
              ),
              value: '${data.attentionCount}',
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SeriesBarChart(
          points: [
            for (final month in data.monthlyFlow)
              _ChartPoint(month.month, [double.parse(month.collected)]),
          ],
          series: [
            _ChartSeries(
              CompanyAnalyticsStrings.receivedMoney.active(language),
              AppColors.success,
            ),
          ],
        ),
      ],
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    constraints: const BoxConstraints(minHeight: 86),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: AppTypography.titleMedium.copyWith(color: color)),
      ],
    ),
  );
}

class _ChartSeries {
  const _ChartSeries(this.label, this.color);

  final String label;
  final Color color;
}

class _ChartPoint {
  const _ChartPoint(this.label, this.values);

  final String label;
  final List<double> values;
}

class _SeriesBarChart extends StatelessWidget {
  const _SeriesBarChart({required this.points, required this.series});

  final List<_ChartPoint> points;
  final List<_ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final maximum = points.fold<double>(
      1,
      (current, point) => point.values.fold<double>(
        current,
        (value, next) => math.max(value, next),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in series)
              _Legend(label: item.label, color: item.color),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (points.isEmpty)
          const SizedBox.shrink()
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 170 + (textScale - 1) * 40,
              width: math.max(420, points.length * 86),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 125,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (
                                  var index = 0;
                                  index < point.values.length;
                                  index++
                                ) ...[
                                  Container(
                                    width: 12,
                                    height: point.values[index] == 0
                                        ? 3
                                        : math.max(
                                            10,
                                            112 * point.values[index] / maximum,
                                          ),
                                    decoration: BoxDecoration(
                                      color: series[index].color,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(
                                          AppSpacing.radiusSm,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (index != point.values.length - 1)
                                    const SizedBox(width: 4),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(point.label, style: AppTypography.labelSmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DomainUnavailableCard extends StatelessWidget {
  const _DomainUnavailableCard({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) =>
      _Panel(child: _UnavailableData(language: language));
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: value == 0
          ? AppColors.successContainer
          : AppColors.warningContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text('$value', style: AppTypography.labelLarge),
    ),
  );
}

class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.language, required this.value});

  final AppLanguage language;
  final DateTime value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.verified_user_outlined,
        size: 18,
        color: AppColors.success,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          '${CompanyAnalyticsStrings.lastConfirmed.active(language)} · '
          '${_formatTimestamp(value.toLocal())}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.success),
        ),
      ),
    ],
  );
}

class _PartialNotice extends StatelessWidget {
  const _PartialNotice({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _Panel(
    color: AppColors.warningContainer,
    borderColor: AppColors.warning.withValues(alpha: 0.35),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.warning),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                CompanyAnalyticsStrings.partialTitle.active(language),
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                CompanyAnalyticsStrings.partialDescription.active(language),
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MonthlyMovementCard extends StatelessWidget {
  const _MonthlyMovementCard({required this.language, required this.data});

  final AppLanguage language;
  final CompanyMaterialRequestAnalytics data;

  @override
  Widget build(BuildContext context) {
    final maximum = data.monthlyFlow.fold<int>(
      1,
      (value, item) => math.max(value, math.max(item.submitted, item.closed)),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final chartHeight = 190 + ((textScale - 1) * 80);
    final plotHeight = 145 + ((textScale - 1) * 60);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CompanyAnalyticsStrings.monthlyMovement.active(language),
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            children: [
              _Legend(
                label: CompanyAnalyticsStrings.submitted.active(language),
                color: AppColors.blue,
              ),
              _Legend(
                label: CompanyAnalyticsStrings.closed.active(language),
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (data.monthlyFlow.isEmpty)
            _EmptyData(language: language)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: chartHeight,
                width: math.max(
                  MediaQuery.sizeOf(context).width - 96,
                  data.monthlyFlow.length * 78,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final month in data.monthlyFlow)
                      Expanded(
                        child: _MonthBars(
                          month: month,
                          maximum: maximum,
                          plotHeight: plotHeight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.month,
    required this.maximum,
    required this.plotHeight,
  });

  final CompanyMaterialRequestMonth month;
  final int maximum;
  final double plotHeight;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      SizedBox(
        height: plotHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SingleBar(
              value: month.submitted,
              maximum: maximum,
              color: AppColors.blue,
            ),
            const SizedBox(width: 5),
            _SingleBar(
              value: month.closed,
              maximum: maximum,
              color: AppColors.success,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(month.month, style: AppTypography.labelSmall),
    ],
  );
}

class _SingleBar extends StatelessWidget {
  const _SingleBar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  final int value;
  final int maximum;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = value == 0
        ? 3.0
        : math.max(12, 118 * value / maximum).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value', style: AppTypography.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 16,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSm),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.language,
    required this.projection,
    required this.flags,
  });

  final AppLanguage language;
  final CompanyAnalyticsProjection projection;
  final YorksV1FeatureFlags flags;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CompanyAnalyticsStrings.coverageTitle.active(language),
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CompanyAnalyticsStrings.coverageDescription.active(language),
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final item in projection.coverage.values)
          _CoverageRow(
            language: language,
            item: item,
            route: _routeFor(item.domain, flags),
          ),
      ],
    ),
  );

  static String? _routeFor(String domain, YorksV1FeatureFlags flags) =>
      switch (domain) {
        'projects' => RoutePaths.yorksV1Projects,
        'material_requests' => RoutePaths.yorksV1MaterialRequests,
        'accounts' when flags.accounts => RoutePaths.yorksV1Accounts,
        'workforce' when flags.workforce => RoutePaths.yorksV1Workforce,
        'rentals' => RoutePaths.rentals,
        'inventory' => RoutePaths.yorksV1Inventory,
        'audit' => RoutePaths.activityLog,
        _ => null,
      };
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.language,
    required this.item,
    required this.route,
  });

  final AppLanguage language;
  final CompanyAnalyticsCoverageItem item;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final state = item.state;
    final color = switch (state) {
      CompanyAnalyticsCoverageState.available => AppColors.success,
      CompanyAnalyticsCoverageState.sourceOnly => AppColors.blue,
      CompanyAnalyticsCoverageState.denied => AppColors.muted,
    };
    final stateLabel = switch (state) {
      CompanyAnalyticsCoverageState.available =>
        CompanyAnalyticsStrings.available.active(language),
      CompanyAnalyticsCoverageState.sourceOnly =>
        CompanyAnalyticsStrings.sourceOnly.active(language),
      CompanyAnalyticsCoverageState.denied =>
        CompanyAnalyticsStrings.denied.active(language),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(
            state == CompanyAnalyticsCoverageState.denied
                ? Icons.lock_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _domainLabel(item.domain, language),
                  style: AppTypography.titleSmall,
                ),
                Text(
                  stateLabel,
                  style: AppTypography.bodySmall.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (route != null && state != CompanyAnalyticsCoverageState.denied)
            IconButton(
              tooltip: _domainLabel(item.domain, language),
              onPressed: () => context.go(route!),
              icon: const Icon(Icons.arrow_forward_rounded),
              constraints: const BoxConstraints.tightFor(
                width: AppSpacing.minTapTarget,
                height: AppSpacing.minTapTarget,
              ),
            ),
        ],
      ),
    );
  }

  String _domainLabel(String domain, AppLanguage language) => switch (domain) {
    'projects' => CompanyAnalyticsStrings.projectSource.active(language),
    'material_requests' => CompanyAnalyticsStrings.requestsSource.active(
      language,
    ),
    'accounts' => CompanyAnalyticsStrings.accountsSource.active(language),
    'workforce' => CompanyAnalyticsStrings.workforceSource.active(language),
    'rentals' => CompanyAnalyticsStrings.rentalsSource.active(language),
    'inventory' => CompanyAnalyticsStrings.inventorySource.active(language),
    'audit' => CompanyAnalyticsStrings.auditSource.active(language),
    _ => domain,
  };
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.actionLabel,
    required this.onOpen,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final action = onOpen == null
          ? null
          : TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minTapTarget),
              ),
              child: Text(actionLabel),
            );
      if (constraints.maxWidth < 420) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xs),
              action,
            ],
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.titleMedium)),
          ?action,
        ],
      );
    },
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.22)),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Text(
        '$label · $value',
        style: AppTypography.labelLarge.copyWith(color: color),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(child: Text(label, style: AppTypography.bodySmall)),
    ],
  );
}

class _UnavailableData extends StatelessWidget {
  const _UnavailableData({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Row(
      children: [
        const Icon(Icons.lock_outline_rounded, color: AppColors.muted),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            CompanyAnalyticsStrings.denied.active(language),
            style: AppTypography.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _EmptyData extends StatelessWidget {
  const _EmptyData({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Text(
      CompanyAnalyticsStrings.noData.active(language),
      style: AppTypography.bodyMedium,
      textAlign: TextAlign.center,
    ),
  );
}

class _AnalyticsLoading extends StatelessWidget {
  const _AnalyticsLoading();

  @override
  Widget build(BuildContext context) => const _Panel(
    child: SizedBox(
      height: 240,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({
    required this.language,
    required this.error,
    required this.onRetry,
  });

  final AppLanguage language;
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final code = error is YorksV1DomainException
        ? (error as YorksV1DomainException).code
        : YorksV1DomainErrorCode.backendUnavailable;
    return _Panel(
      color: AppColors.errorContainer,
      borderColor: AppColors.error.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            CompanyAnalyticsStrings.unableTitle.active(language),
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CompanyAnalyticsStrings.errorFor(code).active(language),
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(CompanyAnalyticsStrings.tryAgain.active(language)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.minTapTarget),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.color = AppColors.surfaceContainerLowest,
    this.borderColor = AppColors.line,
    this.onTap,
    this.semanticsLabel,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusXl);
    final decoration = BoxDecoration(
      color: color,
      border: Border.all(color: borderColor),
      borderRadius: radius,
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    );
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: child,
    );
    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, borderRadius: radius, child: content),
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _projectStateLabel(String value, AppLanguage language) {
  final state = YorksV1ProjectLifecycle.fromWireValue(value);
  return state == null
      ? CompanyAnalyticsStrings.status.active(language)
      : YorksV1ProjectStrings.stateLabel(state).active(language);
}

String _requestActionLabel(
  CompanyMaterialRequestAttentionItem item,
  AppLanguage language,
) {
  final direct = switch (item.nextActionCode) {
    'replacement_dispatch_required' =>
      YorksV1MaterialRequestStrings.replacementDispatchRequired,
    'receipt_review_required' => YorksV1MaterialRequestStrings.awaitingReceipt,
    'material_request_close_review' ||
    'close_request' => YorksV1MaterialRequestStrings.closeReviewRequired,
    _ => null,
  };
  if (direct != null) return direct.active(language);
  final state = YorksV1MaterialRequestState.fromWireValue(item.state);
  return state == null
      ? CompanyAnalyticsStrings.actionRequired.active(language)
      : yorksV1MaterialRequestStateCopy(state).active(language);
}

String _minutesToHours(int minutes, AppLanguage language) {
  final whole = minutes ~/ 60;
  final remainder = minutes.remainder(60);
  final hours = CompanyAnalyticsStrings.hoursShort.active(language);
  final minuteUnit = CompanyAnalyticsStrings.minutesShort.active(language);
  if (remainder == 0) return '$whole $hours';
  return '$whole $hours ${remainder.toString().padLeft(2, '0')} $minuteUnit';
}

String _formatMoney(String currency, String decimal) {
  final negative = decimal.startsWith('-');
  final unsigned = negative ? decimal.substring(1) : decimal;
  final parts = unsigned.split('.');
  final whole = parts.first.padLeft(1, '0');
  final grouped = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
    grouped.write(whole[index]);
  }
  final fraction = parts.length == 1
      ? '00'
      : parts[1].padRight(2, '0').substring(0, 2);
  return '$currency ${negative ? '-' : ''}$grouped.$fraction';
}

String _formatCompactMoney(
  String currency,
  String decimal,
  AppLanguage language,
) {
  final value = double.parse(decimal);
  final formatted = NumberFormat.compact(locale: language.code).format(value);
  return '$currency $formatted';
}
