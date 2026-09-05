import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/yorks_navigation_history.dart';
import '../../../../app/yorks_v1_workspace_status_label.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../../shared/models/yorks_v1_my_profile.dart';
import '../../../../shared/models/yorks_v1_my_profile_workspace.dart';
import '../../../../shared/models/yorks_v1_profile_strings.dart';
import '../../../../shared/models/yorks_v1_workspace_status.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../../shared/providers/yorks_v1_my_profile_provider.dart';
import '../../../../shared/providers/yorks_v1_my_profile_workspace_provider.dart';
import '../../../../shared/providers/yorks_v1_workspace_status_provider.dart';
import '../../../../shared/services/app_config_service.dart';
import '../../../../shared/sync/connectivity_service.dart';
import '../../../../shared/sync/sync_engine.dart';
import '../../../../shared/widgets/yorks_sign_out_action.dart';
import '../widgets/yorks_my_profile_components.dart';

/// Canonical My Yorks destination.
///
/// P03 deliberately consumes only the protected P01 account projection. It
/// does not infer identity from the legacy employee cache or infer actions from
/// a client role. P04 adds protected summaries, scopes and actions; P05 adds
/// linked work identity and richer preference/session facts.
class EngineerProfileScreen extends ConsumerStatefulWidget {
  const EngineerProfileScreen({super.key});

  @override
  ConsumerState<EngineerProfileScreen> createState() =>
      _EngineerProfileScreenState();
}

class _EngineerProfileScreenState extends ConsumerState<EngineerProfileScreen> {
  final _scrollController = ScrollController();
  final _sectionKeys = <YorksMyProfileSection, GlobalKey>{
    for (final section in YorksMyProfileSection.values) section: GlobalKey(),
  };
  var _selectedSection = YorksMyProfileSection.account;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final profileState = ref.watch(yorksV1MyProfileProvider);
    final profileWorkspaceState = ref.watch(yorksV1MyProfileWorkspaceProvider);
    final featureFlags = ref.watch(yorksV1FeatureFlagsProvider);
    final workspaceStatus = ref.watch(yorksV1WorkspaceStatusProvider);
    final version = ref.watch(appVersionProvider).label;
    final direction = language.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final layout = yorksMyProfileLayoutFor(constraints.maxWidth);
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final compact = layout == YorksMyProfileLayout.compact;
          final horizontalPadding = switch (layout) {
            YorksMyProfileLayout.compact => AppSpacing.mobileScreenHorizontal,
            YorksMyProfileLayout.medium => AppSpacing.xxl,
            YorksMyProfileLayout.expanded => AppSpacing.screenHorizontal,
          };
          final sections = <YorksProfileSectionDefinition>[
            YorksProfileSectionDefinition(
              section: YorksMyProfileSection.account,
              label: AppStrings.overview.active(language),
              icon: Icons.home_outlined,
            ),
            YorksProfileSectionDefinition(
              section: YorksMyProfileSection.accessAndScope,
              label: YorksV1ProfileStrings.accessAndScope.active(language),
              icon: Icons.shield_outlined,
            ),
            YorksProfileSectionDefinition(
              section: YorksMyProfileSection.preferences,
              label: YorksV1ProfileStrings.preferences.active(language),
              icon: Icons.tune_rounded,
            ),
          ];
          final accountSection = _AccountSection(
            key: _sectionKeys[YorksMyProfileSection.account],
            language: language,
            profileState: profileState,
            compact:
                compact ||
                (layout == YorksMyProfileLayout.medium && size.height <= 500),
            onRetry: () => unawaited(_refreshProfile()),
          );
          final todaySection = _TodayAndActionsSection(
            key: _sectionKeys[YorksMyProfileSection.today],
            language: language,
            profileState: profileState,
            workspaceState: profileWorkspaceState,
            featureFlags: featureFlags,
            compact: compact,
            onRetry: () => unawaited(_refreshProfile()),
            onNavigate: (route) => context.push(route),
          );
          final accessSection = _AccessSection(
            key: _sectionKeys[YorksMyProfileSection.accessAndScope],
            language: language,
            profileState: profileState,
            workspaceState: profileWorkspaceState,
            onRetry: () => unawaited(_refreshProfile()),
          );
          final workIdentitySection = _WorkIdentitySection(
            key: _sectionKeys[YorksMyProfileSection.workIdentity],
            language: language,
            profileState: profileState,
            workspaceState: profileWorkspaceState,
            onRetry: () => unawaited(_refreshProfile()),
          );
          final preferencesSection = _PreferencesSection(
            key: _sectionKeys[YorksMyProfileSection.preferences],
            language: language,
            currencyLabel: '🇦🇪 AED',
            languageLabel: language.nativeName,
            onNotifications: () =>
                context.push(RoutePaths.notificationPreferences),
            onLanguage: () => _showLanguagePicker(language),
          );
          final helpAndSecuritySection = _HelpAndSecuritySection(
            key: _sectionKeys[YorksMyProfileSection.helpAndSecurity],
            language: language,
            workspaceStatus: workspaceStatus,
            version: version,
            onWorkspaceSync: () => _showSyncSheet(language),
            onRefreshAccess: () => unawaited(_refreshProfile()),
            onAbout: () => context.push(RoutePaths.about),
            onSignOut: () => showYorksSignOut(context, ref),
          );

          final sectionNavigation = YorksProfileSectionNavigation(
            language: language,
            sections: sections,
            selected: _selectedSection,
            onSelected: _selectSection,
          );
          final confirmedBanner = _ServerConfirmedBanner(
            language: language,
            confirmed: profileState.hasValue && profileWorkspaceState.hasValue,
            onRefresh: () => unawaited(_refreshProfile()),
          );
          final content = FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: CustomScrollView(
              key: const ValueKey('canonical-my-yorks-page'),
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    compact ? AppSpacing.lg : AppSpacing.screenVertical,
                    horizontalPadding,
                    compact ? 96 : AppSpacing.xxxl,
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
                            if (layout == YorksMyProfileLayout.expanded)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 336,
                                    child: Column(
                                      children: [
                                        accountSection,
                                        const SizedBox(height: AppSpacing.xl),
                                        accessSection,
                                        const SizedBox(height: AppSpacing.xl),
                                        workIdentitySection,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xl),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _PageHeading(language: language),
                                        const SizedBox(height: AppSpacing.xl),
                                        todaySection,
                                        const SizedBox(height: AppSpacing.md),
                                        confirmedBanner,
                                        const SizedBox(height: AppSpacing.xl),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: preferencesSection),
                                            const SizedBox(
                                              width: AppSpacing.xl,
                                            ),
                                            Expanded(
                                              child: helpAndSecuritySection,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (compact)
                              Column(
                                children: [
                                  accountSection,
                                  const SizedBox(height: AppSpacing.lg),
                                  sectionNavigation,
                                  const SizedBox(height: AppSpacing.lg),
                                  todaySection,
                                  const SizedBox(height: AppSpacing.lg),
                                  confirmedBanner,
                                  const SizedBox(height: AppSpacing.lg),
                                  accessSection,
                                  const SizedBox(height: AppSpacing.lg),
                                  workIdentitySection,
                                  const SizedBox(height: AppSpacing.lg),
                                  preferencesSection,
                                  const SizedBox(height: AppSpacing.lg),
                                  helpAndSecuritySection,
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PageHeading(language: language),
                                  const SizedBox(height: AppSpacing.lg),
                                  sectionNavigation,
                                  const SizedBox(height: AppSpacing.xl),
                                  accountSection,
                                  const SizedBox(height: AppSpacing.xl),
                                  todaySection,
                                  const SizedBox(height: AppSpacing.md),
                                  confirmedBanner,
                                  const SizedBox(height: AppSpacing.xl),
                                  if (textScale < 1.8)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: accessSection),
                                        const SizedBox(width: AppSpacing.xl),
                                        Expanded(child: workIdentitySection),
                                      ],
                                    )
                                  else ...[
                                    accessSection,
                                    const SizedBox(height: AppSpacing.xl),
                                    workIdentitySection,
                                  ],
                                  const SizedBox(height: AppSpacing.xl),
                                  preferencesSection,
                                  const SizedBox(height: AppSpacing.xl),
                                  helpAndSecuritySection,
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: compact
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(
                      YorksMobileUi.appBarHeight,
                    ),
                    child: YorksMobileAppBar(
                      title: AppStrings.profile.active(language),
                      brand: !yorksCanNavigateBack(
                        context,
                        ref,
                        RoutePaths.engineerProfile,
                      ),
                      leading:
                          yorksCanNavigateBack(
                            context,
                            ref,
                            RoutePaths.engineerProfile,
                          )
                          ? YorksMobileIconButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              onPressed: () => yorksNavigateBack(
                                context,
                                ref,
                                RoutePaths.engineerProfile,
                                fallback: RoutePaths.engineerHome,
                              ),
                            )
                          : null,
                    ),
                  )
                : null,
            body: SafeArea(top: !compact, child: content),
          );
        },
      ),
    );
  }

  Future<void> _refreshProfile() async {
    await ref.read(yorksV1MyProfileProvider.notifier).refresh();
    if (!mounted || !ref.read(yorksV1MyProfileProvider).hasValue) return;
    await ref.read(yorksV1MyProfileWorkspaceProvider.notifier).refresh();
  }

  void _selectSection(YorksMyProfileSection section) {
    setState(() => _selectedSection = section);
    final sectionContext = _sectionKeys[section]?.currentContext;
    if (sectionContext == null) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      sectionContext,
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: .04,
    );
  }

  void _showLanguagePicker(AppLanguage language) {
    LanguagePickerSheet.show(
      context,
      current: language,
      title: AppStrings.secondaryLanguage.active(language),
      description: YorksV1ProfileStrings.chooseLanguage.active(language),
      textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
      onSelected: (next) =>
          ref.read(languageProvider.notifier).setLanguage(next),
    );
  }

  void _showSyncSheet(AppLanguage language) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 680),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => Directionality(
        textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: _WorkspaceSyncSheet(language: language),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          YorksV1ProfileStrings.account.active(language).toUpperCase(),
          style: AppTypography.eyebrow,
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(
            AppStrings.profile.active(language),
            style: AppTypography.headlineLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          YorksV1ProfileStrings.introduction.active(language),
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

class _ServerConfirmedBanner extends StatelessWidget {
  const _ServerConfirmedBanner({
    required this.language,
    required this.confirmed,
    required this.onRefresh,
  });

  final AppLanguage language;
  final bool confirmed;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!confirmed) return const SizedBox.shrink();
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('my-yorks-server-confirmed-banner'),
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.successContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.success.withValues(alpha: .24)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    YorksV1ProfileStrings.serverConfirmed.active(language),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    YorksV1ProfileStrings.accountScopeRefreshDescription.active(
                      language,
                    ),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              tooltip: YorksV1ProfileStrings.accountScopeRefresh.active(
                language,
              ),
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    super.key,
    required this.language,
    required this.profileState,
    required this.compact,
    required this.onRetry,
  });

  final AppLanguage language;
  final AsyncValue<YorksV1MyProfile> profileState;
  final bool compact;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (profileState) {
      AsyncData(:final value) => YorksIdentityHero(
        language: language,
        state: YorksAccountEvidenceState.verified,
        displayName: value.displayName,
        email: value.email,
        role: value.exactRole,
        compact: compact,
      ),
      AsyncError() => YorksIdentityHero(
        language: language,
        state: YorksAccountEvidenceState.unavailable,
        compact: compact,
        onRetry: onRetry,
      ),
      _ => YorksIdentityHero(
        language: language,
        state: YorksAccountEvidenceState.loading,
        compact: compact,
      ),
    };
  }
}

class _TodayAndActionsSection extends StatelessWidget {
  const _TodayAndActionsSection({
    super.key,
    required this.language,
    required this.profileState,
    required this.workspaceState,
    required this.featureFlags,
    required this.compact,
    required this.onRetry,
    required this.onNavigate,
  });

  final AppLanguage language;
  final AsyncValue<YorksV1MyProfile> profileState;
  final AsyncValue<YorksV1MyProfileWorkspace> workspaceState;
  final YorksV1FeatureFlags featureFlags;
  final bool compact;
  final VoidCallback onRetry;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (profileState.hasError || workspaceState.hasError) {
      return _WorkspaceFactsStateCard(
        title: YorksV1ProfileStrings.today.active(language),
        description: YorksV1ProfileStrings.todayDescription.active(language),
        icon: Icons.today_outlined,
        language: language,
        unavailable: true,
        onRetry: onRetry,
      );
    }
    final profile = profileState.valueOrNull;
    final workspace = workspaceState.valueOrNull;
    if (profile == null || workspace == null) {
      return _WorkspaceFactsStateCard(
        title: YorksV1ProfileStrings.today.active(language),
        description: YorksV1ProfileStrings.todayDescription.active(language),
        icon: Icons.today_outlined,
        language: language,
      );
    }

    final actions = _resolvedProfileActions(
      profile: profile,
      workspace: workspace,
      flags: featureFlags,
      language: language,
      onNavigate: onNavigate,
    );
    final allowedMetricKeys = <String>{
      if (actions.any((action) => action.id == 'open_projects'))
        'technical_projects',
      if (actions.any((action) => action.id == 'open_material_requests')) ...{
        'material_requests_needing_action',
        'material_requests_open',
      },
      if (actions.any((action) => action.id == 'open_accounts'))
        'accounts_projects',
    };
    final metrics = workspace.today.metrics
        .where((metric) => allowedMetricKeys.contains(metric.key))
        .toList(growable: false);

    return YorksProfileSectionCard(
      title: YorksV1ProfileStrings.today.active(language),
      description: YorksV1ProfileStrings.todayDescription.active(language),
      icon: Icons.today_outlined,
      children: [
        Padding(
          key: const ValueKey('my-yorks-today'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: metrics.isEmpty
              ? _WorkspaceInlineNotice(
                  icon: Icons.fact_check_outlined,
                  title: YorksV1ProfileStrings.noTodayFacts.active(language),
                  description: YorksV1ProfileStrings.noTodayFactsDescription
                      .active(language),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final twoColumns =
                        !compact &&
                        textScale < 1.6 &&
                        constraints.maxWidth >= 560;
                    final width = twoColumns
                        ? (constraints.maxWidth - AppSpacing.sm) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final metric in metrics)
                          SizedBox(
                            width: width,
                            child: YorksRoleMetricCard(
                              title: YorksV1ProfileStrings.todayMetricTitle(
                                metric.key,
                                language,
                              ),
                              description:
                                  YorksV1ProfileStrings.todayMetricDescription(
                                    metric.key,
                                    language,
                                  ),
                              value: metric.value,
                              icon: _metricIcon(metric.key),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                YorksV1ProfileStrings.quickActions.active(language),
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                YorksV1ProfileStrings.quickActionsDescription.active(language),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (actions.isEmpty)
                _WorkspaceInlineNotice(
                  icon: Icons.lock_outline_rounded,
                  title: YorksV1ProfileStrings.noQuickActions.active(language),
                  description: YorksV1ProfileStrings.noQuickActionsDescription
                      .active(language),
                )
              else
                YorksQuickActionGrid(actions: actions, compact: compact),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccessSection extends StatelessWidget {
  const _AccessSection({
    super.key,
    required this.language,
    required this.profileState,
    required this.workspaceState,
    required this.onRetry,
  });

  final AppLanguage language;
  final AsyncValue<YorksV1MyProfile> profileState;
  final AsyncValue<YorksV1MyProfileWorkspace> workspaceState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (profileState.hasError || workspaceState.hasError) {
      return _WorkspaceFactsStateCard(
        title: YorksV1ProfileStrings.accessAndScope.active(language),
        description: YorksV1ProfileStrings.accessAndScopeDescription.active(
          language,
        ),
        icon: Icons.shield_outlined,
        language: language,
        unavailable: true,
        onRetry: onRetry,
      );
    }
    final workspace = workspaceState.valueOrNull;
    if (profileState.valueOrNull == null || workspace == null) {
      return _WorkspaceFactsStateCard(
        title: YorksV1ProfileStrings.accessAndScope.active(language),
        description: YorksV1ProfileStrings.accessAndScopeDescription.active(
          language,
        ),
        icon: Icons.shield_outlined,
        language: language,
      );
    }
    return YorksAccessSummaryCard(
      key: const ValueKey('my-yorks-access-scope'),
      language: language,
      scope: workspace.accessScope,
      verifiedAt: workspace.generatedAt,
    );
  }
}

class _WorkIdentitySection extends StatelessWidget {
  const _WorkIdentitySection({
    super.key,
    required this.language,
    required this.profileState,
    required this.workspaceState,
    required this.onRetry,
  });

  final AppLanguage language;
  final AsyncValue<YorksV1MyProfile> profileState;
  final AsyncValue<YorksV1MyProfileWorkspace> workspaceState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (profileState.hasError || workspaceState.hasError) {
      return _WorkspaceFactsStateCard(
        title: YorksV1ProfileStrings.workIdentity.active(language),
        description: YorksV1ProfileStrings.workIdentityDescription.active(
          language,
        ),
        icon: Icons.badge_outlined,
        language: language,
        unavailable: true,
        onRetry: onRetry,
      );
    }
    final workspace = workspaceState.valueOrNull;
    if (profileState.valueOrNull == null || workspace == null) {
      return _WorkspaceFactsStateCard(
        title: YorksV1ProfileStrings.workIdentity.active(language),
        description: YorksV1ProfileStrings.workIdentityDescription.active(
          language,
        ),
        icon: Icons.badge_outlined,
        language: language,
      );
    }
    return YorksWorkIdentityCard(
      key: const ValueKey('my-yorks-work-identity'),
      language: language,
      worker: workspace.workIdentity.worker,
    );
  }
}

class _WorkspaceFactsStateCard extends StatelessWidget {
  const _WorkspaceFactsStateCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.language,
    this.unavailable = false,
    this.onRetry,
  });

  final String title;
  final String description;
  final IconData icon;
  final AppLanguage language;
  final bool unavailable;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return YorksProfileSectionCard(
      title: title,
      description: description,
      icon: icon,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WorkspaceInlineNotice(
                icon: unavailable
                    ? Icons.error_outline_rounded
                    : Icons.sync_rounded,
                title: unavailable
                    ? YorksV1ProfileStrings.workspaceFactsUnavailable.active(
                        language,
                      )
                    : YorksV1ProfileStrings.workspaceFactsLoading.active(
                        language,
                      ),
                description: unavailable
                    ? YorksV1ProfileStrings.workspaceFactsUnavailableDescription
                          .active(language)
                    : YorksV1ProfileStrings.workspaceFactsLoadingDescription
                          .active(language),
              ),
              if (!unavailable) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (unavailable && onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      YorksV1ProfileStrings.tryAgain.active(language),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkspaceInlineNotice extends StatelessWidget {
  const _WorkspaceInlineNotice({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.inkSecondary, size: 21),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<YorksProfileQuickAction> _resolvedProfileActions({
  required YorksV1MyProfile profile,
  required YorksV1MyProfileWorkspace workspace,
  required YorksV1FeatureFlags flags,
  required AppLanguage language,
  required ValueChanged<String> onNavigate,
}) {
  return [
    for (final action in profile.actions)
      if (_profileFeatureEnabled(action.requiredFeature, flags) &&
          (action.id != 'open_accounts' ||
              workspace.accessScope.accountsPortfolioAvailable) &&
          _profileActionRoute(action.id) != null)
        YorksProfileQuickAction(
          id: action.id,
          title: YorksV1ProfileStrings.actionTitle(action.id, language),
          description: YorksV1ProfileStrings.actionDescription(
            action.id,
            language,
          ),
          icon: _profileActionIcon(action.id),
          onPressed: () => onNavigate(_profileActionRoute(action.id)!),
        ),
  ];
}

bool _profileFeatureEnabled(String feature, YorksV1FeatureFlags flags) =>
    switch (feature) {
      'projects' => flags.projects,
      'requests' => flags.requests,
      'accounts' => flags.accounts,
      'inventory_suppliers' => flags.inventorySuppliers,
      'returns_documents' => flags.returnsDocuments,
      'team_chat' => flags.teamChat,
      'analytics' => flags.analytics,
      'foundation' => flags.foundation,
      _ => false,
    };

String? _profileActionRoute(String actionId) => switch (actionId) {
  'open_projects' => RoutePaths.yorksV1Projects,
  'open_material_requests' => RoutePaths.yorksV1MaterialRequests,
  'open_accounts' => RoutePaths.yorksV1Accounts,
  'open_inventory' => RoutePaths.yorksV1Inventory,
  'open_returns' => RoutePaths.yorksV1Returns,
  'open_chat' => RoutePaths.yorksV1TeamChat,
  'open_rentals' => RoutePaths.rentals,
  'open_users' => RoutePaths.users,
  'open_configuration' => RoutePaths.yorksV1Configuration,
  'open_audit' => RoutePaths.activityLog,
  'open_analytics' => RoutePaths.yorksV1Analytics,
  _ => null,
};

IconData _profileActionIcon(String actionId) => switch (actionId) {
  'open_projects' => Icons.account_tree_outlined,
  'open_material_requests' => Icons.assignment_outlined,
  'open_accounts' => Icons.account_balance_outlined,
  'open_inventory' => Icons.inventory_2_outlined,
  'open_returns' => Icons.assignment_return_outlined,
  'open_chat' => Icons.forum_outlined,
  'open_rentals' => Icons.apartment_outlined,
  'open_users' => Icons.manage_accounts_outlined,
  'open_configuration' => Icons.tune_rounded,
  'open_audit' => Icons.history_edu_outlined,
  'open_analytics' => Icons.insights_outlined,
  _ => Icons.open_in_new_rounded,
};

IconData _metricIcon(String key) => switch (key) {
  'technical_projects' => Icons.account_tree_outlined,
  'material_requests_needing_action' => Icons.notification_important_outlined,
  'material_requests_open' => Icons.assignment_outlined,
  'accounts_projects' => Icons.account_balance_outlined,
  _ => Icons.fact_check_outlined,
};

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    super.key,
    required this.language,
    required this.currencyLabel,
    required this.languageLabel,
    required this.onNotifications,
    required this.onLanguage,
  });

  final AppLanguage language;
  final String currencyLabel;
  final String languageLabel;
  final VoidCallback onNotifications;
  final VoidCallback onLanguage;

  @override
  Widget build(BuildContext context) {
    return YorksProfileSectionCard(
      title: YorksV1ProfileStrings.preferences.active(language),
      description: YorksV1ProfileStrings.preferencesDescription.active(
        language,
      ),
      icon: Icons.tune_rounded,
      children: [
        YorksPreferenceRow(
          icon: Icons.notifications_outlined,
          title: AppStrings.notifications.active(language),
          description: YorksV1ProfileStrings.notificationsDescription.active(
            language,
          ),
          onPressed: onNotifications,
        ),
        YorksPreferenceRow(
          icon: Icons.translate_rounded,
          title: AppStrings.secondaryLanguage.active(language),
          description: YorksV1ProfileStrings.chooseLanguage.active(language),
          value: languageLabel,
          onPressed: onLanguage,
        ),
        YorksPreferenceRow(
          icon: Icons.currency_exchange_rounded,
          title: AppStrings.currency.active(language),
          description: YorksV1ProfileStrings.chooseCurrency.active(language),
          value: currencyLabel,
        ),
      ],
    );
  }
}

class _HelpAndSecuritySection extends StatelessWidget {
  const _HelpAndSecuritySection({
    super.key,
    required this.language,
    required this.workspaceStatus,
    required this.version,
    required this.onWorkspaceSync,
    required this.onRefreshAccess,
    required this.onAbout,
    required this.onSignOut,
  });

  final AppLanguage language;
  final YorksV1WorkspaceStatus workspaceStatus;
  final String version;
  final VoidCallback onWorkspaceSync;
  final VoidCallback onRefreshAccess;
  final VoidCallback onAbout;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YorksProfileSectionCard(
          title: YorksV1ProfileStrings.helpAndSecurity.active(language),
          description: YorksV1ProfileStrings.helpAndSecurityDescription.active(
            language,
          ),
          icon: Icons.shield_outlined,
          children: [
            YorksPreferenceRow(
              icon: Icons.cloud_done_outlined,
              title: AppStrings.workspaceSync.active(language),
              description: YorksV1ProfileStrings.workspaceSyncDescription
                  .active(language),
              trailing: YorksV1WorkspaceStatusLabel(
                status: workspaceStatus,
                compact: true,
                language: language,
              ),
              onPressed: onWorkspaceSync,
            ),
            YorksPreferenceRow(
              icon: Icons.admin_panel_settings_outlined,
              title: YorksV1ProfileStrings.accountScopeRefresh.active(language),
              description: YorksV1ProfileStrings.accountScopeRefreshDescription
                  .active(language),
              onPressed: onRefreshAccess,
            ),
            YorksPreferenceRow(
              icon: Icons.info_outline_rounded,
              title: AppStrings.about.active(language),
              description: YorksV1ProfileStrings.aboutDescription.active(
                language,
              ),
              onPressed: onAbout,
            ),
            YorksPreferenceRow(
              icon: Icons.logout_rounded,
              title: AppStrings.signOut.active(language),
              description: YorksV1ProfileStrings.signOutDescription.active(
                language,
              ),
              destructive: true,
              onPressed: onSignOut,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${YorksV1ProfileStrings.organizationName.active(language)} '
              '$version',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Global sync intentionally states only what connectivity and the durable
/// outbox prove. Record-level competing-writer conflicts remain on the record,
/// where both authoritative and local values are available for review.
class _WorkspaceSyncSheet extends ConsumerWidget {
  const _WorkspaceSyncSheet({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(yorksV1WorkspaceStatusProvider);
    final failed = ref.watch(failedSyncProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final online = ref.watch(isOnlineProvider);
    final hasFailure = failed.isNotEmpty;
    final callout = switch (status.state) {
      YorksV1WorkspaceConnectionState.offline => YorksMobileCallout(
        icon: Icons.cloud_off_outlined,
        title: YorksV1ProfileStrings.offlineWorkspace.active(language),
        message: pending == 0
            ? YorksV1ProfileStrings.localDraftsOffline.active(language)
            : YorksV1ProfileStrings.queuedChanges(language, pending),
        warning: true,
      ),
      YorksV1WorkspaceConnectionState.syncing => YorksMobileCallout(
        icon: Icons.sync_rounded,
        title: YorksV1ProfileStrings.syncingChanges.active(language),
        message: YorksV1ProfileStrings.syncingCount(language, pending),
      ),
      YorksV1WorkspaceConnectionState.failed => YorksMobileCallout(
        icon: Icons.error_outline_rounded,
        title: YorksV1ProfileStrings.changesNeedAttention.active(language),
        message: YorksV1ProfileStrings.failedCount(language, failed.length),
        warning: true,
      ),
      _ => YorksMobileCallout(
        icon: Icons.cloud_done_outlined,
        title: online
            ? YorksV1ProfileStrings.workspaceConnected.active(language)
            : YorksV1ProfileStrings.workspaceStatusUnavailable.active(language),
        message: online
            ? YorksV1ProfileStrings.noQueuedChanges.active(language)
            : YorksV1ProfileStrings.connectionWillUpdate.active(language),
      ),
    };
    final maxHeight = MediaQuery.sizeOf(context).height * .92;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          YorksV1ProfileStrings.syncStatus.active(language),
                          style: AppTypography.titleLarge,
                        ),
                      ),
                    ),
                    YorksV1WorkspaceStatusLabel(
                      status: status,
                      compact: true,
                      language: language,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                callout,
                const SizedBox(height: 14),
                YorksMobileCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          YorksV1ProfileStrings.conflictHandling.active(
                            language,
                          ),
                          style: AppTypography.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        YorksV1ProfileStrings.conflictHandlingDescription
                            .active(language),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasFailure) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: FilledButton.icon(
                      onPressed: () => ref.read(syncEngineProvider).retryAll(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        YorksV1ProfileStrings.retrySync.active(language),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
