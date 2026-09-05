import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/constants.dart';
import '../models/app_language.dart';
import '../models/app_strings.dart';
import '../models/yorks_about_strings.dart';
import '../providers/language_provider.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final compact = MediaQuery.sizeOf(context).width <= 640;
    final horizontal = compact
        ? AppSpacing.mobileScreenHorizontal
        : AppSpacing.screenHorizontal;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.md,
                horizontal,
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
                        _AboutHeader(language: language),
                        const SizedBox(height: AppSpacing.lg),
                        _AboutHero(language: language, compact: compact),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeading(
                          title: YorksAboutStrings.managesTitle.active(
                            language,
                          ),
                          description: YorksAboutStrings.managesDescription
                              .active(language),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _CapabilityGrid(language: language),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeading(
                          title: YorksAboutStrings.trustTitle.active(language),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _TrustGrid(language: language),
                        const SizedBox(height: AppSpacing.xxl),
                        _AboutSystemPanel(language: language),
                        const SizedBox(height: AppSpacing.lg),
                        _BoundaryPanel(language: language),
                        const SizedBox(height: AppSpacing.xxl),
                        _AboutLinks(language: language),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          YorksAboutStrings.copyright.active(language),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.muted,
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
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: YorksAboutStrings.back.active(language),
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(RoutePaths.engineerProfile),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          AppStrings.about.active(language),
          style: AppTypography.titleLarge,
        ),
      ),
    ],
  );
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.language, required this.compact});
  final AppLanguage language;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? AppSpacing.xl : AppSpacing.huge),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          YorksAboutStrings.productLabel.active(language),
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.blueContainerStrong,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          YorksAboutStrings.productName.active(language),
          style:
              (compact
                      ? AppTypography.headlineMedium
                      : AppTypography.displaySmall)
                  .copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          YorksAboutStrings.heroTitle.active(language),
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            YorksAboutStrings.heroBody.active(language),
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              YorksAboutStrings.edition.active(language),
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.description});
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.headlineSmall),
      if (description != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          description!,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        ),
      ],
    ],
  );
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _ResponsiveGrid(
    maximumColumns: 3,
    items: [
      _AboutItem(
        icon: Icons.account_tree_outlined,
        color: AppColors.blue,
        title: YorksAboutStrings.projectsTitle.active(language),
        body: YorksAboutStrings.projectsBody.active(language),
      ),
      _AboutItem(
        icon: Icons.groups_outlined,
        color: AppColors.tertiary,
        title: YorksAboutStrings.workforceTitle.active(language),
        body: YorksAboutStrings.workforceBody.active(language),
      ),
      _AboutItem(
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        title: YorksAboutStrings.accountsTitle.active(language),
        body: YorksAboutStrings.accountsBody.active(language),
      ),
      _AboutItem(
        icon: Icons.apartment_outlined,
        color: AppColors.warning,
        title: YorksAboutStrings.rentalsTitle.active(language),
        body: YorksAboutStrings.rentalsBody.active(language),
      ),
      _AboutItem(
        icon: Icons.admin_panel_settings_outlined,
        color: AppColors.navy,
        title: YorksAboutStrings.administrationTitle.active(language),
        body: YorksAboutStrings.administrationBody.active(language),
      ),
    ],
  );
}

class _TrustGrid extends StatelessWidget {
  const _TrustGrid({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _ResponsiveGrid(
    maximumColumns: 4,
    items: [
      _AboutItem(
        icon: Icons.verified_user_outlined,
        color: AppColors.blue,
        title: YorksAboutStrings.serverTitle.active(language),
        body: YorksAboutStrings.serverBody.active(language),
      ),
      _AboutItem(
        icon: Icons.lock_outline_rounded,
        color: AppColors.tertiary,
        title: YorksAboutStrings.accessTitle.active(language),
        body: YorksAboutStrings.accessBody.active(language),
      ),
      _AboutItem(
        icon: Icons.history_rounded,
        color: AppColors.success,
        title: YorksAboutStrings.auditTitle.active(language),
        body: YorksAboutStrings.auditBody.active(language),
      ),
      _AboutItem(
        icon: Icons.cloud_done_outlined,
        color: AppColors.warning,
        title: YorksAboutStrings.offlineTitle.active(language),
        body: YorksAboutStrings.offlineBody.active(language),
      ),
    ],
  );
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.maximumColumns, required this.items});
  final int maximumColumns;
  final List<_AboutItem> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final columns = largeText
          ? 1
          : constraints.maxWidth >= 980
          ? maximumColumns
          : constraints.maxWidth >= 620
          ? 2
          : 1;
      final gap = AppSpacing.lg * (columns - 1);
      final width = (constraints.maxWidth - gap) / columns;
      final height = columns == 1
          ? null
          : maximumColumns == 4
          ? 260.0
          : 240.0;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              height: height,
              child: _AboutItemCard(item: item),
            ),
        ],
      );
    },
  );
}

class _AboutItem {
  const _AboutItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _AboutItemCard extends StatelessWidget {
  const _AboutItemCard({required this.item});
  final _AboutItem item;

  @override
  Widget build(BuildContext context) => _AboutPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(item.icon, color: item.color),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(item.title, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          item.body,
          style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _AboutSystemPanel extends StatelessWidget {
  const _AboutSystemPanel({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _AboutPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          YorksAboutStrings.systemTitle.active(language),
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SystemRow(
          label: YorksAboutStrings.editionLabel.active(language),
          value: YorksAboutStrings.edition.active(language),
        ),
        _SystemRow(
          label: YorksAboutStrings.languagesLabel.active(language),
          value: YorksAboutStrings.languagesValue.active(language),
        ),
        _SystemRow(
          label: YorksAboutStrings.currencyLabel.active(language),
          value: YorksAboutStrings.currencyValue.active(language),
        ),
        _SystemRow(
          label: YorksAboutStrings.devicesLabel.active(language),
          value: YorksAboutStrings.devicesValue.active(language),
        ),
        _SystemRow(
          label: YorksAboutStrings.dataAuthorityLabel.active(language),
          value: YorksAboutStrings.dataAuthorityValue.active(language),
          showDivider: false,
        ),
      ],
    ),
  );
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    decoration: BoxDecoration(
      border: showDivider
          ? const Border(bottom: BorderSide(color: AppColors.line))
          : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTypography.labelMedium)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BoundaryPanel extends StatelessWidget {
  const _BoundaryPanel({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.blueContainer.withValues(alpha: 0.45),
      border: Border.all(color: AppColors.blueContainerStrong),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.blue),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                YorksAboutStrings.boundaryTitle.active(language),
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                YorksAboutStrings.boundaryBody.active(language),
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AboutLinks extends StatelessWidget {
  const _AboutLinks({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => _AboutPanel(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      children: [
        _AboutLink(
          icon: Icons.privacy_tip_outlined,
          label: AppStrings.privacyPolicy.active(language),
          onTap: () => context.push(RoutePaths.privacyPolicy),
        ),
        _AboutLink(
          icon: Icons.gavel_rounded,
          label: AppStrings.termsOfService.active(language),
          onTap: () => context.push(RoutePaths.termsOfService),
        ),
        _AboutLink(
          icon: Icons.code_rounded,
          label: AppStrings.openSourceLicenses.active(language),
          onTap: () => showLicensePage(
            context: context,
            applicationName: YorksAboutStrings.productName.active(language),
            applicationVersion: YorksAboutStrings.edition.active(language),
            applicationLegalese: YorksAboutStrings.copyright.active(language),
          ),
        ),
      ],
    ),
  );
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.bodyLarge)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}
